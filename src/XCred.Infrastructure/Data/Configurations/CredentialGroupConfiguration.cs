using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using XCred.Core.Entities;

namespace XCred.Infrastructure.Data.Configurations;

public class CredentialGroupConfiguration : IEntityTypeConfiguration<CredentialGroup>
{
    public void Configure(EntityTypeBuilder<CredentialGroup> builder)
    {
        builder.HasKey(cg => cg.Id);
        builder.HasIndex(cg => cg.OwnerId);
        builder.HasIndex(cg => cg.GroupId);

        builder.Property(cg => cg.Name).HasMaxLength(200).IsRequired();
        builder.Property(cg => cg.Icon).HasMaxLength(20).IsRequired();

        builder.HasOne(cg => cg.Owner).WithMany(u => u.CredentialGroups)
            .HasForeignKey(cg => cg.OwnerId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(cg => cg.Group).WithMany(g => g.CredentialGroups)
            .HasForeignKey(cg => cg.GroupId).OnDelete(DeleteBehavior.Restrict);

        builder.HasMany(cg => cg.Credentials).WithOne(c => c.CredentialGroup)
            .HasForeignKey(c => c.CredentialGroupId).OnDelete(DeleteBehavior.ClientSetNull);
    }
}
