import '../api/api_client.dart';
import '../models/settings_models.dart';

/// MOB-SET-01/02 — AuthController.cs's profile/change-password/notification-preference
/// endpoints. Login-password change is pure server-side BCrypt rehash (the two-secret
/// model means it never touches the master password or any key material) — nothing
/// here needs CryptoService.
class SettingsRepository {
  SettingsRepository(this._api);
  final ApiClient _api;

  Future<ProfileInfo> getProfile() async {
    final data = await _api.get<Map<String, dynamic>>(
        '/api/auth/profile', (json) => json as Map<String, dynamic>);
    return ProfileInfo.fromJson(data);
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) {
    return _api.post<String>(
      '/api/auth/change-password',
      identityFromData<String>,
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  Future<void> updateNotificationPreferences(NotificationPreferences prefs) {
    return _api.put<String>(
      '/api/auth/notification-preferences',
      identityFromData<String>,
      data: prefs.toJson(),
    );
  }
}
