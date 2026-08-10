// Mirrors XCred.Core.DTOs.Groups.GroupDto / GroupMemberDto — see GroupsController.cs.
// "Team" is the UI-facing label; the entity/route/DB layer still says "Group", same as
// the web app (a presentation-only relabel from an earlier session, no rename).
class TeamMember {
  final String userId;
  final String username;
  final String email;
  final String role;
  final DateTime joinedAt;
  const TeamMember({
    required this.userId,
    required this.username,
    required this.email,
    required this.role,
    required this.joinedAt,
  });

  bool get isAdmin => role == 'Admin';

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
        userId: json['userId'] as String,
        username: json['username'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        joinedAt: DateTime.parse(json['joinedAt'] as String),
      );
}

class TeamSummary {
  final String id;
  final String name;
  final String? description;
  final int memberCount;
  final String myRole;
  final DateTime createdAt;
  final List<TeamMember> members;

  const TeamSummary({
    required this.id,
    required this.name,
    this.description,
    required this.memberCount,
    required this.myRole,
    required this.createdAt,
    this.members = const [],
  });

  /// Team-scoped admin — distinct from the global user role (AuthSession.role). Gates
  /// add/remove-member; deleting a team is global-admin-only server-side
  /// (GroupsController.cs's `Delete` is `[Authorize(Roles = Roles.Admin)]`, unlike every
  /// other endpoint on that controller), so it must NOT be gated on this flag.
  bool get isMyRoleAdmin => myRole == 'Admin';

  factory TeamSummary.fromJson(Map<String, dynamic> json) => TeamSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        memberCount: json['memberCount'] as int? ?? 0,
        myRole: json['myRole'] as String? ?? 'Member',
        createdAt: DateTime.parse(json['createdAt'] as String),
        members: ((json['members'] as List<dynamic>?) ?? [])
            .map((m) => TeamMember.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}
