using XCred.Core.Entities;
using XCred.Core.Interfaces;
using XCred.Infrastructure.Data;

namespace XCred.Infrastructure.Services;

public class AuditService(AppDbContext db) : IAuditService
{
    public async Task LogAsync(Guid? userId, string action, string? resourceType = null,
        Guid? resourceId = null, string? detail = null, string? ipAddress = null)
    {
        db.AuditLogs.Add(new AuditLog
        {
            UserId = userId,
            Action = action,
            ResourceType = resourceType,
            ResourceId = resourceId,
            Detail = detail,
            IpAddress = ipAddress
        });
        await db.SaveChangesAsync();
    }
}
