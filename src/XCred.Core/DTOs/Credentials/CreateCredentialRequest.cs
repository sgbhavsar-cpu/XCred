namespace XCred.Core.DTOs.Credentials;

public class CreateCredentialRequest
{
    public string Type { get; set; } = string.Empty;
    public string EncryptedData { get; set; } = string.Empty;
    public string DataIv { get; set; } = string.Empty;
    public string EncryptedCredentialKey { get; set; } = string.Empty;
    public DateTime? ExpiryDate { get; set; }
    public Guid? FolderId { get; set; }
    public Guid? CredentialGroupId { get; set; }
    public List<Guid> TagIds { get; set; } = [];
}
