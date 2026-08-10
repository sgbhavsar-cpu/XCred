// Mirrors XCred.Core.DTOs.Auth.ProfileDto / NotificationPreferencesRequest and
// XCred.Api.Controllers.BackupController's RestoreResultDto.
import 'dart:convert';

class NotificationPreferences {
  final bool expiryReminders;
  final bool shareNotifications;
  final bool securityAlerts;
  const NotificationPreferences({
    required this.expiryReminders,
    required this.shareNotifications,
    required this.securityAlerts,
  });

  static const defaults =
      NotificationPreferences(expiryReminders: true, shareNotifications: true, securityAlerts: true);

  /// The server stores this as an opaque JSON string column (User.NotificationPreferences),
  /// not a parsed object — parse defensively, falling back to defaults on anything
  /// malformed rather than crashing the whole Settings screen over it.
  factory NotificationPreferences.fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return defaults;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return NotificationPreferences(
        expiryReminders: json['expiryReminders'] as bool? ?? true,
        shareNotifications: json['shareNotifications'] as bool? ?? true,
        securityAlerts: json['securityAlerts'] as bool? ?? true,
      );
    } catch (_) {
      return defaults;
    }
  }

  /// The backend replaces the whole object on every save (no partial update) —
  /// always send all three fields.
  Map<String, dynamic> toJson() => {
        'expiryReminders': expiryReminders,
        'shareNotifications': shareNotifications,
        'securityAlerts': securityAlerts,
      };

  NotificationPreferences copyWith({bool? expiryReminders, bool? shareNotifications}) =>
      NotificationPreferences(
        expiryReminders: expiryReminders ?? this.expiryReminders,
        shareNotifications: shareNotifications ?? this.shareNotifications,
        securityAlerts: securityAlerts,
      );
}

class ProfileInfo {
  final String id;
  final String username;
  final String email;
  final String role;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final NotificationPreferences notificationPreferences;

  const ProfileInfo({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.createdAt,
    this.lastLoginAt,
    required this.notificationPreferences,
  });

  ProfileInfo copyWith({NotificationPreferences? notificationPreferences}) => ProfileInfo(
        id: id,
        username: username,
        email: email,
        role: role,
        createdAt: createdAt,
        lastLoginAt: lastLoginAt,
        notificationPreferences: notificationPreferences ?? this.notificationPreferences,
      );

  factory ProfileInfo.fromJson(Map<String, dynamic> json) => ProfileInfo(
        id: json['id'] as String,
        username: json['username'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastLoginAt: json['lastLoginAt'] == null ? null : DateTime.parse(json['lastLoginAt'] as String),
        notificationPreferences:
            NotificationPreferences.fromJsonString(json['notificationPreferences'] as String?),
      );
}

class BackupRestoreResult {
  final int credentialsRestored;
  final int credentialsSkipped;
  final int tagsRestored;
  final int foldersRestored;
  const BackupRestoreResult({
    required this.credentialsRestored,
    required this.credentialsSkipped,
    required this.tagsRestored,
    required this.foldersRestored,
  });

  factory BackupRestoreResult.fromJson(Map<String, dynamic> json) => BackupRestoreResult(
        credentialsRestored: json['credentialsRestored'] as int? ?? 0,
        credentialsSkipped: json['credentialsSkipped'] as int? ?? 0,
        tagsRestored: json['tagsRestored'] as int? ?? 0,
        foldersRestored: json['foldersRestored'] as int? ?? 0,
      );
}
