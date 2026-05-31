using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using XCred.Core.DTOs.Common;
using XCred.Infrastructure.Data;

namespace XCred.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/users")]
public class UsersController(AppDbContext db) : ControllerBase
{
    /// <summary>
    /// Returns all active, approved users except the caller — used to build the share-with picker.
    /// Public keys are included so the client can perform envelope encryption without a second round-trip.
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<ApiResponse<IEnumerable<UserSummaryDto>>>> GetAll()
    {
        var currentUserId = GetUserId();
        var users = await db.Users.AsNoTracking()
            .Where(u => u.IsActive && u.IsApproved && u.Id != currentUserId)
            .OrderBy(u => u.Username)
            .Select(u => new UserSummaryDto
            {
                Id = u.Id,
                Username = u.Username,
                Email = u.Email,
                PublicKey = u.PublicKey
            })
            .ToListAsync();

        return Ok(ApiResponse<IEnumerable<UserSummaryDto>>.Ok(users));
    }

    [HttpGet("{id:guid}/public-key")]
    public async Task<ActionResult<ApiResponse<string>>> GetPublicKey(Guid id)
    {
        var publicKey = await db.Users.AsNoTracking()
            .Where(u => u.Id == id && u.IsActive && u.IsApproved)
            .Select(u => u.PublicKey)
            .FirstOrDefaultAsync();

        if (publicKey == null)
            return NotFound(ApiResponse<string>.Fail("NOT_FOUND", "User not found."));

        return Ok(ApiResponse<string>.Ok(publicKey));
    }

    private Guid GetUserId() =>
        Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? User.FindFirst("sub")!.Value);
}

public class UserSummaryDto
{
    public Guid Id { get; set; }
    public string Username { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string PublicKey { get; set; } = string.Empty;
}
