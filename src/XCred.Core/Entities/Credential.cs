namespace XCred.Core.Entities;

public class Credential
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid OwnerId { get; set; }
    public User Owner { get; set; } = null!;

    // Stored plaintext — type label does not reveal credential contents
    public string Type { get; set; } = string.Empty;

    // AES-256-GCM encrypted JSON blob: name, all type fields, notes, custom fields
    public string EncryptedData { get; set; } = string.Empty;
    public string DataIv { get; set; } = string.Empty;

    // Per-credential symmetric key, encrypted with owner's public key (RSA-OAEP)
    public string EncryptedCredentialKey { get; set; } = string.Empty;

    // Stored plaintext to support server-side expiry alerts
    public DateTime? ExpiryDate { get; set; }

    public Guid? FolderId { get; set; }
    public Folder? Folder { get; set; }

    public Guid? CredentialGroupId { get; set; }
    public CredentialGroup? CredentialGroup { get; set; }

    public bool IsDeleted { get; set; } = false;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    public Guid CreatedById { get; set; }
    public Guid UpdatedById { get; set; }

    public ICollection<CredentialTag> CredentialTags { get; set; } = [];
    public ICollection<CredentialAttachment> Attachments { get; set; } = [];
    public ICollection<SharedCredential> Shares { get; set; } = [];
}
