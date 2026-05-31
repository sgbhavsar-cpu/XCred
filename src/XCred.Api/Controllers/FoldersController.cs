using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using XCred.Core.DTOs.Common;
using XCred.Core.DTOs.Folders;
using XCred.Core.Entities;
using XCred.Infrastructure.Data;

namespace XCred.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/folders")]
public class FoldersController(AppDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<ApiResponse<IEnumerable<FolderDto>>>> GetAll()
    {
        var userId = GetUserId();

        var credCounts = await db.Credentials
            .Where(c => c.OwnerId == userId && c.FolderId.HasValue)
            .GroupBy(c => c.FolderId!.Value)
            .Select(g => new { FolderId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.FolderId, x => x.Count);

        var all = await db.Folders.AsNoTracking()
            .Where(f => f.OwnerId == userId)
            .ToListAsync();

        var roots = all
            .Where(f => f.ParentFolderId == null)
            .OrderBy(f => f.SortOrder).ThenBy(f => f.Name)
            .ToList();

        return Ok(ApiResponse<IEnumerable<FolderDto>>.Ok(roots.Select(f => MapToDto(f, all, credCounts))));
    }

    [HttpPost]
    public async Task<ActionResult<ApiResponse<FolderDto>>> Create([FromBody] CreateFolderRequest req)
    {
        var userId = GetUserId();

        if (req.ParentFolderId.HasValue)
        {
            var parent = await db.Folders.FirstOrDefaultAsync(f => f.Id == req.ParentFolderId && f.OwnerId == userId);
            if (parent == null)
                return BadRequest(ApiResponse<FolderDto>.Fail("INVALID_PARENT", "Parent folder not found."));
        }

        var folder = new Folder
        {
            Name = req.Name.Trim(),
            OwnerId = userId,
            ParentFolderId = req.ParentFolderId,
            GroupId = req.GroupId
        };

        db.Folders.Add(folder);
        await db.SaveChangesAsync();
        return CreatedAtAction(nameof(GetAll), ApiResponse<FolderDto>.Ok(MapToDto(folder, [], [])));
    }

    [HttpPut("{id:guid}")]
    public async Task<ActionResult<ApiResponse<FolderDto>>> Update(Guid id, [FromBody] UpdateFolderRequest req)
    {
        var userId = GetUserId();
        var folder = await db.Folders.FirstOrDefaultAsync(f => f.Id == id && f.OwnerId == userId);
        if (folder == null) return NotFound(ApiResponse<FolderDto>.Fail("NOT_FOUND", "Folder not found."));

        folder.Name = req.Name.Trim();
        folder.ParentFolderId = req.ParentFolderId;
        folder.SortOrder = req.SortOrder;
        await db.SaveChangesAsync();

        return Ok(ApiResponse<FolderDto>.Ok(MapToDto(folder, [], [])));
    }

    [HttpDelete("{id:guid}")]
    public async Task<ActionResult<ApiResponse<string>>> Delete(Guid id)
    {
        var userId = GetUserId();
        var folder = await db.Folders.FirstOrDefaultAsync(f => f.Id == id && f.OwnerId == userId);
        if (folder == null) return NotFound(ApiResponse<string>.Fail("NOT_FOUND", "Folder not found."));

        // Move credentials out of deleted folder
        await db.Credentials
            .Where(c => c.FolderId == id && c.OwnerId == userId)
            .ExecuteUpdateAsync(s => s.SetProperty(c => c.FolderId, (Guid?)null));

        db.Folders.Remove(folder);
        await db.SaveChangesAsync();
        return Ok(ApiResponse<string>.Ok("Folder deleted."));
    }

    private static FolderDto MapToDto(Folder f, List<Folder> all, Dictionary<Guid, int> credCounts) => new()
    {
        Id = f.Id,
        Name = f.Name,
        ParentFolderId = f.ParentFolderId,
        GroupId = f.GroupId,
        SortOrder = f.SortOrder,
        CreatedAt = f.CreatedAt,
        CredentialCount = credCounts.GetValueOrDefault(f.Id),
        Children = all.Where(c => c.ParentFolderId == f.Id)
            .OrderBy(c => c.SortOrder).ThenBy(c => c.Name)
            .Select(c => MapToDto(c, all, credCounts)).ToList()
    };

    private Guid GetUserId() =>
        Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? User.FindFirst("sub")!.Value);
}
