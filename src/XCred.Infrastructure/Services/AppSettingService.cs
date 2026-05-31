using Microsoft.EntityFrameworkCore;
using XCred.Core.Entities;
using XCred.Core.Interfaces;
using XCred.Infrastructure.Data;

namespace XCred.Infrastructure.Services;

public class AppSettingService(AppDbContext db) : IAppSettingService
{
    public async Task<string?> GetAsync(string key)
    {
        var setting = await db.AppSettings.AsNoTracking().FirstOrDefaultAsync(s => s.Key == key);
        return setting?.Value;
    }

    public async Task<T> GetAsync<T>(string key, T defaultValue)
    {
        var value = await GetAsync(key);
        if (value == null) return defaultValue;
        try
        {
            return (T)Convert.ChangeType(value, typeof(T));
        }
        catch
        {
            return defaultValue;
        }
    }

    public async Task SetAsync(string key, string value)
    {
        var setting = await db.AppSettings.FirstOrDefaultAsync(s => s.Key == key);
        if (setting == null)
        {
            db.AppSettings.Add(new AppSetting { Key = key, Value = value, UpdatedAt = DateTime.UtcNow });
        }
        else
        {
            setting.Value = value;
            setting.UpdatedAt = DateTime.UtcNow;
        }
        await db.SaveChangesAsync();
    }
}
