using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using XCred.Core.Constants;
using XCred.Core.DTOs.Common;
using XCred.Core.DTOs.Dashboard;
using XCred.Core.Interfaces;
using XCred.Infrastructure.Data;

namespace XCred.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/dashboard")]
public class DashboardController(AppDbContext db, IAppSettingService settings) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<ApiResponse<DashboardDto>>> Get()
    {
        var userId = GetUserId();
        var warningDays = await settings.GetAsync(AppSettingKeys.ExpiryWarningDays, 30);
        var now = DateTime.UtcNow.Date;
        var warningDate = now.AddDays(warningDays);

        var totalCredentials = await db.Credentials.CountAsync(c => c.OwnerId == userId);

        var myGroupIds = await db.GroupMembers
            .Where(gm => gm.UserId == userId)
            .Select(gm => gm.GroupId)
            .ToListAsync();

        var sharedWithMe = await db.SharedCredentials.CountAsync(s =>
            !s.IsRevoked
            && (s.ExpiresAt == null || s.ExpiresAt > DateTime.UtcNow)
            && (s.SharedWithUserId == userId || (s.SharedWithGroupId != null && myGroupIds.Contains(s.SharedWithGroupId.Value))));

        var groupCount = myGroupIds.Count;

        var expiredCreds = await db.Credentials
            .Where(c => c.OwnerId == userId && c.ExpiryDate.HasValue && c.ExpiryDate.Value.Date < now)
            .ToListAsync();

        var expiringCreds = await db.Credentials
            .Where(c => c.OwnerId == userId && c.ExpiryDate.HasValue
                && c.ExpiryDate.Value.Date >= now && c.ExpiryDate.Value.Date <= warningDate)
            .ToListAsync();

        var recentActivity = await db.AuditLogs
            .AsNoTracking()
            .Where(a => a.UserId == userId)
            .OrderByDescending(a => a.Timestamp)
            .Take(10)
            .Select(a => new RecentActivityDto
            {
                Action = a.Action,
                ResourceType = a.ResourceType,
                Detail = a.Detail,
                Timestamp = a.Timestamp
            })
            .ToListAsync();

        var orgSettings = new OrgSettingsDto
        {
            ClipboardClearSeconds = await settings.GetAsync(AppSettingKeys.ClipboardClearSeconds, 30),
            ExpiryWarningDays = warningDays,
            SessionTimeoutMinutes = await settings.GetAsync(AppSettingKeys.SessionTimeoutMinutes, 15),
            MaxAttachmentSizeMb = await settings.GetAsync(AppSettingKeys.MaxAttachmentSizeMb, 10)
        };

        return Ok(ApiResponse<DashboardDto>.Ok(new DashboardDto
        {
            TotalCredentials = totalCredentials,
            SharedWithMe = sharedWithMe,
            GroupCount = groupCount,
            ExpiredCredentials = expiredCreds.Select(c => new ExpiryAlertDto
            {
                CredentialId = c.Id,
                EncryptedData = c.EncryptedData,
                DataIv = c.DataIv,
                EncryptedCredentialKey = c.EncryptedCredentialKey,
                Type = c.Type,
                ExpiryDate = c.ExpiryDate!.Value,
                DaysUntilExpiry = (int)(c.ExpiryDate.Value.Date - now).TotalDays,
                FolderId = c.FolderId
            }).ToList(),
            ExpiringCredentials = expiringCreds.Select(c => new ExpiryAlertDto
            {
                CredentialId = c.Id,
                EncryptedData = c.EncryptedData,
                DataIv = c.DataIv,
                EncryptedCredentialKey = c.EncryptedCredentialKey,
                Type = c.Type,
                ExpiryDate = c.ExpiryDate!.Value,
                DaysUntilExpiry = (int)(c.ExpiryDate.Value.Date - now).TotalDays,
                FolderId = c.FolderId
            }).ToList(),
            RecentActivity = recentActivity,
            OrgSettings = orgSettings
        }));
    }

    private Guid GetUserId() =>
        Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? User.FindFirst("sub")!.Value);
}
