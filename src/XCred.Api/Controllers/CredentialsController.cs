using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using XCred.Core.Constants;
using XCred.Core.DTOs.Common;
using XCred.Core.DTOs.Credentials;
using XCred.Core.Entities;
using XCred.Core.Interfaces;
using XCred.Infrastructure.Data;

namespace XCred.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/credentials")]
public class CredentialsController(AppDbContext db, IAuditService audit) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<ApiResponse<IEnumerable<CredentialDto>>>> GetAll()
    {
        var userId = GetUserId();
        var credentials = await db.Credentials
            .AsNoTracking()
            .Where(c => c.OwnerId == userId)
            .Include(c => c.CredentialTags).ThenInclude(ct => ct.Tag)
            .Include(c => c.Attachments)
            .Include(c => c.Owner)
            .Include(c => c.Folder)
            .Include(c => c.CredentialGroup)
            .Include(c => c.Shares)
            .OrderByDescending(c => c.UpdatedAt)
            .ToListAsync();

        return Ok(ApiResponse<IEnumerable<CredentialDto>>.Ok(credentials.Select(MapToDto)));
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<ApiResponse<CredentialDto>>> GetById(Guid id)
    {
        var userId = GetUserId();
        var cred = await db.Credentials
            .AsNoTracking()
            .Include(c => c.CredentialTags).ThenInclude(ct => ct.Tag)
            .Include(c => c.Attachments)
            .Include(c => c.Owner)
            .Include(c => c.Folder)
            .Include(c => c.CredentialGroup)
            .Include(c => c.Shares)
            .FirstOrDefaultAsync(c => c.Id == id && c.OwnerId == userId);

        if (cred == null) return NotFound(ApiResponse<CredentialDto>.Fail("NOT_FOUND", "Credential not found."));

        await audit.LogAsync(userId, AuditActions.CredentialViewed, "Credential", id, cred.Type, GetIp());
        return Ok(ApiResponse<CredentialDto>.Ok(MapToDto(cred)));
    }

    [HttpPost]
    public async Task<ActionResult<ApiResponse<CredentialDto>>> Create([FromBody] CreateCredentialRequest req)
    {
        var userId = GetUserId();

        if (!CredentialTypes.All.Contains(req.Type))
            return BadRequest(ApiResponse<CredentialDto>.Fail("INVALID_TYPE", "Unknown credential type."));

        if (!await IsFolderAccessibleAsync(req.FolderId, userId))
            return BadRequest(ApiResponse<CredentialDto>.Fail("INVALID_FOLDER", "Folder not found or not accessible."));

        if (!await IsCredentialGroupAccessibleAsync(req.CredentialGroupId, userId))
            return BadRequest(ApiResponse<CredentialDto>.Fail("INVALID_CREDENTIAL_GROUP", "Credential group not found or not accessible."));

        var cred = new Credential
        {
            OwnerId = userId,
            Type = req.Type,
            EncryptedData = req.EncryptedData,
            DataIv = req.DataIv,
            EncryptedCredentialKey = req.EncryptedCredentialKey,
            ExpiryDate = req.ExpiryDate,
            FolderId = req.FolderId,
            CredentialGroupId = req.CredentialGroupId,
            CreatedById = userId,
            UpdatedById = userId
        };

        if (req.TagIds.Count > 0)
        {
            var validTags = await db.Tags
                .Where(t => req.TagIds.Contains(t.Id) && t.OwnerId == userId)
                .Select(t => t.Id)
                .ToListAsync();
            cred.CredentialTags = validTags.Select(tid => new CredentialTag { TagId = tid }).ToList();
        }

        db.Credentials.Add(cred);
        await db.SaveChangesAsync();
        await audit.LogAsync(userId, AuditActions.CredentialCreated, "Credential", cred.Id, req.Type, GetIp());

        var created = await db.Credentials
            .Include(c => c.CredentialTags).ThenInclude(ct => ct.Tag)
            .Include(c => c.Attachments)
            .Include(c => c.Owner)
            .Include(c => c.Folder)
            .Include(c => c.CredentialGroup)
            .Include(c => c.Shares)
            .FirstAsync(c => c.Id == cred.Id);

        return CreatedAtAction(nameof(GetById), new { id = cred.Id }, ApiResponse<CredentialDto>.Ok(MapToDto(created)));
    }

    [HttpPut("{id:guid}")]
    public async Task<ActionResult<ApiResponse<CredentialDto>>> Update(Guid id, [FromBody] UpdateCredentialRequest req)
    {
        var userId = GetUserId();
        var cred = await db.Credentials
            .Include(c => c.CredentialTags)
            .FirstOrDefaultAsync(c => c.Id == id && c.OwnerId == userId);

        if (cred == null) return NotFound(ApiResponse<CredentialDto>.Fail("NOT_FOUND", "Credential not found."));

        if (!await IsFolderAccessibleAsync(req.FolderId, userId))
            return BadRequest(ApiResponse<CredentialDto>.Fail("INVALID_FOLDER", "Folder not found or not accessible."));

        if (!await IsCredentialGroupAccessibleAsync(req.CredentialGroupId, userId))
            return BadRequest(ApiResponse<CredentialDto>.Fail("INVALID_CREDENTIAL_GROUP", "Credential group not found or not accessible."));

        cred.EncryptedData = req.EncryptedData;
        cred.DataIv = req.DataIv;
        cred.EncryptedCredentialKey = req.EncryptedCredentialKey;
        cred.ExpiryDate = req.ExpiryDate;
        cred.FolderId = req.FolderId;
        cred.CredentialGroupId = req.CredentialGroupId;
        cred.UpdatedAt = DateTime.UtcNow;
        cred.UpdatedById = userId;

        cred.CredentialTags.Clear();
        if (req.TagIds.Count > 0)
        {
            var validTags = await db.Tags
                .Where(t => req.TagIds.Contains(t.Id) && t.OwnerId == userId)
                .Select(t => t.Id)
                .ToListAsync();
            foreach (var tid in validTags)
                cred.CredentialTags.Add(new CredentialTag { CredentialId = id, TagId = tid });
        }

        // Revoke all "until changed" shares when credential is updated
        var untilChangedShares = await db.SharedCredentials
            .Where(s => s.CredentialId == id && s.UntilChanged && !s.IsRevoked)
            .ToListAsync();
        foreach (var share in untilChangedShares)
        {
            share.IsRevoked = true;
            share.RevokedAt = DateTime.UtcNow;
        }

        await db.SaveChangesAsync();
        await audit.LogAsync(userId, AuditActions.CredentialUpdated, "Credential", id, cred.Type, GetIp());

        var updated = await db.Credentials
            .Include(c => c.CredentialTags).ThenInclude(ct => ct.Tag)
            .Include(c => c.Attachments)
            .Include(c => c.Owner)
            .Include(c => c.Folder)
            .Include(c => c.CredentialGroup)
            .Include(c => c.Shares)
            .FirstAsync(c => c.Id == id);

        return Ok(ApiResponse<CredentialDto>.Ok(MapToDto(updated)));
    }

    [HttpDelete("{id:guid}")]
    public async Task<ActionResult<ApiResponse<string>>> Delete(Guid id)
    {
        var userId = GetUserId();
        var cred = await db.Credentials.FirstOrDefaultAsync(c => c.Id == id && c.OwnerId == userId);
        if (cred == null) return NotFound(ApiResponse<string>.Fail("NOT_FOUND", "Credential not found."));

        cred.IsDeleted = true;
        cred.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync();
        await audit.LogAsync(userId, AuditActions.CredentialDeleted, "Credential", id, cred.Type, GetIp());

        return Ok(ApiResponse<string>.Ok("Credential deleted."));
    }

    [HttpPost("{id:guid}/copy")]
    public async Task<ActionResult<ApiResponse<string>>> LogCopy(Guid id, [FromQuery] string field = "password")
    {
        var userId = GetUserId();
        var cred = await db.Credentials.AsNoTracking()
            .FirstOrDefaultAsync(c => c.Id == id && c.OwnerId == userId);
        if (cred == null) return NotFound();

        await audit.LogAsync(userId, AuditActions.CredentialCopied, "Credential", id, $"{cred.Type}:{field}", GetIp());
        return Ok(ApiResponse<string>.Ok("Logged."));
    }

    private CredentialDto MapToDto(Credential c) => new()
    {
        Id = c.Id,
        Type = c.Type,
        EncryptedData = c.EncryptedData,
        DataIv = c.DataIv,
        EncryptedCredentialKey = c.EncryptedCredentialKey,
        ExpiryDate = c.ExpiryDate,
        FolderId = c.FolderId,
        FolderName = c.Folder?.Name,
        CredentialGroupId = c.CredentialGroupId,
        CredentialGroupName = c.CredentialGroup?.Name,
        OwnerId = c.OwnerId,
        OwnerUsername = c.Owner?.Username ?? string.Empty,
        IsShared = c.Shares.Any(s => !s.IsRevoked),
        CreatedAt = c.CreatedAt,
        UpdatedAt = c.UpdatedAt,
        Tags = c.CredentialTags.Select(ct => new TagDto
        {
            Id = ct.Tag.Id,
            Name = ct.Tag.Name,
            Color = ct.Tag.Color
        }).ToList(),
        Attachments = c.Attachments.Select(a => new AttachmentDto
        {
            Id = a.Id,
            EncryptedFileName = a.EncryptedFileName,
            FileNameIv = a.FileNameIv,
            EncryptedMimeType = a.EncryptedMimeType,
            MimeTypeIv = a.MimeTypeIv,
            FileSizeBytes = a.FileSizeBytes,
            UploadedAt = a.UploadedAt
        }).ToList()
    };

    private async Task<bool> IsFolderAccessibleAsync(Guid? folderId, Guid userId) =>
        !folderId.HasValue || await db.Folders.AnyAsync(f => f.Id == folderId && f.OwnerId == userId);

    private async Task<bool> IsCredentialGroupAccessibleAsync(Guid? credentialGroupId, Guid userId)
    {
        if (!credentialGroupId.HasValue) return true;
        var group = await db.CredentialGroups.FirstOrDefaultAsync(cg => cg.Id == credentialGroupId);
        if (group == null) return false;
        if (group.OwnerId == userId) return true;
        return group.GroupId != null && await db.GroupMembers.AnyAsync(gm => gm.GroupId == group.GroupId && gm.UserId == userId);
    }

    private Guid GetUserId() =>
        Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? User.FindFirst("sub")!.Value);

    private string GetIp() => HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
}
