using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using XCred.Core.Entities;

namespace XCred.Infrastructure.Data.Configurations;

public class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.HasKey(u => u.Id);
        builder.HasIndex(u => u.Username).IsUnique();
        builder.HasIndex(u => u.Email).IsUnique();
        builder.Property(u => u.Username).HasMaxLength(100).IsRequired();
        builder.Property(u => u.Email).HasMaxLength(256).IsRequired();
        builder.Property(u => u.PasswordHash).IsRequired();
        builder.Property(u => u.KeyDerivationSalt).IsRequired();
        builder.Property(u => u.PublicKey).IsRequired();
        builder.Property(u => u.EncryptedPrivateKey).IsRequired();
        builder.Property(u => u.PrivateKeyIv).IsRequired();
        builder.Property(u => u.Role).HasMaxLength(20).IsRequired();

        // Prevent cascade delete cycles
        builder.HasMany(u => u.Credentials).WithOne(c => c.Owner)
            .HasForeignKey(c => c.OwnerId).OnDelete(DeleteBehavior.Restrict);
        builder.HasMany(u => u.Folders).WithOne(f => f.Owner)
            .HasForeignKey(f => f.OwnerId).OnDelete(DeleteBehavior.Restrict);
        builder.HasMany(u => u.Tags).WithOne(t => t.Owner)
            .HasForeignKey(t => t.OwnerId).OnDelete(DeleteBehavior.Cascade);
        builder.HasMany(u => u.RefreshTokens).WithOne(r => r.User)
            .HasForeignKey(r => r.UserId).OnDelete(DeleteBehavior.Cascade);
        builder.HasMany(u => u.AuditLogs).WithOne(a => a.User)
            .HasForeignKey(a => a.UserId).OnDelete(DeleteBehavior.SetNull);
    }
}
