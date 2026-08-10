import '../api/api_client.dart';
import '../models/team_models.dart';

/// MOB-TEAM-01 — GroupsController.cs's endpoints (route stays `/api/groups`; "Team" is
/// UI-only, see team_models.dart).
class TeamsRepository {
  TeamsRepository(this._api);
  final ApiClient _api;

  /// Only teams the caller is a member of — there is no "browse all teams" even for a
  /// global Admin (GroupsController.cs's `GetAll` scopes strictly by membership).
  Future<List<TeamSummary>> getAll() async {
    final data = await _api.get<List<dynamic>>('/api/groups', (json) => json as List<dynamic>);
    return data.map((e) => TeamSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TeamSummary> getById(String id) async {
    final data = await _api.get<Map<String, dynamic>>(
        '/api/groups/$id', (json) => json as Map<String, dynamic>);
    return TeamSummary.fromJson(data);
  }

  /// The creator is auto-added as a team Admin server-side; [memberIds] beyond that
  /// join as plain Members — unused here, matching the web app, which always creates
  /// empty and adds members afterward one at a time via [addMember].
  Future<void> create({required String name, String? description}) {
    return _api.post<Map<String, dynamic>>(
      '/api/groups',
      (json) => json as Map<String, dynamic>,
      data: {'name': name, 'description': description, 'memberIds': const []},
    );
  }

  /// Requires the caller to be this team's Admin or a global Admin
  /// (GroupsController.cs's `AddMember`) — a 403 with no JSON body, which ApiClient
  /// surfaces as a generic NETWORK_ERROR; the UI should avoid offering this action to
  /// anyone who wouldn't pass that check rather than relying on the error message.
  Future<void> addMember(String teamId, String memberId) {
    return _api.post<String>(
      '/api/groups/$teamId/members/$memberId',
      identityFromData<String>,
    );
  }

  /// Same authorization as [addMember], **except** removing yourself ("leave team") is
  /// always allowed regardless of role.
  Future<void> removeMember(String teamId, String memberId) {
    return _api.delete<String>(
        '/api/groups/$teamId/members/$memberId', identityFromData<String>);
  }

  /// Global-Admin-only server-side, unlike every other endpoint here — see
  /// [TeamSummary.isMyRoleAdmin]'s doc comment. Also has no cascade-revoke for
  /// credentials shared with this team (Restrict FK), so deleting a team that still has
  /// active group-shares fails with an unstructured error, not a friendly message.
  Future<void> delete(String teamId) {
    return _api.delete<String>('/api/groups/$teamId', identityFromData<String>);
  }
}
