using System.IO.Compression;
using System.Security.Claims;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using XCred.Core.Constants;
using XCred.Core.DTOs.Common;
using XCred.Core.Entities;
using XCred.Core.Interfaces;
using XCred.Infrastructure.Data;

namespace XCred.Api.Controllers;

/// Admin-only, whole-instance backup — distinct from the per-user BackupController, which
/// only ever touches the calling user's own OwnerId-scoped rows. This is a full clone of
/// every table, meant for moving an entire XCred instance (all users, all data) onto a
/// different machine — e.g. an existing SQL-Server-backed install migrating onto the
/// portable SQLite distribution, or just disaster recovery. The export format is plain
/// per-table JSON inside a zip (not a raw DB file copy), so it works regardless of which
/// EF Core provider is running on either end.
[Authorize(Roles = Roles.Admin)]
[ApiController]
[Route("api/system-backup")]
public class SystemBackupController(AppDbContext db, IAuditService audit) : ControllerBase
{
    // WhenWritingNull — every entity here carries required-by-convention navigation
    // properties (e.g. GroupMember.Group/User, Tag.Owner) that a plain query (no
    // .Include()) leaves null; skipping nulls keeps the export to just the actual scalar
    // columns instead of a page of redundant "xyz": null noise. IgnoreCycles is a
    // defensive backstop, not currently load-bearing — none of these navigations are
    // populated at query time, so there's no real object graph to cycle through today.
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        ReferenceHandler = ReferenceHandler.IgnoreCycles,
        WriteIndented = false,
    };

    [HttpGet("export")]
    public async Task<ActionResult> Export()
    {
        var userId = GetUserId();

        var users = await db.Users.AsNoTracking().ToListAsync();
        var groups = await db.Groups.AsNoTracking().ToListAsync();
        var appSettings = await db.AppSettings.AsNoTracking().ToListAsync();
        var groupMembers = await db.GroupMembers.AsNoTracking().ToListAsync();
        var folders = await db.Folders.AsNoTracking().ToListAsync();
        var credentialGroups = await db.CredentialGroups.AsNoTracking().ToListAsync();
        var tags = await db.Tags.AsNoTracking().ToListAsync();
        // IgnoreQueryFilters — Credential is the one entity with a soft-delete filter
        // (CredentialConfiguration.cs); a plain query would silently drop deleted rows.
        var credentials = await db.Credentials.AsNoTracking().IgnoreQueryFilters().ToListAsync();
        var credentialTags = await db.CredentialTags.AsNoTracking().ToListAsync();
        var attachments = await db.CredentialAttachments.AsNoTracking().ToListAsync();
        var sharedCredentials = await db.SharedCredentials.AsNoTracking().ToListAsync();
        var auditLogs = await db.AuditLogs.AsNoTracking().ToListAsync();
        // RefreshTokens deliberately excluded — stale/security-sensitive session state,
        // not meaningful to carry into a restored instance.

        var manifest = new SystemBackupManifest
        {
            ExportedAt = DateTime.UtcNow,
            RowCounts = new SystemBackupSummaryDto
            {
                Users = users.Count,
                Groups = groups.Count,
                AppSettings = appSettings.Count,
                GroupMembers = groupMembers.Count,
                Folders = folders.Count,
                CredentialGroups = credentialGroups.Count,
                Tags = tags.Count,
                Credentials = credentials.Count,
                CredentialTags = credentialTags.Count,
                CredentialAttachments = attachments.Count,
                SharedCredentials = sharedCredentials.Count,
                AuditLogs = auditLogs.Count,
            },
        };

        using var ms = new MemoryStream();
        using (var zip = new ZipArchive(ms, ZipArchiveMode.Create, leaveOpen: true))
        {
            WriteEntry(zip, "manifest.json", manifest);
            WriteEntry(zip, "users.json", users);
            WriteEntry(zip, "groups.json", groups);
            WriteEntry(zip, "appSettings.json", appSettings);
            WriteEntry(zip, "groupMembers.json", groupMembers);
            WriteEntry(zip, "folders.json", folders);
            WriteEntry(zip, "credentialGroups.json", credentialGroups);
            WriteEntry(zip, "tags.json", tags);
            WriteEntry(zip, "credentials.json", credentials);
            WriteEntry(zip, "credentialTags.json", credentialTags);
            WriteEntry(zip, "credentialAttachments.json", attachments);
            WriteEntry(zip, "sharedCredentials.json", sharedCredentials);
            WriteEntry(zip, "auditLogs.json", auditLogs);
        }

        await audit.LogAsync(userId, AuditActions.SystemBackupExported, "SystemBackup", null,
            $"{users.Count} users, {credentials.Count} credentials", GetIp());

        return File(ms.ToArray(), "application/zip", $"xcred-system-backup-{DateTime.UtcNow:yyyyMMdd-HHmmss}.zip");
    }

    [HttpPost("restore")]
    [RequestSizeLimit(524_288_000)] // 500MB — a whole-instance backup carries every attachment blob, easily past the 15MB global Kestrel limit set for normal API calls.
    public async Task<ActionResult<ApiResponse<SystemBackupSummaryDto>>> Restore(IFormFile file, [FromQuery] bool force = false)
    {
        var userId = GetUserId();

        // This is a from-scratch-clone operation by design (see class doc) — refuse by
        // default on a target that already has data, rather than silently merging or
        // wiping. force=true is an explicit, deliberate opt-in to wipe-and-replace.
        var hasExistingUsers = await db.Users.AnyAsync();
        if (hasExistingUsers && !force)
        {
            return Conflict(ApiResponse<SystemBackupSummaryDto>.Fail("TARGET_NOT_EMPTY",
                "This instance already has data. Restoring would replace everything. Pass force=true to confirm."));
        }

        using var zip = new ZipArchive(file.OpenReadStream(), ZipArchiveMode.Read);
        List<User> users;
        List<Group> groups;
        List<AppSetting> appSettings;
        List<GroupMember> groupMembers;
        List<Folder> folders;
        List<CredentialGroup> credentialGroups;
        List<Tag> tags;
        List<Credential> credentials;
        List<CredentialTag> credentialTags;
        List<CredentialAttachment> attachments;
        List<SharedCredential> sharedCredentials;
        List<AuditLog> auditLogs;
        try
        {
            users = ReadEntry<User>(zip, "users.json");
            groups = ReadEntry<Group>(zip, "groups.json");
            appSettings = ReadEntry<AppSetting>(zip, "appSettings.json");
            groupMembers = ReadEntry<GroupMember>(zip, "groupMembers.json");
            folders = ReadEntry<Folder>(zip, "folders.json");
            credentialGroups = ReadEntry<CredentialGroup>(zip, "credentialGroups.json");
            tags = ReadEntry<Tag>(zip, "tags.json");
            credentials = ReadEntry<Credential>(zip, "credentials.json");
            credentialTags = ReadEntry<CredentialTag>(zip, "credentialTags.json");
            attachments = ReadEntry<CredentialAttachment>(zip, "credentialAttachments.json");
            sharedCredentials = ReadEntry<SharedCredential>(zip, "sharedCredentials.json");
            auditLogs = ReadEntry<AuditLog>(zip, "auditLogs.json");
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<SystemBackupSummaryDto>.Fail("INVALID_BACKUP",
                $"That file isn't a valid system backup: {ex.Message}"));
        }

        await using var transaction = await db.Database.BeginTransactionAsync();
        db.ChangeTracker.AutoDetectChangesEnabled = false;
        try
        {
            if (hasExistingUsers)
            {
                // Wipe in reverse-dependency order. IgnoreQueryFilters so a soft-deleted
                // credential left over from the prior instance doesn't survive the wipe.
                db.AuditLogs.RemoveRange(await db.AuditLogs.ToListAsync());
                db.SharedCredentials.RemoveRange(await db.SharedCredentials.ToListAsync());
                db.CredentialAttachments.RemoveRange(await db.CredentialAttachments.ToListAsync());
                db.CredentialTags.RemoveRange(await db.CredentialTags.ToListAsync());
                db.Credentials.RemoveRange(await db.Credentials.IgnoreQueryFilters().ToListAsync());
                db.Tags.RemoveRange(await db.Tags.ToListAsync());
                db.CredentialGroups.RemoveRange(await db.CredentialGroups.ToListAsync());
                db.Folders.RemoveRange(await db.Folders.ToListAsync());
                db.GroupMembers.RemoveRange(await db.GroupMembers.ToListAsync());
                db.RefreshTokens.RemoveRange(await db.RefreshTokens.ToListAsync());
                db.AppSettings.RemoveRange(await db.AppSettings.ToListAsync());
                db.Groups.RemoveRange(await db.Groups.ToListAsync());
                db.Users.RemoveRange(await db.Users.ToListAsync());
                await db.SaveChangesAsync();
            }

            // Insertion order matches FK dependencies (parents before children).
            db.Users.AddRange(users); await db.SaveChangesAsync();
            db.Groups.AddRange(groups); await db.SaveChangesAsync();
            db.AppSettings.AddRange(appSettings); await db.SaveChangesAsync();
            db.GroupMembers.AddRange(groupMembers); await db.SaveChangesAsync();
            db.Folders.AddRange(folders); await db.SaveChangesAsync();
            db.CredentialGroups.AddRange(credentialGroups); await db.SaveChangesAsync();
            db.Tags.AddRange(tags); await db.SaveChangesAsync();
            db.Credentials.AddRange(credentials); await db.SaveChangesAsync();
            db.CredentialTags.AddRange(credentialTags); await db.SaveChangesAsync();
            db.CredentialAttachments.AddRange(attachments); await db.SaveChangesAsync();
            db.SharedCredentials.AddRange(sharedCredentials); await db.SaveChangesAsync();
            db.AuditLogs.AddRange(auditLogs); await db.SaveChangesAsync();

            await transaction.CommitAsync();
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
        finally
        {
            db.ChangeTracker.AutoDetectChangesEnabled = true;
        }

        // The admin performing this restore may not exist among the just-restored users
        // (e.g. cloning a different instance's data onto this one) — fall back to a
        // userless audit entry rather than violating the AuditLog.UserId FK.
        var auditUserId = users.Any(u => u.Id == userId) ? userId : (Guid?)null;
        await audit.LogAsync(auditUserId, AuditActions.SystemBackupRestored, "SystemBackup", null,
            $"{users.Count} users, {credentials.Count} credentials, force={force}", GetIp());

        return Ok(ApiResponse<SystemBackupSummaryDto>.Ok(new SystemBackupSummaryDto
        {
            Users = users.Count,
            Groups = groups.Count,
            AppSettings = appSettings.Count,
            GroupMembers = groupMembers.Count,
            Folders = folders.Count,
            CredentialGroups = credentialGroups.Count,
            Tags = tags.Count,
            Credentials = credentials.Count,
            CredentialTags = credentialTags.Count,
            CredentialAttachments = attachments.Count,
            SharedCredentials = sharedCredentials.Count,
            AuditLogs = auditLogs.Count,
        }));
    }

    private static void WriteEntry<T>(ZipArchive zip, string name, T data)
    {
        var entry = zip.CreateEntry(name, CompressionLevel.Optimal);
        using var stream = entry.Open();
        JsonSerializer.Serialize(stream, data, JsonOptions);
    }

    private static List<T> ReadEntry<T>(ZipArchive zip, string name)
    {
        var entry = zip.GetEntry(name)
            ?? throw new InvalidOperationException($"missing {name}");
        using var stream = entry.Open();
        return JsonSerializer.Deserialize<List<T>>(stream, JsonOptions)
            ?? throw new InvalidOperationException($"{name} was empty/unparseable");
    }

    private Guid GetUserId() =>
        Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? User.FindFirst("sub")!.Value);

    private string GetIp() => HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
}

public class SystemBackupManifest
{
    public string Version { get; set; } = "1.0";
    public DateTime ExportedAt { get; set; }
    public SystemBackupSummaryDto RowCounts { get; set; } = new();
}

public class SystemBackupSummaryDto
{
    public int Users { get; set; }
    public int Groups { get; set; }
    public int AppSettings { get; set; }
    public int GroupMembers { get; set; }
    public int Folders { get; set; }
    public int CredentialGroups { get; set; }
    public int Tags { get; set; }
    public int Credentials { get; set; }
    public int CredentialTags { get; set; }
    public int CredentialAttachments { get; set; }
    public int SharedCredentials { get; set; }
    public int AuditLogs { get; set; }
}
