using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using XCred.Core.Constants;
using XCred.Core.Interfaces;
using XCred.Infrastructure.Data;

namespace XCred.Infrastructure.Services;

public class ExpiryNotificationService(
    IServiceScopeFactory scopeFactory,
    ILogger<ExpiryNotificationService> logger) : BackgroundService
{
    // Reminder thresholds in days before expiry
    private static readonly int[] ReminderDays = [30, 14, 7, 1, 0];

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // Brief startup delay so the app is fully initialised before the first run
        await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);

        while (!stoppingToken.IsCancellationRequested)
        {
            await RunAsync();

            // Calculate delay until next midnight UTC
            var now = DateTime.UtcNow;
            var nextRun = now.Date.AddDays(1);
            var delay = nextRun - now;
            await Task.Delay(delay, stoppingToken);
        }
    }

    private async Task RunAsync()
    {
        try
        {
            using var scope = scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var emailService = scope.ServiceProvider.GetRequiredService<IEmailService>();
            var settings = scope.ServiceProvider.GetRequiredService<IAppSettingService>();

            var warningDays = await settings.GetAsync(AppSettingKeys.ExpiryWarningDays, 30);
            var today = DateTime.UtcNow.Date;

            // Load credentials that have an expiry date within the warning window
            var expiring = await db.Credentials
                .AsNoTracking()
                .Where(c => c.ExpiryDate.HasValue && c.ExpiryDate.Value.Date >= today
                            && c.ExpiryDate.Value.Date <= today.AddDays(warningDays))
                .Include(c => c.Owner)
                .ToListAsync();

            // Also load already-expired (for digest only, not per-credential emails)
            var expired = await db.Credentials
                .AsNoTracking()
                .Where(c => c.ExpiryDate.HasValue && c.ExpiryDate.Value.Date < today)
                .Include(c => c.Owner)
                .ToListAsync();

            // Send per-owner reminders only for threshold days
            foreach (var cred in expiring)
            {
                var daysLeft = (int)(cred.ExpiryDate!.Value.Date - today).TotalDays;
                if (!ReminderDays.Contains(daysLeft)) continue;

                try
                {
                    await emailService.SendExpiryReminderAsync(
                        cred.Owner.Email,
                        cred.Owner.Username,
                        cred.Type,
                        cred.ExpiryDate.Value,
                        daysLeft);
                }
                catch (Exception ex)
                {
                    logger.LogWarning(ex, "Failed to send expiry reminder for credential {Id}", cred.Id);
                }
            }

            // Build and send admin digest
            var admins = await db.Users.AsNoTracking()
                .Where(u => u.Role == Roles.Admin && u.IsActive && u.IsApproved)
                .ToListAsync();

            var digestItems = expired
                .Select(c => new ExpiryDigestItem(c.Type, c.ExpiryDate!.Value, c.Owner.Username, IsExpired: true))
                .Concat(expiring.Select(c =>
                    new ExpiryDigestItem(c.Type, c.ExpiryDate!.Value, c.Owner.Username, IsExpired: false)))
                .ToList();

            if (digestItems.Count > 0)
            {
                foreach (var admin in admins)
                {
                    try
                    {
                        await emailService.SendExpiryDigestAsync(admin.Email, digestItems);
                    }
                    catch (Exception ex)
                    {
                        logger.LogWarning(ex, "Failed to send admin digest to {Email}", admin.Email);
                    }
                }
            }

            logger.LogInformation(
                "Expiry notification run complete. Checked {Count} expiring credentials, sent digest to {AdminCount} admin(s).",
                expiring.Count, admins.Count);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Expiry notification service encountered an error");
        }
    }
}
