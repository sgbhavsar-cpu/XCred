namespace XCred.Core.DTOs.Credentials;

public class CredentialDto
{
    public Guid Id { get; set; }
    public string Type { get; set; } = string.Empty;
    public string EncryptedData { get; set; } = string.Empty;
    public string DataIv { get; set; } = string.Empty;
    public string EncryptedCredentialKey { get; set; } = string.Empty;
    public DateTime? ExpiryDate { get; set; }
    public Guid? FolderId { get; set; }
    public string? FolderName { get; set; }
    public Guid? CredentialGroupId { get; set; }
    public string? CredentialGroupName { get; set; }
    public Guid OwnerId { get; set; }
    public string OwnerUsername { get; set; } = string.Empty;
    public bool IsShared { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public List<TagDto> Tags { get; set; } = [];
    public List<AttachmentDto> Attachments { get; set; } = [];
}

public class TagDto
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Color { get; set; } = string.Empty;
    public int CredentialCount { get; set; }
}

public class AttachmentDto
{
    public Guid Id { get; set; }
    public string EncryptedFileName { get; set; } = string.Empty;
    public string FileNameIv { get; set; } = string.Empty;
    public string EncryptedMimeType { get; set; } = string.Empty;
    public string MimeTypeIv { get; set; } = string.Empty;
    public long FileSizeBytes { get; set; }
    public DateTime UploadedAt { get; set; }
}
