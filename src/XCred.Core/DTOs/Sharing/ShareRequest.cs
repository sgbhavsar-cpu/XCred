namespace XCred.Core.DTOs.Sharing;

public class ShareCredentialRequest
{
    public Guid? SharedWithUserId { get; set; }
    public Guid? SharedWithGroupId { get; set; }
    public DateTime? ExpiresAt { get; set; }
    public bool UntilChanged { get; set; } = false;

    // Re-encrypted credential data for the recipient
    public string EncryptedData { get; set; } = string.Empty;
    public string DataIv { get; set; } = string.Empty;
    // Credential key encrypted with recipient's public key
    public string EncryptedCredentialKey { get; set; } = string.Empty;
}

public class SharedCredentialDto
{
    public Guid Id { get; set; }
    public Guid CredentialId { get; set; }
    public string EncryptedData { get; set; } = string.Empty;
    public string DataIv { get; set; } = string.Empty;
    public string EncryptedCredentialKey { get; set; } = string.Empty;
    public string CredentialType { get; set; } = string.Empty;
    public string SharedByUsername { get; set; } = string.Empty;
    public Guid? SharedWithUserId { get; set; }
    public string? SharedWithUsername { get; set; }
    public Guid? SharedWithGroupId { get; set; }
    public string? SharedWithGroupName { get; set; }
    public DateTime? ExpiresAt { get; set; }
    public bool UntilChanged { get; set; }
    public DateTime CreatedAt { get; set; }
    public bool IsRevoked { get; set; }
}
