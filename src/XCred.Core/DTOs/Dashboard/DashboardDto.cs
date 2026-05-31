namespace XCred.Core.DTOs.Dashboard;

public class DashboardDto
{
    public int TotalCredentials { get; set; }
    public int SharedWithMe { get; set; }
    public int GroupCount { get; set; }
    public List<ExpiryAlertDto> ExpiredCredentials { get; set; } = [];
    public List<ExpiryAlertDto> ExpiringCredentials { get; set; } = [];
    public List<RecentActivityDto> RecentActivity { get; set; } = [];
    public OrgSettingsDto OrgSettings { get; set; } = null!;
}

public class ExpiryAlertDto
{
    public Guid CredentialId { get; set; }
    public string EncryptedData { get; set; } = string.Empty;
    public string DataIv { get; set; } = string.Empty;
    public string EncryptedCredentialKey { get; set; } = string.Empty;
    public string Type { get; set; } = string.Empty;
    public DateTime ExpiryDate { get; set; }
    public int DaysUntilExpiry { get; set; }
    public Guid? FolderId { get; set; }
}

public class RecentActivityDto
{
    public string Action { get; set; } = string.Empty;
    public string? ResourceType { get; set; }
    public string? Detail { get; set; }
    public DateTime Timestamp { get; set; }
}

public class OrgSettingsDto
{
    public int ClipboardClearSeconds { get; set; }
    public int ExpiryWarningDays { get; set; }
    public int SessionTimeoutMinutes { get; set; }
    public int MaxAttachmentSizeMb { get; set; }
}
