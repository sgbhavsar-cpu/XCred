import '../api/api_client.dart';
import '../models/share_models.dart';

/// MOB-SHARE-01/02 — SharesController.cs's four endpoints. Only the credential owner
/// can create or revoke a share (server-enforced); recipients only ever read
/// [getSharedWithMe].
class SharesRepository {
  SharesRepository(this._api);
  final ApiClient _api;

  Future<List<SharedCredentialSummary>> getSharedWithMe() async {
    final data = await _api.get<List<dynamic>>(
        '/api/shares/shared-with-me', (json) => json as List<dynamic>);
    return data.map((e) => SharedCredentialSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<SharedCredentialSummary>> getSharedByMe() async {
    final data = await _api.get<List<dynamic>>(
        '/api/shares/shared-by-me', (json) => json as List<dynamic>);
    return data.map((e) => SharedCredentialSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// [encryptedData]/[dataIv] are the owned credential's ciphertext, sent unchanged —
  /// only [encryptedCredentialKey] differs per recipient (re-wrapped under their public
  /// key). See crypto_service.dart's `encryptKeyWithPublicKey`.
  Future<void> create({
    required String credentialId,
    required String sharedWithUserId,
    required String encryptedData,
    required String dataIv,
    required String encryptedCredentialKey,
    DateTime? expiresAt,
    bool untilChanged = false,
  }) {
    return _api.post<Map<String, dynamic>>(
      '/api/shares/credential/$credentialId',
      (json) => json as Map<String, dynamic>,
      data: {
        'sharedWithUserId': sharedWithUserId,
        'encryptedData': encryptedData,
        'dataIv': dataIv,
        'encryptedCredentialKey': encryptedCredentialKey,
        'expiresAt': expiresAt?.toIso8601String(),
        'untilChanged': untilChanged,
      },
    );
  }

  /// Only the credential owner (or a global Admin) can revoke — SharesController.cs's
  /// `Revoke` returns 403 otherwise. A soft delete server-side (`IsRevoked` flag), not
  /// removed, so it still shows up (dimmed) in "Shared By Me".
  Future<void> revoke(String shareId) {
    return _api.delete<String>('/api/shares/$shareId', identityFromData<String>);
  }
}
