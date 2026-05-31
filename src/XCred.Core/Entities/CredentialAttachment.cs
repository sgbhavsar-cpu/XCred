namespace XCred.Core.Entities;

public class CredentialAttachment
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid CredentialId { get; set; }
    public Credential Credential { get; set; } = null!;

    // All metadata is encrypted client-side
    public string EncryptedFileName { get; set; } = string.Empty;
    public string FileNameIv { get; set; } = string.Empty;
    public string EncryptedMimeType { get; set; } = string.Empty;
    public string MimeTypeIv { get; set; } = string.Empty;
    public string EncryptedData { get; set; } = string.Empty;
    public string DataIv { get; set; } = string.Empty;

    // Stored plaintext — file size is not sensitive
    public long FileSizeBytes { get; set; }

    public DateTime UploadedAt { get; set; } = DateTime.UtcNow;
    public Guid UploadedById { get; set; }
}
