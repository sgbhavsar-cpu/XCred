// Mirrors XCred.Api.Controllers.AdminController's AdminUserDto / AuditLogDto /
// PagedResult<T>, and XCred.Core.Constants.AuditActions.

class AdminUserSummary {
  final String id;
  final String username;
  final String email;
  final String role;
  final bool isActive;
  final bool isApproved;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const AdminUserSummary({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.isActive,
    required this.isApproved,
    required this.createdAt,
    this.lastLoginAt,
  });

  bool get isAdmin => role == 'Admin';

  factory AdminUserSummary.fromJson(Map<String, dynamic> json) => AdminUserSummary(
        id: json['id'] as String,
        username: json['username'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        isActive: json['isActive'] as bool,
        isApproved: json['isApproved'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastLoginAt:
            json['lastLoginAt'] == null ? null : DateTime.parse(json['lastLoginAt'] as String),
      );
}

class AuditLogEntry {
  final String id;
  final DateTime timestamp;
  final String? userId;
  final String? username;
  final String? ipAddress;
  final String action;
  final String? resourceType;
  final String? resourceId;
  final String? detail;

  const AuditLogEntry({
    required this.id,
    required this.timestamp,
    this.userId,
    this.username,
    this.ipAddress,
    required this.action,
    this.resourceType,
    this.resourceId,
    this.detail,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        userId: json['userId'] as String?,
        username: json['username'] as String?,
        ipAddress: json['ipAddress'] as String?,
        action: json['action'] as String,
        resourceType: json['resourceType'] as String?,
        resourceId: json['resourceId'] as String?,
        detail: json['detail'] as String?,
      );
}

/// AdminController.cs's `GET /api/admin/audit-log` returns real server-side pagination
/// (`PagedResult<AuditLogDto>`), not a flat list — MOB-ADMIN-03's acceptance criteria is
/// specifically that page/pageSize/filters actually reach the API and change the
/// result, unlike the web app (which never wires any of them, always page 1 of 50).
class PagedAuditLog {
  final List<AuditLogEntry> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const PagedAuditLog({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PagedAuditLog.fromJson(Map<String, dynamic> json) => PagedAuditLog(
        items: ((json['items'] as List<dynamic>?) ?? [])
            .map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int? ?? 0,
        page: json['page'] as int? ?? 1,
        pageSize: json['pageSize'] as int? ?? 50,
        totalPages: json['totalPages'] as int? ?? 0,
      );
}

/// Mirrors AuditActions.cs verbatim — the audit-log `action` filter is a plain-string
/// exact match server-side (no enum, no whitelist), so this list only drives the
/// mobile filter dropdown's options, not any validation.
const List<String> kAuditActions = [
  'LoginSuccess',
  'LoginFailed',
  'Logout',
  'SessionExpired',
  'Registered',
  'AccountApproved',
  'AccountDeactivated',
  'PasswordChanged',
  'MasterPasswordChanged',
  'CredentialCreated',
  'CredentialViewed',
  'CredentialCopied',
  'CredentialUpdated',
  'CredentialDeleted',
  'AttachmentUploaded',
  'AttachmentDownloaded',
  'AttachmentDeleted',
  'ShareCreated',
  'ShareRevoked',
  'ShareAccessed',
  'ShareExpired',
  'GroupCreated',
  'GroupDeleted',
  'GroupMemberAdded',
  'GroupMemberRemoved',
  'CredentialGroupCreated',
  'CredentialGroupUpdated',
  'CredentialGroupDeleted',
  'BackupExported',
  'BackupImported',
];
