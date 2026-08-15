using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using XCred.Core.Entities;

namespace XCred.Infrastructure.Data;

// Constructor takes the non-generic DbContextOptions (not DbContextOptions<AppDbContext>)
// deliberately — this is what lets SqliteAppDbContext subclass it for EF Core's
// multi-provider migrations pattern (each provider's migrations are scoped by the
// concrete DbContext type via the [DbContext(typeof(...))] designer attribute). See
// SqliteAppDbContext.cs.
public class AppDbContext(DbContextOptions options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<Credential> Credentials => Set<Credential>();
    public DbSet<CredentialAttachment> CredentialAttachments => Set<CredentialAttachment>();
    public DbSet<Folder> Folders => Set<Folder>();
    public DbSet<CredentialGroup> CredentialGroups => Set<CredentialGroup>();
    public DbSet<Tag> Tags => Set<Tag>();
    public DbSet<CredentialTag> CredentialTags => Set<CredentialTag>();
    public DbSet<Group> Groups => Set<Group>();
    public DbSet<GroupMember> GroupMembers => Set<GroupMember>();
    public DbSet<SharedCredential> SharedCredentials => Set<SharedCredential>();
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<AppSetting> AppSettings => Set<AppSetting>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
    }

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        // Cascade deletes on related entities handle soft-deleted credentials correctly;
        // suppressing the mismatched-filter warning is intentional here.
        optionsBuilder.ConfigureWarnings(w =>
            w.Ignore(CoreEventId.PossibleIncorrectRequiredNavigationWithQueryFilterInteractionWarning));
    }
}
