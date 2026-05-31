using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using XCred.Core.Entities;

namespace XCred.Infrastructure.Data.Configurations;

public class CredentialTagConfiguration : IEntityTypeConfiguration<CredentialTag>
{
    public void Configure(EntityTypeBuilder<CredentialTag> builder)
    {
        builder.HasKey(ct => new { ct.CredentialId, ct.TagId });

        builder.HasOne(ct => ct.Credential).WithMany(c => c.CredentialTags)
            .HasForeignKey(ct => ct.CredentialId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne(ct => ct.Tag).WithMany(t => t.CredentialTags)
            .HasForeignKey(ct => ct.TagId).OnDelete(DeleteBehavior.Cascade);
    }
}
