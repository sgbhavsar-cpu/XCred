namespace XCred.Core.Entities;

// A container that bundles several related Credential records under one real-world entity
// (e.g. "HDFC Bank" holding a debit card, a netbanking login, and a mobile banking PIN).
// Distinct from Group, which is a team of users that shares credentials.
public class CredentialGroup
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = string.Empty;
    public string Icon { get; set; } = "🏦";

    public Guid? OwnerId { get; set; }
    public User? Owner { get; set; }

    public Guid? GroupId { get; set; }
    public Group? Group { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public ICollection<Credential> Credentials { get; set; } = [];
}
