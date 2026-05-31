using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using XCred.Core.Constants;
using XCred.Core.DTOs.Auth;
using XCred.Core.DTOs.Common;
using XCred.Core.Entities;
using XCred.Core.Exceptions;
using XCred.Core.Interfaces;
using XCred.Infrastructure.Data;

namespace XCred.Api.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController(
    AppDbContext db,
    ITokenService tokenService,
    IAuditService audit,
    IAppSettingService settings,
    IEmailService email,
    IConfiguration config) : ControllerBase
{
    [HttpPost("register")]
    public async Task<ActionResult<ApiResponse<string>>> Register([FromBody] RegisterRequest req)
    {
        if (await db.Users.AnyAsync(u => u.Username == req.Username))
            return Conflict(ApiResponse<string>.Fail("USERNAME_TAKEN", "Username is already taken."));

        if (await db.Users.AnyAsync(u => u.Email == req.Email))
            return Conflict(ApiResponse<string>.Fail("EMAIL_TAKEN", "Email is already registered."));

        var isFirstUser = !await db.Users.AnyAsync();
        var user = new User
        {
            Username = req.Username,
            Email = req.Email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.Password, workFactor: 12),
            KeyDerivationSalt = req.KeyDerivationSalt,
            PublicKey = req.PublicKey,
            EncryptedPrivateKey = req.EncryptedPrivateKey,
            PrivateKeyIv = req.PrivateKeyIv,
            Role = isFirstUser ? Roles.Admin : Roles.User,
            IsApproved = isFirstUser
        };

        db.Users.Add(user);
        await db.SaveChangesAsync();
        await audit.LogAsync(user.Id, AuditActions.Registered, "User", user.Id, user.Username, GetIp());

        return Ok(ApiResponse<string>.Ok(isFirstUser
            ? "Account created. You are the first user and have been granted admin access."
            : "Account created. Awaiting admin approval before you can log in."));
    }

    [HttpPost("login")]
    public async Task<ActionResult<ApiResponse<AuthResponse>>> Login([FromBody] LoginRequest req)
    {
        var user = await db.Users.FirstOrDefaultAsync(u => u.Username == req.Username);
        var ip = GetIp();

        if (user == null || !BCrypt.Net.BCrypt.Verify(req.Password, user.PasswordHash))
        {
            if (user != null)
            {
                var maxAttempts = await settings.GetAsync(AppSettingKeys.MaxFailedLoginAttempts, 5);
                user.FailedLoginAttempts++;
                if (user.FailedLoginAttempts >= maxAttempts)
                {
                    var lockMinutes = await settings.GetAsync(AppSettingKeys.LockoutDurationMinutes, 15);
                    user.LockoutUntil = DateTime.UtcNow.AddMinutes(lockMinutes);
                    await db.SaveChangesAsync();
                    await email.SendFailedLoginAlertAsync(user.Email, user.Username, ip);
                }
                else
                {
                    await db.SaveChangesAsync();
                }
                await audit.LogAsync(user.Id, AuditActions.LoginFailed, "User", user.Id, ip, ip);
            }
            return Unauthorized(ApiResponse<AuthResponse>.Fail("INVALID_CREDENTIALS", "Invalid username or password."));
        }

        if (user.LockoutUntil.HasValue && user.LockoutUntil > DateTime.UtcNow)
            return Unauthorized(ApiResponse<AuthResponse>.Fail("ACCOUNT_LOCKED",
                $"Account locked until {user.LockoutUntil:u}. Check your email."));

        if (!user.IsActive)
            return Unauthorized(ApiResponse<AuthResponse>.Fail("ACCOUNT_INACTIVE", "Account has been deactivated."));

        if (!user.IsApproved)
            return Unauthorized(ApiResponse<AuthResponse>.Fail("PENDING_APPROVAL", "Your account is awaiting admin approval."));

        user.FailedLoginAttempts = 0;
        user.LockoutUntil = null;
        user.LastLoginAt = DateTime.UtcNow;
        user.LastLoginIp = ip;

        var (refreshTokenPlain, refreshTokenHash) = tokenService.GenerateRefreshToken();
        var refreshDays = int.Parse(config["Jwt:RefreshTokenDays"] ?? "7");

        db.RefreshTokens.Add(new RefreshToken
        {
            UserId = user.Id,
            TokenHash = refreshTokenHash,
            ExpiresAt = DateTime.UtcNow.AddDays(refreshDays),
            IpAddress = ip,
            UserAgent = Request.Headers.UserAgent.ToString()
        });

        await db.SaveChangesAsync();
        await audit.LogAsync(user.Id, AuditActions.LoginSuccess, "User", user.Id, ip, ip);

        var accessTokenMinutes = int.Parse(config["Jwt:AccessTokenMinutes"] ?? "15");

        return Ok(ApiResponse<AuthResponse>.Ok(new AuthResponse
        {
            AccessToken = tokenService.GenerateAccessToken(user),
            RefreshToken = refreshTokenPlain,
            ExpiresAt = DateTime.UtcNow.AddMinutes(accessTokenMinutes),
            KeyDerivationSalt = user.KeyDerivationSalt,
            PublicKey = user.PublicKey,
            EncryptedPrivateKey = user.EncryptedPrivateKey,
            PrivateKeyIv = user.PrivateKeyIv,
            User = new UserInfo
            {
                Id = user.Id,
                Username = user.Username,
                Email = user.Email,
                FullName = user.Username,
                Role = user.Role
            }
        }));
    }

    [HttpPost("refresh")]
    public async Task<ActionResult<ApiResponse<AuthResponse>>> Refresh([FromBody] RefreshTokenRequest req)
    {
        var hash = Convert.ToBase64String(SHA256.HashData(Encoding.UTF8.GetBytes(req.RefreshToken)));
        var token = await db.RefreshTokens
            .Include(r => r.User)
            .FirstOrDefaultAsync(r => r.TokenHash == hash && !r.IsRevoked && r.ExpiresAt > DateTime.UtcNow);

        if (token == null)
            return Unauthorized(ApiResponse<AuthResponse>.Fail("INVALID_TOKEN", "Refresh token is invalid or expired."));

        if (!token.User.IsActive || !token.User.IsApproved)
            return Unauthorized(ApiResponse<AuthResponse>.Fail("ACCOUNT_INACTIVE", "Account is inactive."));

        token.IsRevoked = true;

        var (newTokenPlain, newTokenHash) = tokenService.GenerateRefreshToken();
        var refreshDays = int.Parse(config["Jwt:RefreshTokenDays"] ?? "7");
        db.RefreshTokens.Add(new RefreshToken
        {
            UserId = token.UserId,
            TokenHash = newTokenHash,
            ExpiresAt = DateTime.UtcNow.AddDays(refreshDays),
            IpAddress = GetIp(),
            UserAgent = Request.Headers.UserAgent.ToString()
        });

        await db.SaveChangesAsync();

        var accessTokenMinutes = int.Parse(config["Jwt:AccessTokenMinutes"] ?? "15");
        return Ok(ApiResponse<AuthResponse>.Ok(new AuthResponse
        {
            AccessToken = tokenService.GenerateAccessToken(token.User),
            RefreshToken = newTokenPlain,
            ExpiresAt = DateTime.UtcNow.AddMinutes(accessTokenMinutes),
            KeyDerivationSalt = token.User.KeyDerivationSalt,
            PublicKey = token.User.PublicKey,
            EncryptedPrivateKey = token.User.EncryptedPrivateKey,
            PrivateKeyIv = token.User.PrivateKeyIv,
            User = new UserInfo
            {
                Id = token.User.Id,
                Username = token.User.Username,
                Email = token.User.Email,
                FullName = token.User.Username,
                Role = token.User.Role
            }
        }));
    }

    [Authorize]
    [HttpPost("logout")]
    public async Task<ActionResult<ApiResponse<string>>> Logout([FromBody] RefreshTokenRequest req)
    {
        var hash = Convert.ToBase64String(SHA256.HashData(Encoding.UTF8.GetBytes(req.RefreshToken)));
        var token = await db.RefreshTokens.FirstOrDefaultAsync(r => r.TokenHash == hash);
        if (token != null)
        {
            token.IsRevoked = true;
            await db.SaveChangesAsync();
        }
        var userId = GetCurrentUserId();
        await audit.LogAsync(userId, AuditActions.Logout, "User", userId, null, GetIp());
        return Ok(ApiResponse<string>.Ok("Logged out successfully."));
    }

    [Authorize]
    [HttpPost("change-password")]
    public async Task<ActionResult<ApiResponse<string>>> ChangePassword([FromBody] ChangePasswordRequest req)
    {
        var userId = GetCurrentUserId()!.Value;
        var user = await db.Users.FindAsync(userId);
        if (user == null) return NotFound();

        if (!BCrypt.Net.BCrypt.Verify(req.CurrentPassword, user.PasswordHash))
            return Unauthorized(ApiResponse<string>.Fail("INVALID_PASSWORD", "Current password is incorrect."));

        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.NewPassword, workFactor: 12);
        await db.SaveChangesAsync();
        await audit.LogAsync(userId, AuditActions.PasswordChanged, "User", userId, null, GetIp());
        return Ok(ApiResponse<string>.Ok("Password changed successfully."));
    }

    [Authorize]
    [HttpPost("change-master-key")]
    public async Task<ActionResult<ApiResponse<string>>> ChangeMasterKey([FromBody] ChangeMasterKeyRequest req)
    {
        var userId = GetCurrentUserId()!.Value;
        var user = await db.Users.FindAsync(userId);
        if (user == null) return NotFound();

        user.PublicKey = req.NewPublicKey;
        user.EncryptedPrivateKey = req.NewEncryptedPrivateKey;
        user.PrivateKeyIv = req.NewPrivateKeyIv;
        user.KeyDerivationSalt = req.NewKeyDerivationSalt;

        foreach (var rc in req.ReEncryptedCredentials)
        {
            var cred = await db.Credentials.FirstOrDefaultAsync(c => c.Id == rc.CredentialId && c.OwnerId == userId);
            if (cred == null) continue;
            cred.EncryptedData = rc.EncryptedData;
            cred.DataIv = rc.DataIv;
            cred.EncryptedCredentialKey = rc.EncryptedCredentialKey;
            cred.UpdatedAt = DateTime.UtcNow;
            cred.UpdatedById = userId;
        }

        await db.SaveChangesAsync();
        await audit.LogAsync(userId, AuditActions.MasterPasswordChanged, "User", userId, null, GetIp());
        return Ok(ApiResponse<string>.Ok("Master key updated successfully."));
    }

    [Authorize]
    [HttpGet("profile")]
    public async Task<ActionResult<ApiResponse<ProfileDto>>> GetProfile()
    {
        var userId = GetCurrentUserId()!.Value;
        var user = await db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId);
        if (user == null) return NotFound();
        return Ok(ApiResponse<ProfileDto>.Ok(new ProfileDto
        {
            Id = user.Id, Username = user.Username, Email = user.Email,
            Role = user.Role, CreatedAt = user.CreatedAt, LastLoginAt = user.LastLoginAt,
            NotificationPreferences = user.NotificationPreferences
        }));
    }

    [Authorize]
    [HttpPut("notification-preferences")]
    public async Task<ActionResult<ApiResponse<string>>> UpdateNotificationPreferences(
        [FromBody] NotificationPreferencesRequest req)
    {
        var userId = GetCurrentUserId()!.Value;
        var user = await db.Users.FindAsync(userId);
        if (user == null) return NotFound();
        user.NotificationPreferences = System.Text.Json.JsonSerializer.Serialize(req);
        await db.SaveChangesAsync();
        return Ok(ApiResponse<string>.Ok("Preferences saved."));
    }

    public record ChangePasswordRequest(string CurrentPassword, string NewPassword);

    private Guid? GetCurrentUserId()
    {
        var sub = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? User.FindFirst("sub")?.Value;
        return sub != null ? Guid.Parse(sub) : null;
    }

    private string GetIp() =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
}

public class ProfileDto
{
    public Guid Id { get; set; }
    public string Username { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Role { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime? LastLoginAt { get; set; }
    public string NotificationPreferences { get; set; } = string.Empty;
}

public class NotificationPreferencesRequest
{
    public bool ExpiryReminders { get; set; } = true;
    public bool ShareNotifications { get; set; } = true;
    public bool SecurityAlerts { get; set; } = true;
}
