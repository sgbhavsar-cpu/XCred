namespace XCred.Core.Entities;

public class User
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Username { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;

    // Salt for client-side PBKDF2-SHA256 key derivation — stored server-side, never used for decryption server-side
    public string KeyDerivationSalt { get; set; } = string.Empty;

    // Asymmetric key pair for credential sharing (envelope encryption)
    public string PublicKey { get; set; } = string.Empty;
    public string EncryptedPrivateKey { get; set; } = string.Empty;
    public string PrivateKeyIv { get; set; } = string.Empty;

    public string Role { get; set; } = Constants.Roles.User;
    public bool IsActive { get; set; } = true;
    public bool IsApproved { get; set; } = false;

    public int FailedLoginAttempts { get; set; } = 0;
    public DateTime? LockoutUntil { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? LastLoginAt { get; set; }
    public string? LastLoginIp { get; set; }

    // JSON blob: { "expiryReminders": true, "shareNotifications": true, "securityAlerts": true }
    public string NotificationPreferences { get; set; } = "{\"expiryReminders\":true,\"shareNotifications\":true,\"securityAlerts\":true}";

    public ICollection<Credential> Credentials { get; set; } = [];
    public ICollection<Folder> Folders { get; set; } = [];
    public ICollection<CredentialGroup> CredentialGroups { get; set; } = [];
    public ICollection<Tag> Tags { get; set; } = [];
    public ICollection<GroupMember> GroupMemberships { get; set; } = [];
    public ICollection<RefreshToken> RefreshTokens { get; set; } = [];
    public ICollection<AuditLog> AuditLogs { get; set; } = [];
}
