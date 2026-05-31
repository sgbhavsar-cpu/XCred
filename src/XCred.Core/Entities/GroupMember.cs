namespace XCred.Core.Entities;

public class GroupMember
{
    public Guid GroupId { get; set; }
    public Group Group { get; set; } = null!;
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;
    public string Role { get; set; } = "Member";  // "Admin" | "Member"
    public DateTime JoinedAt { get; set; } = DateTime.UtcNow;
}
