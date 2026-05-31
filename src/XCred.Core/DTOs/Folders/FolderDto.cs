namespace XCred.Core.DTOs.Folders;

public class FolderDto
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public Guid? ParentFolderId { get; set; }
    public Guid? GroupId { get; set; }
    public int SortOrder { get; set; }
    public DateTime CreatedAt { get; set; }
    public int CredentialCount { get; set; }
    public List<FolderDto> Children { get; set; } = [];
}

public class CreateFolderRequest
{
    public string Name { get; set; } = string.Empty;
    public Guid? ParentFolderId { get; set; }
    public Guid? GroupId { get; set; }
}

public class UpdateFolderRequest
{
    public string Name { get; set; } = string.Empty;
    public Guid? ParentFolderId { get; set; }
    public int SortOrder { get; set; }
}
