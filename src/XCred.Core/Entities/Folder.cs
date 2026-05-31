namespace XCred.Core.Entities;

public class Folder
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = string.Empty;
    public Guid? OwnerId { get; set; }
    public User? Owner { get; set; }
    public Guid? GroupId { get; set; }
    public Group? Group { get; set; }
    public Guid? ParentFolderId { get; set; }
    public Folder? ParentFolder { get; set; }
    public int SortOrder { get; set; } = 0;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public ICollection<Folder> Children { get; set; } = [];
    public ICollection<Credential> Credentials { get; set; } = [];
}
