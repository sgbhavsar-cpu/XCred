using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using XCred.Core.Entities;

namespace XCred.Infrastructure.Data.Configurations;

public class GroupMemberConfiguration : IEntityTypeConfiguration<GroupMember>
{
    public void Configure(EntityTypeBuilder<GroupMember> builder)
    {
        builder.HasKey(gm => new { gm.GroupId, gm.UserId });

        builder.HasOne(gm => gm.Group).WithMany(g => g.Members)
            .HasForeignKey(gm => gm.GroupId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne(gm => gm.User).WithMany(u => u.GroupMemberships)
            .HasForeignKey(gm => gm.UserId).OnDelete(DeleteBehavior.Cascade);
    }
}
