import '../api/api_client.dart';
import '../models/admin_models.dart';

/// MOB-ADMIN-01/02/03 — AdminController.cs. The whole controller is
/// `[Authorize(Roles = Admin)]`, so every call here 403s for a non-admin caller; the UI
/// must gate access on `AuthSession.role == 'Admin'` rather than relying on the error.
class AdminRepository {
  AdminRepository(this._api);
  final ApiClient _api;

  Future<List<AdminUserSummary>> getUsers({bool includeInactive = false, bool pendingOnly = false}) async {
    final data = await _api.get<List<dynamic>>(
      '/api/admin/users',
      (json) => json as List<dynamic>,
      query: {'includeInactive': includeInactive, 'pendingOnly': pendingOnly},
    );
    return data.map((e) => AdminUserSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> approveUser(String id) {
    return _api.post<String>('/api/admin/users/$id/approve', identityFromData<String>);
  }

  /// Blocked server-side if `id` is the caller's own account (no "last admin"
  /// protection beyond that) — revokes the user's refresh tokens immediately, though an
  /// already-issued access token keeps working until it naturally expires.
  Future<void> deactivateUser(String id) {
    return _api.post<String>('/api/admin/users/$id/deactivate', identityFromData<String>);
  }

  Future<void> activateUser(String id) {
    return _api.post<String>('/api/admin/users/$id/activate', identityFromData<String>);
  }

  /// No self-demotion guard server-side (unlike deactivate) and no "last admin"
  /// protection — an admin can demote themselves or the only other admin freely.
  Future<void> setRole(String id, String role) {
    return _api.post<String>(
      '/api/admin/users/$id/role',
      identityFromData<String>,
      data: {'role': role},
    );
  }

  /// `action` is matched as a plain exact-match string server-side (no enum
  /// validation) — see [kAuditActions] for the mobile filter's option list.
  Future<PagedAuditLog> getAuditLog({
    int page = 1,
    int pageSize = 50,
    String? userId,
    String? action,
    DateTime? from,
    DateTime? to,
  }) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/api/admin/audit-log',
      (json) => json as Map<String, dynamic>,
      query: {
        'page': page,
        'pageSize': pageSize,
        if (userId != null) 'userId': userId,
        if (action != null) 'action': action,
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
      },
    );
    return PagedAuditLog.fromJson(data);
  }
}
