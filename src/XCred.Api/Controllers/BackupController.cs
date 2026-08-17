using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using XCred.Core.Constants;
using XCred.Core.DTOs.Common;
using XCred.Core.Entities;
using XCred.Core.Interfaces;
using XCred.Infrastructure.Data;

namespace XCred.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/backup")]
public class BackupController(AppDbContext db, IAuditService audit) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult> Export()
    {
        var userId = GetUserId();

        var user = await db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId);
        if (user == null) return NotFound();

        var credentials = await db.Credentials.AsNoTracking()
            .AsSplitQuery() // 2 collection Includes in one query JOIN their result sets together,
                            // so row count is their PRODUCT per credential, not their sum — see
                            // CredentialsController.GetAll's comment on the same pattern.
            .Where(c => c.OwnerId == userId)
            .Include(c => c.CredentialTags).ThenInclude(ct => ct.Tag)
            .Include(c => c.Attachments)
            .ToListAsync();

        var folders = await db.Folders.AsNoTracking()
            .Where(f => f.OwnerId == userId)
            .ToListAsync();

        var tags = await db.Tags.AsNoTracking()
            .Where(t => t.OwnerId == userId)
            .ToListAsync();

        var backup = new VaultBackup
        {
            // Restoring this backup onto a fresh registration (a different account, even with
            // the same username/master password — see BUG-2026-08-11) is otherwise impossible:
            // every credential's EncryptedCredentialKey is RSA-wrapped under THIS account's
            // PublicKey, and a fresh registration always mints an unrelated random keypair and
            // salt, regardless of whether the password matches. Including this account's own
            // crypto material closes that gap — restore can now optionally re-point the target
            // account's identity at this one (see AuthController's change-master-key, which the
            // web app's Restore flow now calls first when these fields are present). This is
            // exactly what's already sent to this same user's own browser on every login
            // (AuthController.Login) — no new sensitive-data exposure, same [Authorize] trust
            // boundary, just carried in a file instead of a login response.
            KeyDerivationSalt = user.KeyDerivationSalt,
            PublicKey = user.PublicKey,
            EncryptedPrivateKey = user.EncryptedPrivateKey,
            PrivateKeyIv = user.PrivateKeyIv,
            ExportedAt = DateTime.UtcNow,
            Credentials = credentials.Select(c => new BackupCredential
            {
                Id = c.Id,
                Type = c.Type,
                EncryptedData = c.EncryptedData,
                DataIv = c.DataIv,
                EncryptedCredentialKey = c.EncryptedCredentialKey,
                ExpiryDate = c.ExpiryDate,
                FolderId = c.FolderId,
                CreatedAt = c.CreatedAt,
                TagIds = c.CredentialTags.Select(ct => ct.TagId).ToList(),
                Attachments = c.Attachments.Select(a => new BackupAttachment
                {
                    Id = a.Id,
                    EncryptedFileName = a.EncryptedFileName,
                    FileNameIv = a.FileNameIv,
                    EncryptedMimeType = a.EncryptedMimeType,
                    MimeTypeIv = a.MimeTypeIv,
                    EncryptedData = a.EncryptedData,
                    DataIv = a.DataIv,
                    FileSizeBytes = a.FileSizeBytes
                }).ToList()
            }).ToList(),
            Folders = folders.Select(f => new BackupFolder
            {
                Id = f.Id,
                Name = f.Name,
                ParentFolderId = f.ParentFolderId,
                SortOrder = f.SortOrder
            }).ToList(),
            Tags = tags.Select(t => new BackupTag
            {
                Id = t.Id,
                Name = t.Name,
                Color = t.Color
            }).ToList()
        };

        await audit.LogAsync(userId, AuditActions.BackupExported, "Backup", null,
            $"{credentials.Count} credentials", GetIp());

        // Pre-existing gap (same class as AuthController's notification-preferences bug fixed
        // earlier): a manual JsonSerializer.Serialize call bypasses ASP.NET Core's own
        // camelCase default, which only applies to the framework's MVC output formatter (e.g.
        // Ok(...) results), not calls made directly like this one. Restore's [FromBody] binding
        // tolerated the resulting PascalCase file only because System.Text.Json's deserializer
        // is case-insensitive by default — but the web app's own JS reads fields like
        // `backup.keyDerivationSalt` straight off the parsed JSON, which is NOT
        // case-insensitive, so this needs to actually match everywhere else in the app.
        var json = JsonSerializer.Serialize(backup, new JsonSerializerOptions
        {
            WriteIndented = false,
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });
        var bytes = System.Text.Encoding.UTF8.GetBytes(json);
        return File(bytes, "application/json", $"xcred-backup-{DateTime.UtcNow:yyyyMMdd-HHmmss}.xcredbak");
    }

    [HttpPost("restore")]
    public async Task<ActionResult<ApiResponse<RestoreResultDto>>> Restore([FromBody] VaultBackup backup)
    {
        var userId = GetUserId();
        var created = 0;
        var skipped = 0;

        // Restore tags first (credentials reference them)
        var tagIdMap = new Dictionary<Guid, Guid>();
        foreach (var bt in backup.Tags)
        {
            var existing = await db.Tags.FirstOrDefaultAsync(t => t.OwnerId == userId && t.Name == bt.Name);
            if (existing != null) { tagIdMap[bt.Id] = existing.Id; continue; }

            var tag = new Tag { OwnerId = userId, Name = bt.Name, Color = bt.Color };
            db.Tags.Add(tag);
            await db.SaveChangesAsync();
            tagIdMap[bt.Id] = tag.Id;
        }

        // Restore folders (respect parent hierarchy with two passes)
        var folderIdMap = new Dictionary<Guid, Guid>();
        var rootFolders = backup.Folders.Where(f => f.ParentFolderId == null).ToList();
        var childFolders = backup.Folders.Where(f => f.ParentFolderId != null).ToList();

        foreach (var bf in rootFolders.Concat(childFolders))
        {
            Guid? mappedParentId = bf.ParentFolderId.HasValue && folderIdMap.TryGetValue(bf.ParentFolderId.Value, out var pid)
                ? pid : null;

            var folder = new Folder
            {
                OwnerId = userId,
                Name = bf.Name,
                ParentFolderId = mappedParentId,
                SortOrder = bf.SortOrder
            };
            db.Folders.Add(folder);
            await db.SaveChangesAsync();
            folderIdMap[bf.Id] = folder.Id;
        }

        // Restore credentials
        foreach (var bc in backup.Credentials)
        {
            // Skip duplicates (same encrypted data already exists)
            var exists = await db.Credentials.AnyAsync(c =>
                c.OwnerId == userId && c.EncryptedData == bc.EncryptedData);
            if (exists) { skipped++; continue; }

            Guid? mappedFolderId = bc.FolderId.HasValue && folderIdMap.TryGetValue(bc.FolderId.Value, out var fid)
                ? fid : null;

            var cred = new Credential
            {
                OwnerId = userId,
                Type = bc.Type,
                EncryptedData = bc.EncryptedData,
                DataIv = bc.DataIv,
                EncryptedCredentialKey = bc.EncryptedCredentialKey,
                ExpiryDate = bc.ExpiryDate,
                FolderId = mappedFolderId,
                CreatedAt = bc.CreatedAt,
                CreatedById = userId,
                UpdatedById = userId
            };

            foreach (var origTagId in bc.TagIds)
            {
                if (tagIdMap.TryGetValue(origTagId, out var mappedTagId))
                    cred.CredentialTags.Add(new CredentialTag { TagId = mappedTagId });
            }

            db.Credentials.Add(cred);

            foreach (var ba in bc.Attachments)
            {
                db.CredentialAttachments.Add(new CredentialAttachment
                {
                    CredentialId = cred.Id,
                    EncryptedFileName = ba.EncryptedFileName,
                    FileNameIv = ba.FileNameIv,
                    EncryptedMimeType = ba.EncryptedMimeType,
                    MimeTypeIv = ba.MimeTypeIv,
                    EncryptedData = ba.EncryptedData,
                    DataIv = ba.DataIv,
                    FileSizeBytes = ba.FileSizeBytes,
                    UploadedById = userId
                });
            }

            created++;
        }

        await db.SaveChangesAsync();
        await audit.LogAsync(userId, AuditActions.BackupImported, "Backup", null,
            $"Restored {created} credentials, skipped {skipped} duplicates", GetIp());

        return Ok(ApiResponse<RestoreResultDto>.Ok(new RestoreResultDto
        {
            CredentialsRestored = created,
            CredentialsSkipped = skipped,
            TagsRestored = tagIdMap.Count,
            FoldersRestored = folderIdMap.Count
        }));
    }

    private Guid GetUserId() =>
        Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? User.FindFirst("sub")!.Value);

    private string GetIp() => HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
}

