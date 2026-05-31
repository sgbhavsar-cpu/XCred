using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using XCred.Core.Constants;
using XCred.Core.DTOs.Common;
using XCred.Core.DTOs.Sharing;
using XCred.Core.Entities;
using XCred.Core.Interfaces;
using XCred.Infrastructure.Data;

namespace XCred.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/shares")]
public class SharesController(AppDbContext db, IAuditService audit, IEmailService email) : ControllerBase
{
    [HttpGet("shared-with-me")]
    public async Task<ActionResult<ApiResponse<IEnumerable<SharedCredentialDto>>>> GetSharedWithMe()
    {
        var userId = GetUserId();
        var myGroupIds = await db.GroupMembers
            .Where(gm => gm.UserId == userId)
            .Select(gm => gm.GroupId)
            .ToListAsync();

        var shares = await db.SharedCredentials
            .AsNoTracking()
            .Include(s => s.SharedBy)
            .Include(s => s.SharedWithUser)
            .Include(s => s.SharedWithGroup)
            .Include(s => s.Credential)
            .Where(s => !s.IsRevoked
                && (s.ExpiresAt == null || s.ExpiresAt > DateTime.UtcNow)
                && (s.SharedWithUserId == userId || (s.SharedWithGroupId != null && myGroupIds.Contains(s.SharedWithGroupId.Value))))
            .ToListAsync();

        return Ok(ApiResponse<IEnumerable<SharedCredentialDto>>.Ok(shares.Select(MapToDto)));
    }

    [HttpGet("shared-by-me")]
    public async Task<ActionResult<ApiResponse<IEnumerable<SharedCredentialDto>>>> GetSharedByMe()
    {
        var userId = GetUserId();
        var shares = await db.SharedCredentials
            .AsNoTracking()
            .Include(s => s.SharedBy)
            .Include(s => s.SharedWithUser)
            .Include(s => s.SharedWithGroup)
            .Include(s => s.Credential)
            .Where(s => s.SharedById == userId && !s.IsRevoked)
            .ToListAsync();

        return Ok(ApiResponse<IEnumerable<SharedCredentialDto>>.Ok(shares.Select(MapToDto)));
    }

    [HttpPost("credential/{credentialId:guid}")]
    public async Task<ActionResult<ApiResponse<SharedCredentialDto>>> Share(Guid credentialId, [FromBody] ShareCredentialRequest req)
    {
        var userId = GetUserId();
        var cred = await db.Credentials.FirstOrDefaultAsync(c => c.Id == credentialId && c.OwnerId == userId);
        if (cred == null) return NotFound(ApiResponse<SharedCredentialDto>.Fail("NOT_FOUND", "Credential not found."));

        if (req.SharedWithUserId == null && req.SharedWithGroupId == null)
            return BadRequest(ApiResponse<SharedCredentialDto>.Fail("INVALID_REQUEST", "Must specify a user or group to share with."));

        if (req.SharedWithUserId == userId)
            return BadRequest(ApiResponse<SharedCredentialDto>.Fail("INVALID_REQUEST", "Cannot share with yourself."));

        if (req.SharedWithUserId.HasValue && !await db.Users.AnyAsync(u => u.Id == req.SharedWithUserId && u.IsActive))
            return NotFound(ApiResponse<SharedCredentialDto>.Fail("USER_NOT_FOUND", "User not found."));

        if (req.SharedWithGroupId.HasValue && !await db.Groups.AnyAsync(g => g.Id == req.SharedWithGroupId))
            return NotFound(ApiResponse<SharedCredentialDto>.Fail("GROUP_NOT_FOUND", "Group not found."));

        var share = new SharedCredential
        {
            CredentialId = credentialId,
            SharedById = userId,
            SharedWithUserId = req.SharedWithUserId,
            SharedWithGroupId = req.SharedWithGroupId,
            Permission = "Read",
            EncryptedData = req.EncryptedData,
            DataIv = req.DataIv,
            EncryptedCredentialKey = req.EncryptedCredentialKey,
            ExpiresAt = req.ExpiresAt,
            UntilChanged = req.UntilChanged
        };

        db.SharedCredentials.Add(share);
        await db.SaveChangesAsync();
        await audit.LogAsync(userId, AuditActions.ShareCreated, "SharedCredential", share.Id, $"{credentialId}", GetIp());

        // Email notification to recipient
        if (req.SharedWithUserId.HasValue)
        {
            var recipient = await db.Users.FindAsync(req.SharedWithUserId.Value);
            var sharer = await db.Users.FindAsync(userId);
            if (recipient != null && sharer != null)
                await email.SendShareNotificationAsync(recipient.Email, recipient.Username, sharer.Username, cred.Type);
        }

        var created = await db.SharedCredentials
            .Include(s => s.SharedBy).Include(s => s.SharedWithUser).Include(s => s.SharedWithGroup).Include(s => s.Credential)
            .FirstAsync(s => s.Id == share.Id);

        return CreatedAtAction(nameof(GetSharedByMe), ApiResponse<SharedCredentialDto>.Ok(MapToDto(created)));
    }

    [HttpDelete("{id:guid}")]
    public async Task<ActionResult<ApiResponse<string>>> Revoke(Guid id)
    {
        var userId = GetUserId();
        var share = await db.SharedCredentials
            .Include(s => s.Credential)
            .Include(s => s.SharedWithUser)
            .FirstOrDefaultAsync(s => s.Id == id);

        if (share == null) return NotFound();

        // Only the credential owner or an admin can revoke
        if (share.Credential.OwnerId != userId && !User.IsInRole(Roles.Admin))
            return Forbid();

        share.IsRevoked = true;
        share.RevokedAt = DateTime.UtcNow;
        await db.SaveChangesAsync();
        await audit.LogAsync(userId, AuditActions.ShareRevoked, "SharedCredential", id, null, GetIp());

        if (share.SharedWithUser != null)
            await email.SendShareRevokedAsync(share.SharedWithUser.Email, share.SharedWithUser.Username, share.Credential.Type);

        return Ok(ApiResponse<string>.Ok("Share revoked."));
    }

    private static SharedCredentialDto MapToDto(SharedCredential s) => new()
    {
        Id = s.Id,
        CredentialId = s.CredentialId,
        EncryptedData = s.EncryptedData,
        DataIv = s.DataIv,
        EncryptedCredentialKey = s.EncryptedCredentialKey,
        CredentialType = s.Credential?.Type ?? string.Empty,
        SharedByUsername = s.SharedBy?.Username ?? string.Empty,
        SharedWithUserId = s.SharedWithUserId,
        SharedWithUsername = s.SharedWithUser?.Username,
        SharedWithGroupId = s.SharedWithGroupId,
        SharedWithGroupName = s.SharedWithGroup?.Name,
        ExpiresAt = s.ExpiresAt,
        UntilChanged = s.UntilChanged,
        CreatedAt = s.CreatedAt,
        IsRevoked = s.IsRevoked
    };

    private Guid GetUserId() =>
        Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? User.FindFirst("sub")!.Value);

    private string GetIp() => HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
}
