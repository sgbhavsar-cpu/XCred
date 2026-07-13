namespace XCred.Core.Entities;

public class Group
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public Guid CreatedById { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public ICollection<GroupMember> Members { get; set; } = [];
    public ICollection<Folder> Folders { get; set; } = [];
    public ICollection<CredentialGroup> CredentialGroups { get; set; } = [];
    public ICollection<SharedCredential> SharedCredentials { get; set; } = [];
}
