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

    // Expiry follows the same "touch it or not" pattern: UpdateExpiry=true with a null
    // ExpiryDate clears the expiry on every selected credential.
    public bool UpdateExpiry { get; set; }
    public DateTime? ExpiryDate { get; set; }
}

public class BulkDeleteRequest
{
    public List<Guid> CredentialIds { get; set; } = [];
}

/// <summary>
/// Replaces the encrypted payload (DataIv + EncryptedData) of many credentials at once — used by bulk
/// notes / custom-field edits, which the server cannot perform itself because it never sees the
/// plaintext. The browser decrypts each credential, edits it and re-encrypts it with the SAME
/// per-credential key, so EncryptedCredentialKey is deliberately not part of this request.
/// </summary>
public class BulkUpdateDataRequest
{
    public List<BulkUpdateDataItem> Items { get; set; } = [];
}

public class BulkUpdateDataItem
{
    public Guid Id { get; set; }
    public string EncryptedData { get; set; } = string.Empty;
    public string DataIv { get; set; } = string.Empty;
}


public class BulkAssignResultDto
{
    public int Updated { get; set; }
    public int Skipped { get; set; }
}
