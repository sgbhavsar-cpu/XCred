using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using XCred.Core.Entities;

namespace XCred.Infrastructure.Data.Configurations;

public class SharedCredentialConfiguration : IEntityTypeConfiguration<SharedCredential>
{
    public void Configure(EntityTypeBuilder<SharedCredential> builder)
    {
        builder.HasKey(s => s.Id);
        builder.HasIndex(s => s.CredentialId);
        builder.HasIndex(s => s.SharedWithUserId);
        builder.HasIndex(s => s.SharedWithGroupId);

        builder.HasOne(s => s.SharedBy).WithMany()
            .HasForeignKey(s => s.SharedById).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(s => s.SharedWithUser).WithMany()
            .HasForeignKey(s => s.SharedWithUserId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(s => s.SharedWithGroup).WithMany(g => g.SharedCredentials)
            .HasForeignKey(s => s.SharedWithGroupId).OnDelete(DeleteBehavior.Restrict);
    }
}
