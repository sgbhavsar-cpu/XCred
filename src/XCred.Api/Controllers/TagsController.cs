using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using XCred.Core.DTOs.Common;
using XCred.Core.DTOs.Credentials;
using XCred.Core.Entities;
using XCred.Infrastructure.Data;

namespace XCred.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/tags")]
public class TagsController(AppDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<ApiResponse<IEnumerable<TagDto>>>> GetAll()
    {
        var userId = GetUserId();

        var tagCounts = await db.CredentialTags
            .Where(ct => ct.Tag.OwnerId == userId)
            .GroupBy(ct => ct.TagId)
            .Select(g => new { TagId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.TagId, x => x.Count);

        var tags = await db.Tags.AsNoTracking()
            .Where(t => t.OwnerId == userId)
            .OrderBy(t => t.Name)
            .ToListAsync();

        return Ok(ApiResponse<IEnumerable<TagDto>>.Ok(tags.Select(t => new TagDto
        {
            Id = t.Id,
            Name = t.Name,
            Color = t.Color,
            CredentialCount = tagCounts.GetValueOrDefault(t.Id)
        })));
    }

    [HttpPost]
    public async Task<ActionResult<ApiResponse<TagDto>>> Create([FromBody] CreateTagRequest req)
    {
        var userId = GetUserId();
        if (await db.Tags.AnyAsync(t => t.OwnerId == userId && t.Name == req.Name))
            return Conflict(ApiResponse<TagDto>.Fail("DUPLICATE_TAG", "A tag with this name already exists."));

        var tag = new Tag { OwnerId = userId, Name = req.Name.Trim(), Color = req.Color };
        db.Tags.Add(tag);
        await db.SaveChangesAsync();
        return Ok(ApiResponse<TagDto>.Ok(new TagDto { Id = tag.Id, Name = tag.Name, Color = tag.Color }));
    }

    [HttpPut("{id:guid}")]
    public async Task<ActionResult<ApiResponse<TagDto>>> Update(Guid id, [FromBody] CreateTagRequest req)
    {
        var userId = GetUserId();
        var tag = await db.Tags.FirstOrDefaultAsync(t => t.Id == id && t.OwnerId == userId);
        if (tag == null) return NotFound(ApiResponse<TagDto>.Fail("NOT_FOUND", "Tag not found."));

        tag.Name = req.Name.Trim();
        tag.Color = req.Color;
        await db.SaveChangesAsync();
        return Ok(ApiResponse<TagDto>.Ok(new TagDto { Id = tag.Id, Name = tag.Name, Color = tag.Color }));
    }

    [HttpDelete("{id:guid}")]
    public async Task<ActionResult<ApiResponse<string>>> Delete(Guid id)
    {
        var userId = GetUserId();
        var tag = await db.Tags.FirstOrDefaultAsync(t => t.Id == id && t.OwnerId == userId);
        if (tag == null) return NotFound(ApiResponse<string>.Fail("NOT_FOUND", "Tag not found."));

        db.Tags.Remove(tag);
        await db.SaveChangesAsync();
        return Ok(ApiResponse<string>.Ok("Tag deleted."));
    }

    private Guid GetUserId() =>
        Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? User.FindFirst("sub")!.Value);
}

public class CreateTagRequest
{
    public string Name { get; set; } = string.Empty;
    public string Color { get; set; } = "#6366f1";
}
