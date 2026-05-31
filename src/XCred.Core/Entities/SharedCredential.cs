namespace XCred.Core.Entities;

public class SharedCredential
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid CredentialId { get; set; }
    public Credential Credential { get; set; } = null!;

    public Guid SharedById { get; set; }
    public User SharedBy { get; set; } = null!;

    // Exactly one of these is set
    public Guid? SharedWithUserId { get; set; }
    public User? SharedWithUser { get; set; }
    public Guid? SharedWithGroupId { get; set; }
    public Group? SharedWithGroup { get; set; }

    public string Permission { get; set; } = "Read";  // "Read" only for v1

    // Credential key encrypted with recipient's public key
    public string EncryptedCredentialKey { get; set; } = string.Empty;
    // Re-encrypted credential data for recipient
    public string EncryptedData { get; set; } = string.Empty;
    public string DataIv { get; set; } = string.Empty;

    public DateTime? ExpiresAt { get; set; }
    public bool UntilChanged { get; set; } = false;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public bool IsRevoked { get; set; } = false;
    public DateTime? RevokedAt { get; set; }
}
