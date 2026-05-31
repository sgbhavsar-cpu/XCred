namespace XCred.Core.DTOs.Auth;

public class RegisterRequest
{
    public string FullName { get; set; } = string.Empty;
    public string Username { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;

    // Client-side generated key pair — private key encrypted with Argon2id-derived key
    public string PublicKey { get; set; } = string.Empty;
    public string EncryptedPrivateKey { get; set; } = string.Empty;
    public string PrivateKeyIv { get; set; } = string.Empty;

    // Salt generated client-side for Argon2id — stored server-side, returned on login
    public string KeyDerivationSalt { get; set; } = string.Empty;
}
