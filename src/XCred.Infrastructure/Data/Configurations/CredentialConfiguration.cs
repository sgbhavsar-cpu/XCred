using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using XCred.Core.Entities;

namespace XCred.Infrastructure.Data.Configurations;

public class CredentialConfiguration : IEntityTypeConfiguration<Credential>
{
    public void Configure(EntityTypeBuilder<Credential> builder)
    {
        builder.HasKey(c => c.Id);
        builder.HasIndex(c => c.OwnerId);
        builder.HasIndex(c => c.FolderId);
        builder.HasIndex(c => c.ExpiryDate);
        builder.HasIndex(c => c.IsDeleted);

        builder.Property(c => c.Type).HasMaxLength(50).IsRequired();
        builder.Property(c => c.EncryptedData).IsRequired();
        builder.Property(c => c.DataIv).HasMaxLength(100).IsRequired();
        builder.Property(c => c.EncryptedCredentialKey).IsRequired();

        builder.HasMany(c => c.Attachments).WithOne(a => a.Credential)
            .HasForeignKey(a => a.CredentialId).OnDelete(DeleteBehavior.Cascade);
        builder.HasMany(c => c.Shares).WithOne(s => s.Credential)
            .HasForeignKey(s => s.CredentialId).OnDelete(DeleteBehavior.Cascade);

        builder.HasQueryFilter(c => !c.IsDeleted);
    }
}
