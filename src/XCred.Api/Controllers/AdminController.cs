using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using XCred.Core.Constants;
using XCred.Core.DTOs.Common;
using XCred.Core.Interfaces;
using XCred.Infrastructure.Data;

namespace XCred.Api.Controllers;

[Authorize(Roles = Roles.Admin)]
[ApiController]
[Route("api/admin")]
public class AdminController(AppDbContext db, IAuditService audit, IEmailService email, IAppSettingService settings) : ControllerBase
{
    [HttpGet("users")]
    public async Task<ActionResult<ApiResponse<IEnumerable<AdminUserDto>>>> GetUsers(
        [FromQuery] bool includeInactive = false, [FromQuery] bool pendingOnly = false)
    {
        var query = db.Users.AsNoTracking().AsQueryable();
        if (!includeInactive) query = query.Where(u => u.IsActive);
        if (pendingOnly) query = query.Where(u => !u.IsApproved);

        var users = await query
            .OrderBy(u => u.IsApproved).ThenBy(u => u.Username)
            .Select(u => new AdminUserDto
            {
                Id = u.Id,
                Username = u.Username,
                Email = u.Email,
                Role = u.Role,
                IsActive = u.IsActive,
                IsApproved = u.IsApproved,
                CreatedAt = u.CreatedAt,
                LastLoginAt = u.LastLoginAt
            })
            .ToListAsync();

        return Ok(ApiResponse<IEnumerable<AdminUserDto>>.Ok(users));
    }

    [HttpPost("users/{id:guid}/approve")]
    public async Task<ActionResult<ApiResponse<string>>> ApproveUser(Guid id)
    {
        var user = await db.Users.FindAsync(id);
        if (user == null) return NotFound();

        user.IsApproved = true;
        await db.SaveChangesAsync();
        await audit.LogAsync(GetUserId(), AuditActions.AccountApproved, "User", id, user.Username, GetIp());
        await email.SendAccountApprovedAsync(user.Email, user.Username);

        return Ok(ApiResponse<string>.Ok("User approved."));
    }

    [HttpPost("users/{id:guid}/deactivate")]
    public async Task<ActionResult<ApiResponse<string>>> DeactivateUser(Guid id)
    {
        var user = await db.Users.FindAsync(id);
        if (user == null) return NotFound();
        if (user.Id == GetUserId()) return BadRequest(ApiResponse<string>.Fail("SELF_DEACTIVATE", "Cannot deactivate your own account."));

        user.IsActive = false;
        await db.RefreshTokens.Where(r => r.UserId == id).ExecuteUpdateAsync(s => s.SetProperty(r => r.IsRevoked, true));
        await db.SaveChangesAsync();
        await audit.LogAsync(GetUserId(), AuditActions.AccountDeactivated, "User", id, user.Username, GetIp());
        await email.SendAccountDeactivatedAsync(user.Email, user.Username);

        return Ok(ApiResponse<string>.Ok("User deactivated."));
    }

    [HttpPost("users/{id:guid}/activate")]
    public async Task<ActionResult<ApiResponse<string>>> ActivateUser(Guid id)
    {
        var user = await db.Users.FindAsync(id);
        if (user == null) return NotFound();

        user.IsActive = true;
        await db.SaveChangesAsync();
        return Ok(ApiResponse<string>.Ok("User activated."));
    }

    [HttpPost("users/{id:guid}/role")]
    public async Task<ActionResult<ApiResponse<string>>> SetRole(Guid id, [FromBody] SetRoleRequest req)
    {
        if (req.Role != Roles.Admin && req.Role != Roles.User)
            return BadRequest(ApiResponse<string>.Fail("INVALID_ROLE", "Role must be Admin or User."));

        var user = await db.Users.FindAsync(id);
        if (user == null) return NotFound();

        user.Role = req.Role;
        await db.SaveChangesAsync();
        return Ok(ApiResponse<string>.Ok($"Role updated to {req.Role}."));
    }

    [HttpGet("audit-log")]
    public async Task<ActionResult<ApiResponse<PagedResult<AuditLogDto>>>> GetAuditLog(
        [FromQuery] int page = 1, [FromQuery] int pageSize = 50,
        [FromQuery] Guid? userId = null, [FromQuery] string? action = null,
        [FromQuery] DateTime? from = null, [FromQuery] DateTime? to = null)
    {
        var query = db.AuditLogs.AsNoTracking().Include(a => a.User).AsQueryable();

        if (userId.HasValue) query = query.Where(a => a.UserId == userId);
        if (!string.IsNullOrEmpty(action)) query = query.Where(a => a.Action == action);
        if (from.HasValue) query = query.Where(a => a.Timestamp >= from);
        if (to.HasValue) query = query.Where(a => a.Timestamp <= to);

        var total = await query.CountAsync();
        var items = await query
            .OrderByDescending(a => a.Timestamp)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(a => new AuditLogDto
            {
                Id = a.Id,
                Timestamp = a.Timestamp,
                UserId = a.UserId,
                Username = a.User != null ? a.User.Username : null,
                IpAddress = a.IpAddress,
                Action = a.Action,
                ResourceType = a.ResourceType,
                ResourceId = a.ResourceId,
                Detail = a.Detail
            })
            .ToListAsync();

        return Ok(ApiResponse<PagedResult<AuditLogDto>>.Ok(new PagedResult<AuditLogDto>
        {
            Items = items,
            Total = total,
            Page = page,
            PageSize = pageSize
        }));
    }

    [HttpGet("settings")]
    public async Task<ActionResult<ApiResponse<Dictionary<string, string>>>> GetSettings()
    {
        var allSettings = await db.AppSettings.AsNoTracking().ToListAsync();
        var dict = allSettings.ToDictionary(s => s.Key, s => s.Value);
        // Never return SMTP password via API
        dict.Remove(AppSettingKeys.SmtpPassword);
        return Ok(ApiResponse<Dictionary<string, string>>.Ok(dict));
    }

    [HttpPut("settings")]
    public async Task<ActionResult<ApiResponse<string>>> UpdateSettings([FromBody] Dictionary<string, string> updates)
    {
        foreach (var (key, value) in updates)
            await settings.SetAsync(key, value);

        return Ok(ApiResponse<string>.Ok("Settings updated."));
    }

    [HttpPost("settings/test-email")]
    public async Task<ActionResult<ApiResponse<string>>> SendTestEmail()
    {
        var userId = GetUserId();
        var admin = await db.Users.FindAsync(userId);
        if (admin == null) return NotFound();

        try
        {
            await email.SendTestEmailAsync(admin.Email, admin.Username);
            return Ok(ApiResponse<string>.Ok($"Test email sent to {admin.Email}."));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<string>.Fail("EMAIL_FAILED", ex.Message));
        }
    }

    private Guid GetUserId() =>
        Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value
            ?? User.FindFirst("sub")!.Value);

    private string GetIp() => HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
}

public class AdminUserDto
{
    public Guid Id { get; set; }
    public string Username { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Role { get; set; } = string.Empty;
    public bool IsActive { get; set; }
    public bool IsApproved { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? LastLoginAt { get; set; }
}

public class AuditLogDto
{
    public Guid Id { get; set; }
    public DateTime Timestamp { get; set; }
    public Guid? UserId { get; set; }
    public string? Username { get; set; }
    public string? IpAddress { get; set; }
    public string Action { get; set; } = string.Empty;
    public string? ResourceType { get; set; }
    public Guid? ResourceId { get; set; }
    public string? Detail { get; set; }
}

public class SetRoleRequest
{
    public string Role { get; set; } = string.Empty;
}
