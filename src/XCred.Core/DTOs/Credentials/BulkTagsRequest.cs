namespace XCred.Core.DTOs.Credentials;

/// <summary>
/// Adds and/or removes tags across a batch of credentials in one call. Unlike folder/credential
/// group (BulkAssignRequest), tags are multi-valued per credential, so this is an add/remove
/// delta rather than a single "set to" value — a credential keeps whatever tags it already had
/// that aren't in RemoveTagIds, plus whatever's newly added.
/// </summary>
public class BulkTagsRequest
{
    public List<Guid> CredentialIds { get; set; } = [];
    public List<Guid> AddTagIds { get; set; } = [];
    public List<Guid> RemoveTagIds { get; set; } = [];
}

public class BulkTagsResultDto
{
    public int Updated { get; set; }
    public int Skipped { get; set; }
}