public class VaultBackup
{
    public string Version { get; set; } = "1.1";
    public DateTime ExportedAt { get; set; }
    public List<BackupCredential> Credentials { get; set; } = [];
    public List<BackupFolder> Folders { get; set; } = [];
    public List<BackupTag> Tags { get; set; } = [];

    // Account crypto material — optional (absent on backups exported before v1.1, and on
    // Restore's [FromBody] side these are simply never read by the restore-credentials logic
    // below, only by the web app's separate change-master-key call). See Export()'s comment.
    public string? KeyDerivationSalt { get; set; }
    public string? PublicKey { get; set; }
    public string? EncryptedPrivateKey { get; set; }
    public string? PrivateKeyIv { get; set; }
}

public class BackupCredential
{
    public Guid Id { get; set; }
    public string Type { get; set; } = string.Empty;
    public string EncryptedData { get; set; } = string.Empty;
    public string DataIv { get; set; } = string.Empty;
    public string EncryptedCredentialKey { get; set; } = string.Empty;
    public DateTime? ExpiryDate { get; set; }
    public Guid? FolderId { get; set; }
    public DateTime CreatedAt { get; set; }
    public List<Guid> TagIds { get; set; } = [];
    public List<BackupAttachment> Attachments { get; set; } = [];
}

public class BackupAttachment
{
    public Guid Id { get; set; }
    public string EncryptedFileName { get; set; } = string.Empty;
    public string FileNameIv { get; set; } = string.Empty;
    public string EncryptedMimeType { get; set; } = string.Empty;
    public string MimeTypeIv { get; set; } = string.Empty;
    public string EncryptedData { get; set; } = string.Empty;
    public string DataIv { get; set; } = string.Empty;
    public long FileSizeBytes { get; set; }
}

public class BackupFolder
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public Guid? ParentFolderId { get; set; }
    public int SortOrder { get; set; }
}

public class BackupTag
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Color { get; set; } = string.Empty;
}

public class RestoreResultDto
{
    public int CredentialsRestored { get; set; }
    public int CredentialsSkipped { get; set; }
    public int TagsRestored { get; set; }
    public int FoldersRestored { get; set; }
}
