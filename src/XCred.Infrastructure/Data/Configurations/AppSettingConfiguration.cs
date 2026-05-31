using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using XCred.Core.Constants;
using XCred.Core.Entities;

namespace XCred.Infrastructure.Data.Configurations;

public class AppSettingConfiguration : IEntityTypeConfiguration<AppSetting>
{
    public void Configure(EntityTypeBuilder<AppSetting> builder)
    {
        builder.HasKey(s => s.Key);
        builder.Property(s => s.Key).HasMaxLength(100);
        builder.Property(s => s.Value).HasMaxLength(1000);

        var seedDate = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc);
        builder.HasData(
            new AppSetting { Key = AppSettingKeys.SessionTimeoutMinutes, Value = "15", UpdatedAt = seedDate },
            new AppSetting { Key = AppSettingKeys.ClipboardClearSeconds, Value = "30", UpdatedAt = seedDate },
            new AppSetting { Key = AppSettingKeys.ExpiryWarningDays, Value = "30", UpdatedAt = seedDate },
            new AppSetting { Key = AppSettingKeys.MaxAttachmentSizeMb, Value = "10", UpdatedAt = seedDate },
            new AppSetting { Key = AppSettingKeys.MaxFailedLoginAttempts, Value = "5", UpdatedAt = seedDate },
            new AppSetting { Key = AppSettingKeys.LockoutDurationMinutes, Value = "15", UpdatedAt = seedDate }
        );
    }
}
