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
    public const string BankAccount = "BankAccount";
    public const string MobileBankingPin = "MobileBankingPin";
    public const string NetworkDevice = "NetworkDevice";
    public const string EmailAccount = "EmailAccount";
    public const string IdentityDocument = "IdentityDocument";
    public const string InsurancePolicy = "InsurancePolicy";
    public const string RecoveryCodes = "RecoveryCodes";
    public const string Generic = "Generic";

    public static readonly string[] All =
    [
        WebsiteLogin, Database, ApiKey, SshKey, CreditCard,
        SecureNote, WiFi, SoftwareLicense, Certificate, EnvironmentVariables,
        BankAccount, MobileBankingPin, NetworkDevice, EmailAccount,
        IdentityDocument, InsurancePolicy, RecoveryCodes, Generic
    ];
}
