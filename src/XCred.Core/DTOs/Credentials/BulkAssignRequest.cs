namespace XCred.Core.DTOs.Credentials;

/// <summary>
/// Reassigns folder and/or credential group for a batch of credentials in one call — used by
/// both drag-and-drop (single credential) and the multi-select bulk-edit toolbar. Folder and
/// group are independent dimensions, so each carries its own "should this field even be
/// touched" flag: UpdateFolder/UpdateCredentialGroup distinguish "leave unchanged" from
/// "set to null" (unassign), which a bare nullable Guid? alone can't express.
/// </summary>
public class BulkAssignRequest
{
    public List<Guid> CredentialIds { get; set; } = [];
    public bool UpdateFolder { get; set; }
    public Guid? FolderId { get; set; }
    public bool UpdateCredentialGroup { get; set; }
    public Guid? CredentialGroupId { get; set; }
}

public class BulkAssignResultDto
{
    public int Updated { get; set; }
    public int Skipped { get; set; }
}
