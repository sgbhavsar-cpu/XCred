namespace XCred.Core.DTOs.Auth;

public class ChangeMasterKeyRequest
{
    // New key material after re-encrypting everything client-side
    public string NewEncryptedPrivateKey { get; set; } = string.Empty;
    public string NewPrivateKeyIv { get; set; } = string.Empty;
    public string NewKeyDerivationSalt { get; set; } = string.Empty;
    public string NewPublicKey { get; set; } = string.Empty;

    // All re-encrypted credentials
    public List<ReEncryptedCredential> ReEncryptedCredentials { get; set; } = [];
}

public class ReEncryptedCredential
{
    public Guid CredentialId { get; set; }
    public string EncryptedData { get; set; } = string.Empty;
    public string DataIv { get; set; } = string.Empty;
    public string EncryptedCredentialKey { get; set; } = string.Empty;
}
