using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Configuration;
using MimeKit;
using XCred.Core.Constants;
using XCred.Core.Interfaces;

namespace XCred.Infrastructure.Services;

public class EmailService(IAppSettingService settings, IConfiguration config) : IEmailService
{
    private async Task<(string host, int port, string username, string password, string fromEmail, string fromName, bool useSsl)> GetSmtpSettingsAsync()
    {
        var host = await settings.GetAsync(AppSettingKeys.SmtpHost) ?? config["Email:Host"] ?? string.Empty;
        var portStr = await settings.GetAsync(AppSettingKeys.SmtpPort);
        var port = portStr != null && int.TryParse(portStr, out var p) ? p
            : int.TryParse(config["Email:Port"], out var cfgPort) ? cfgPort : 587;
        var username = await settings.GetAsync(AppSettingKeys.SmtpUsername) ?? config["Email:Username"] ?? string.Empty;
        var password = await settings.GetAsync(AppSettingKeys.SmtpPassword) ?? config["Email:Password"] ?? string.Empty;
        var fromEmail = await settings.GetAsync(AppSettingKeys.SmtpFromEmail) ?? config["Email:FromEmail"] ?? "noreply@xcred.local";
        var fromName = await settings.GetAsync(AppSettingKeys.SmtpFromName) ?? config["Email:FromName"] ?? "XCred Vault";
        var useSslStr = await settings.GetAsync(AppSettingKeys.SmtpUseSsl) ?? config["Email:UseSsl"] ?? "true";
        var useSsl = !bool.TryParse(useSslStr, out var ssl) || ssl;
        return (host, port, username, password, fromEmail, fromName, useSsl);
    }

    private async Task SendAsync(string toEmail, string toName, string subject, string htmlBody, bool throwIfUnconfigured = false)
    {
        var (host, port, username, password, fromEmail, fromName, useSsl) = await GetSmtpSettingsAsync();

        if (string.IsNullOrWhiteSpace(host))
        {
            if (throwIfUnconfigured) throw new InvalidOperationException("SMTP host is not configured.");
            return;
        }

        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(fromName, fromEmail));
        message.To.Add(new MailboxAddress(toName, toEmail));
        message.Subject = subject;
        message.Body = new BodyBuilder { HtmlBody = htmlBody }.ToMessageBody();

        using var client = new SmtpClient();
        await client.ConnectAsync(host, port, useSsl ? SecureSocketOptions.SslOnConnect : SecureSocketOptions.StartTlsWhenAvailable);
        if (!string.IsNullOrEmpty(username))
            await client.AuthenticateAsync(username, password);
        await client.SendAsync(message);
        await client.DisconnectAsync(true);
    }

    public Task SendAccountApprovedAsync(string toEmail, string username) =>
        SendAsync(toEmail, username, "Your XCred account has been approved",
            $"<p>Hi <b>{username}</b>,</p><p>Your XCred account has been approved. You can now log in at the XCred portal.</p>");

    public Task SendAccountDeactivatedAsync(string toEmail, string username) =>
        SendAsync(toEmail, username, "Your XCred account has been deactivated",
            $"<p>Hi <b>{username}</b>,</p><p>Your XCred account has been deactivated. Please contact your administrator for assistance.</p>");

    public Task SendLoginAlertAsync(string toEmail, string username, string ipAddress, DateTime timestamp) =>
        SendAsync(toEmail, username, "New login to your XCred account",
            $"<p>Hi <b>{username}</b>,</p><p>A login to your account was detected from IP <b>{ipAddress}</b> at <b>{timestamp:u}</b>.</p><p>If this was not you, please change your password immediately.</p>");

    public Task SendFailedLoginAlertAsync(string toEmail, string username, string ipAddress) =>
        SendAsync(toEmail, username, "Multiple failed login attempts on your XCred account",
            $"<p>Hi <b>{username}</b>,</p><p>Multiple failed login attempts were detected on your account from IP <b>{ipAddress}</b>. Your account has been temporarily locked.</p>");

    public Task SendShareNotificationAsync(string toEmail, string recipientName, string sharedByName, string credentialType) =>
        SendAsync(toEmail, recipientName, $"{sharedByName} shared a credential with you",
            $"<p>Hi <b>{recipientName}</b>,</p><p><b>{sharedByName}</b> has shared a <b>{credentialType}</b> credential with you in XCred.</p><p>Log in to your vault to view it.</p>");

    public Task SendShareRevokedAsync(string toEmail, string recipientName, string credentialType) =>
        SendAsync(toEmail, recipientName, "A shared credential has been revoked",
            $"<p>Hi <b>{recipientName}</b>,</p><p>Access to a shared <b>{credentialType}</b> credential has been revoked.</p>");

    public Task SendExpiryReminderAsync(string toEmail, string username, string credentialType, DateTime expiryDate, int daysRemaining) =>
        SendAsync(toEmail, username,
            daysRemaining <= 0 ? "Credential expired" : $"Credential expiring in {daysRemaining} day(s)",
            $"<p>Hi <b>{username}</b>,</p><p>A <b>{credentialType}</b> credential in your XCred vault {(daysRemaining <= 0 ? "has expired" : $"will expire in <b>{daysRemaining}</b> day(s)")} on <b>{expiryDate:d}</b>.</p><p>Log in to your vault to take action.</p>");

    public async Task SendExpiryDigestAsync(string adminEmail, IEnumerable<ExpiryDigestItem> items)
    {
        var rows = string.Join("", items.Select(i =>
            $"<tr><td>{i.CredentialType}</td><td>{i.OwnerUsername}</td><td>{i.ExpiryDate:d}</td><td style='color:{(i.IsExpired ? "red" : "orange")}'>{(i.IsExpired ? "Expired" : "Expiring Soon")}</td></tr>"));

        await SendAsync(adminEmail, "Admin",
            "XCred Daily Expiry Digest",
            $"<h2>Credential Expiry Summary</h2><table border='1' cellpadding='4'><tr><th>Type</th><th>Owner</th><th>Expiry</th><th>Status</th></tr>{rows}</table>");
    }

    public Task SendTestEmailAsync(string toEmail, string username) =>
        SendAsync(toEmail, username, "XCred SMTP Test — Configuration Verified",
            $"<p>Hi <b>{username}</b>,</p><p>This is a test email from <b>XCred Vault</b>. Your SMTP settings are configured correctly.</p><p>Sent at {DateTime.UtcNow:u}.</p>",
            throwIfUnconfigured: true);
}
