using XCred.Core.DTOs.Credentials;

namespace XCred.Core.DTOs.CredentialGroups;

public class CredentialGroupDto
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Icon { get; set; } = string.Empty;
    public Guid? GroupId { get; set; }
    public int CredentialCount { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class CredentialGroupDetailDto : CredentialGroupDto
{
    public List<CredentialDto> Credentials { get; set; } = [];
}

public class CreateCredentialGroupRequest
{
    public string Name { get; set; } = string.Empty;
    public string Icon { get; set; } = "🏦";
    public Guid? GroupId { get; set; }
}

public class UpdateCredentialGroupRequest
{
    public string Name { get; set; } = string.Empty;
    public string Icon { get; set; } = "🏦";
}
