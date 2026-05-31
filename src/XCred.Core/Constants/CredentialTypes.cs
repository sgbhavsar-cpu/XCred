namespace XCred.Core.Constants;

public static class CredentialTypes
{
    public const string WebsiteLogin = "WebsiteLogin";
    public const string Database = "Database";
    public const string ApiKey = "ApiKey";
    public const string SshKey = "SshKey";
    public const string CreditCard = "CreditCard";
    public const string SecureNote = "SecureNote";
    public const string WiFi = "WiFi";
    public const string SoftwareLicense = "SoftwareLicense";
    public const string Certificate = "Certificate";
    public const string EnvironmentVariables = "EnvironmentVariables";
    public const string Generic = "Generic";

    public static readonly string[] All =
    [
        WebsiteLogin, Database, ApiKey, SshKey, CreditCard,
        SecureNote, WiFi, SoftwareLicense, Certificate, EnvironmentVariables, Generic
    ];
}
