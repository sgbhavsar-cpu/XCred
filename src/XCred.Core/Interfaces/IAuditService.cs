namespace XCred.Core.Interfaces;

public interface IAuditService
{
    Task LogAsync(Guid? userId, string action, string? resourceType = null, Guid? resourceId = null, string? detail = null, string? ipAddress = null);
}
