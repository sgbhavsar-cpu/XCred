namespace XCred.Core.Interfaces;

public interface IEmailService
{
    Task SendAccountApprovedAsync(string toEmail, string username);
    Task SendAccountDeactivatedAsync(string toEmail, string username);
    Task SendLoginAlertAsync(string toEmail, string username, string ipAddress, DateTime timestamp);
    Task SendFailedLoginAlertAsync(string toEmail, string username, string ipAddress);
    Task SendShareNotificationAsync(string toEmail, string recipientName, string sharedByName, string credentialType);
    Task SendShareRevokedAsync(string toEmail, string recipientName, string credentialType);
    Task SendExpiryReminderAsync(string toEmail, string username, string credentialType, DateTime expiryDate, int daysRemaining);
    Task SendExpiryDigestAsync(string adminEmail, IEnumerable<ExpiryDigestItem> items);
    Task SendTestEmailAsync(string toEmail, string username);
}

public record ExpiryDigestItem(string CredentialType, DateTime ExpiryDate, string OwnerUsername, bool IsExpired);
