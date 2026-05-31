using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using XCred.Core.Constants;
using XCred.Core.DTOs.Common;
using XCred.Core.DTOs.Groups;
using XCred.Core.Entities;
using XCred.Core.Interfaces;
using XCred.Infrastructure.Data;

namespace XCred.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/groups")]
public class GroupsController(AppDbContext db, IAuditService audit) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<ApiResponse<IEnumerable<GroupDto>>>> GetAll()
    {
        var userId = GetUserId();
        var myGroupIds = await db.GroupMembers
            .Where(gm => gm.UserId == userId)
            .Select(gm => gm.GroupId)
            .ToListAsync();

        var groups = await db.Groups
            .AsNoTracking()
            .Include(g => g.Members).ThenInclude(m => m.User)
            .Where(g => myGroupIds.Contains(g.Id))
            .ToListAsync();

        return Ok(ApiResponse<IEnumerable<GroupDto>>.Ok(groups.Select(g => MapToDto(g, userId))));
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<ApiResponse<GroupDto>>> GetById(Guid id)
    {
        var userId = GetUserId();
        var group = await db.Groups
            .AsNoTracking()
            .Include(g => g.Members).ThenInclude(m => m.User)
            .FirstOrDefaultAsync(g => g.Id == id);

        if (group == null) return NotFound(ApiResponse<GroupDto>.Fail("NOT_FOUND", "Group not found."));
        if (!group.Members.Any(m => m.UserId == userId))
            return Forbid();

        return Ok(ApiResponse<GroupDto>.Ok(MapToDto(group, userId)));
    }

    [HttpPost]
    public async Task<ActionResult<ApiResponse<GroupDto>>> Create([FromBody] CreateGroupRequest req)
    {
        var userId = GetUserId();
        var group = new Group
        {
            Name = req.Name.Trim(),
            Description = req.Description,
            CreatedById = userId
        };

        group.Members.Add(new GroupMember { UserId = userId, Role = "Admin" });

        foreach (var memberId in req.MemberIds.Where(id => id != userId))
        {
            if (await db.Users.AnyAsync(u => u.Id == memberId && u.IsActive && u.IsApproved))
                group.Members.Add(new GroupMember { UserId = memberId, Role = "Member" });
        }

        db.Groups.Add(group);
        await db.SaveChangesAsync();
        await audit.LogAsync(userId, AuditActions.GroupCreated, "Group", group.Id, req.Name, GetIp());

        var created = await db.Groups
            .Include(g => g.Members).ThenInclude(m => m.User)
            .FirstAsync(g => g.Id == group.Id);

        return CreatedAtAction(nameof(GetById), new { id = group.Id }, ApiResponse<GroupDto>.Ok(MapToDto(created, userId)));
    }

    [HttpPost("{id:guid}/members/{memberId:guid}")]
    public async Task<ActionResult<ApiResponse<string>>> AddMember(Guid id, Guid memberId)
    {
        var userId = GetUserId();
        var myMembership = await db.GroupMembers.FirstOrDefaultAsync(gm => gm.GroupId == id && gm.UserId == userId);
        if (myMembership?.Role != "Admin" && !User.IsInRole(Roles.Admin))
            return Forbid();

        if (await db.GroupMembers.AnyAsync(gm => gm.GroupId == id && gm.UserId == memberId))
            return Conflict(ApiResponse<string>.Fail("ALREADY_MEMBER", "User is already a member."));

        if (!await db.Users.AnyAsync(u => u.Id == memberId && u.IsActive && u.IsApproved))
            return NotFound(ApiResponse<string>.Fail("USER_NOT_FOUND", "User not found."));

        db.GroupMembers.Add(new GroupMember { GroupId = id, UserId = memberId, Role = "Member" });
        await db.SaveChangesAsync();
        await audit.LogAsync(userId, AuditActions.GroupMemberAdded, "Group", id, memberId.ToString(), GetIp());

        return Ok(ApiResponse<string>.Ok("Member added."));
    }

    [HttpDelete("{id:guid}/members/{memberId:guid}")]
    public async Task<ActionResult<ApiResponse<string>>> RemoveMember(Guid id, Guid memberId)
    {
        var userId = GetUserId();
        var myMembership = await db.GroupMembers.FirstOrDefaultAsync(gm => gm.GroupId == id && gm.UserId == userId);
        if (myMembership?.Role != "Admin" && !User.IsInRole(Roles.Admin) && memberId != userId)
            return Forbid();

        var member = await db.GroupMembers.FirstOrDefaultAsync(gm => gm.GroupId == id && gm.UserId == memberId);
        if (member == null) return NotFound();

        db.GroupMembers.Remove(member);
        await db.SaveChangesAsync();
        await audit.LogAsync(userId, AuditActions.GroupMemberRemoved, "Group", id, memberId.ToString(), GetIp());

        return Ok(ApiResponse<string>.Ok("Member removed."));
    }

    [HttpDelete("{id:guid}")]
    [Authorize(Roles = Roles.Admin)]
    public async Task<ActionResult<ApiResponse<string>>> Delete(Guid id)
    {
        var userId = GetUserId();
        var group = await db.Groups.FirstOrDefaultAsync(g => g.Id == id);
        if (group == null) return NotFound();

        db.Groups.Remove(group);
        await db.SaveChangesAsync();
        await audit.LogAsync(userId, AuditActions.GroupDeleted, "Group", id, group.Name, GetIp());
        return Ok(ApiResponse<string>.Ok("Group deleted."));
    }

    private static GroupDto MapToDto(Group g, Guid currentUserId) => new()
    {
        Id = g.Id,
        Name = g.Name,
        Description = g.Description,
        MemberCount = g.Members.Count,
        MyRole = g.Members.FirstOrDefault(m => m.UserId == currentUserId)?.Role ?? "Member",
        CreatedAt = g.CreatedAt,
        Members = g.Members.Select(m => new GroupMemberDto
        {
            UserId = m.UserId,
            Username = m.User.Username,
            Email = m.User.Email,
            Role = m.Role,
            JoinedAt = m.JoinedAt
        }).ToList()
    };

    private Guid GetUserId() =>
        Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? User.FindFirst("sub")!.Value);

    private string GetIp() => HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
}
