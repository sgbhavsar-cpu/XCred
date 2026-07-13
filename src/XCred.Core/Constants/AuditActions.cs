namespace XCred.Core.Constants;

public static class AuditActions
{
    public const string LoginSuccess = "LoginSuccess";
    public const string LoginFailed = "LoginFailed";
    public const string Logout = "Logout";
    public const string SessionExpired = "SessionExpired";
    public const string Registered = "Registered";
    public const string AccountApproved = "AccountApproved";
    public const string AccountDeactivated = "AccountDeactivated";
    public const string PasswordChanged = "PasswordChanged";
    public const string MasterPasswordChanged = "MasterPasswordChanged";

    public const string CredentialCreated = "CredentialCreated";
    public const string CredentialViewed = "CredentialViewed";
    public const string CredentialCopied = "CredentialCopied";
    public const string CredentialUpdated = "CredentialUpdated";
    public const string CredentialDeleted = "CredentialDeleted";

    public const string AttachmentUploaded = "AttachmentUploaded";
    public const string AttachmentDownloaded = "AttachmentDownloaded";
    public const string AttachmentDeleted = "AttachmentDeleted";

    public const string ShareCreated = "ShareCreated";
    public const string ShareRevoked = "ShareRevoked";
    public const string ShareAccessed = "ShareAccessed";
    public const string ShareExpired = "ShareExpired";

    public const string GroupCreated = "GroupCreated";
    public const string GroupDeleted = "GroupDeleted";
    public const string GroupMemberAdded = "GroupMemberAdded";
    public const string GroupMemberRemoved = "GroupMemberRemoved";

    public const string CredentialGroupCreated = "CredentialGroupCreated";
    public const string CredentialGroupUpdated = "CredentialGroupUpdated";
    public const string CredentialGroupDeleted = "CredentialGroupDeleted";

    public const string BackupExported = "BackupExported";
    public const string BackupImported = "BackupImported";
}
