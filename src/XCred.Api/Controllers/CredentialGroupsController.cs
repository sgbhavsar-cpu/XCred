using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using XCred.Core.Constants;
using XCred.Core.DTOs.Common;
using XCred.Core.DTOs.CredentialGroups;
using XCred.Core.DTOs.Credentials;
using XCred.Core.Entities;
using XCred.Core.Interfaces;
using XCred.Infrastructure.Data;

namespace XCred.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/credential-groups")]
public class CredentialGroupsController(AppDbContext db, IAuditService audit) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<ApiResponse<IEnumerable<CredentialGroupDto>>>> GetAll()
    {
        var userId = GetUserId();
        var myTeamIds = await db.GroupMembers.Where(gm => gm.UserId == userId).Select(gm => gm.GroupId).ToListAsync();

        var groups = await db.CredentialGroups
            .AsNoTracking()
            .Where(cg => cg.OwnerId == userId || (cg.GroupId != null && myTeamIds.Contains(cg.GroupId.Value)))
            .Include(cg => cg.Credentials)
            .OrderBy(cg => cg.Name)
            .ToListAsync();

        return Ok(ApiResponse<IEnumerable<CredentialGroupDto>>.Ok(groups.Select(MapToDto)));
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<ApiResponse<CredentialGroupDetailDto>>> GetById(Guid id)
    {
        var userId = GetUserId();
        var group = await db.CredentialGroups
            .AsNoTracking()
            .Include(cg => cg.Credentials).ThenInclude(c => c.CredentialTags).ThenInclude(ct => ct.Tag)
            .Include(cg => cg.Credentials).ThenInclude(c => c.Attachments)
            .Include(cg => cg.Credentials).ThenInclude(c => c.Owner)
            .Include(cg => cg.Credentials).ThenInclude(c => c.Folder)
            .Include(cg => cg.Credentials).ThenInclude(c => c.Shares)
            .FirstOrDefaultAsync(cg => cg.Id == id);

        if (group == null) return NotFound(ApiResponse<CredentialGroupDetailDto>.Fail("NOT_FOUND", "Credential group not found."));
        if (!await CanAccessAsync(group, userId)) return Forbid();

        var dto = new CredentialGroupDetailDto
        {
            Id = group.Id,
            Name = group.Name,
            Icon = group.Icon,
            GroupId = group.GroupId,
            CredentialCount = group.Credentials.Count,
            CreatedAt = group.CreatedAt,
            UpdatedAt = group.UpdatedAt,
            Credentials = group.Credentials.OrderBy(c => c.Type).Select(MapCredentialToDto).ToList()
        };

        return Ok(ApiResponse<CredentialGroupDetailDto>.Ok(dto));
    }

    [HttpPost]
    public async Task<ActionResult<ApiResponse<CredentialGroupDto>>> Create([FromBody] CreateCredentialGroupRequest req)
    {
        var userId = GetUserId();

        if (string.IsNullOrWhiteSpace(req.Name))
            return BadRequest(ApiResponse<CredentialGroupDto>.Fail("INVALID_NAME", "Name is required."));

        if (req.GroupId.HasValue && !await db.GroupMembers.AnyAsync(gm => gm.GroupId == req.GroupId && gm.UserId == userId))
            return BadRequest(ApiResponse<CredentialGroupDto>.Fail("INVALID_TEAM", "Team not found or not accessible."));

        var group = new CredentialGroup
        {
            Name = req.Name.Trim(),
            Icon = string.IsNullOrWhiteSpace(req.Icon) ? "🏦" : req.Icon,
            OwnerId = req.GroupId.HasValue ? null : userId,
            GroupId = req.GroupId
        };

        db.CredentialGroups.Add(group);
        await db.SaveChangesAsync();
        await audit.LogAsync(userId, AuditActions.CredentialGroupCreated, "CredentialGroup", group.Id, group.Name, GetIp());

        return CreatedAtAction(nameof(GetById), new { id = group.Id }, ApiResponse<CredentialGroupDto>.Ok(MapToDto(group)));
    }

    [HttpPut("{id:guid}")]
    public async Task<ActionResult<ApiResponse<CredentialGroupDto>>> Update(Guid id, [FromBody] UpdateCredentialGroupRequest req)
    {
        var userId = GetUserId();
        var group = await db.CredentialGroups.Include(cg => cg.Credentials).FirstOrDefaultAsync(cg => cg.Id == id);
        if (group == null) return NotFound(ApiResponse<CredentialGroupDto>.Fail("NOT_FOUND", "Credential group not found."));
        if (!await CanAccessAsync(group, userId)) return Forbid();

        if (string.IsNullOrWhiteSpace(req.Name))
            return BadRequest(ApiResponse<CredentialGroupDto>.Fail("INVALID_NAME", "Name is required."));

        group.Name = req.Name.Trim();
        group.Icon = string.IsNullOrWhiteSpace(req.Icon) ? group.Icon : req.Icon;
        group.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync();
        await audit.LogAsync(userId, AuditActions.CredentialGroupUpdated, "CredentialGroup", id, group.Name, GetIp());

        return Ok(ApiResponse<CredentialGroupDto>.Ok(MapToDto(group)));
    }

    [HttpDelete("{id:guid}")]
    public async Task<ActionResult<ApiResponse<string>>> Delete(Guid id)
    {
        var userId = GetUserId();
        var group = await db.CredentialGroups.FirstOrDefaultAsync(cg => cg.Id == id);
        if (group == null) return NotFound(ApiResponse<string>.Fail("NOT_FOUND", "Credential group not found."));
        if (!await CanAccessAsync(group, userId)) return Forbid();

        // Unlink member credentials rather than deleting them
        await db.Credentials
            .Where(c => c.CredentialGroupId == id)
            .ExecuteUpdateAsync(s => s.SetProperty(c => c.CredentialGroupId, (Guid?)null));

        db.CredentialGroups.Remove(group);
        await db.SaveChangesAsync();
        await audit.LogAsync(userId, AuditActions.CredentialGroupDeleted, "CredentialGroup", id, group.Name, GetIp());

        return Ok(ApiResponse<string>.Ok("Credential group deleted."));
    }

    private async Task<bool> CanAccessAsync(CredentialGroup group, Guid userId)
    {
        if (group.OwnerId == userId) return true;
        if (group.GroupId == null) return false;
        return await db.GroupMembers.AnyAsync(gm => gm.GroupId == group.GroupId && gm.UserId == userId);
    }

    private static CredentialGroupDto MapToDto(CredentialGroup cg) => new()
    {
        Id = cg.Id,
        Name = cg.Name,
        Icon = cg.Icon,
        GroupId = cg.GroupId,
        CredentialCount = cg.Credentials.Count,
        CreatedAt = cg.CreatedAt,
        UpdatedAt = cg.UpdatedAt
    };

    private static CredentialDto MapCredentialToDto(Credential c) => new()
    {
        Id = c.Id,
        Type = c.Type,
        EncryptedData = c.EncryptedData,
        DataIv = c.DataIv,
        EncryptedCredentialKey = c.EncryptedCredentialKey,
        ExpiryDate = c.ExpiryDate,
        FolderId = c.FolderId,
        FolderName = c.Folder?.Name,
        OwnerId = c.OwnerId,
        OwnerUsername = c.Owner?.Username ?? string.Empty,
        IsShared = c.Shares.Any(s => !s.IsRevoked),
        CreatedAt = c.CreatedAt,
        UpdatedAt = c.UpdatedAt,
        Tags = c.CredentialTags.Select(ct => new TagDto { Id = ct.Tag.Id, Name = ct.Tag.Name, Color = ct.Tag.Color }).ToList(),
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

    private Guid GetUserId() =>
        Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? User.FindFirst("sub")!.Value);

    private string GetIp() => HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
}
