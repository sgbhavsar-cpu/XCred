namespace XCred.Core.Entities;

public class CredentialTag
{
    public Guid CredentialId { get; set; }
    public Credential Credential { get; set; } = null!;
    public Guid TagId { get; set; }
    public Tag Tag { get; set; } = null!;
}
