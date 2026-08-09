import '../api/api_client.dart';
import '../api/api_response.dart';
import '../db/app_database.dart';
import '../models/credential_models.dart';

/// Cache-first-when-offline result — architecture.md §3.3. [servedFromCache] is true
/// only when the network call itself failed (no connectivity, timeout); a real server
/// rejection (auth, validation) propagates as an exception instead of silently showing
/// stale data.
class VaultFetchResult<T> {
  final List<T> items;
  final bool servedFromCache;
  const VaultFetchResult({required this.items, required this.servedFromCache});
}

/// Owns "read (cache-first when offline), write (network), decrypt (elsewhere, in
/// memory)" for credentials — architecture.md §2's Repository layer. Decryption
/// deliberately isn't here: it needs the session's private key, which this class has no
/// business knowing about (see core/providers/vault_providers.dart for that seam).
class CredentialRepository {
  CredentialRepository(this._api, this._db);
  final ApiClient _api;
  final AppDatabase _db;

  Future<VaultFetchResult<CredentialListItem>> getAll() async {
    try {
      final data = await _api.get<List<dynamic>>(
        '/api/credentials',
        (json) => json as List<dynamic>,
      );
      final items =
          data.map((e) => CredentialListItem.fromJson(e as Map<String, dynamic>)).toList();
      await _db.replaceCachedCredentials(items);
      return VaultFetchResult(items: items, servedFromCache: false);
    } on ApiException catch (e) {
      if (e.code != 'NETWORK_ERROR') rethrow;
      final cached = await _db.getCachedCredentials();
      return VaultFetchResult(items: cached, servedFromCache: true);
    }
  }

  /// Prefers a fresh fetch (also triggers the server's view-audit log entry); falls back
  /// to the cached list row if offline. Returns null if the credential doesn't exist in
  /// either place (deleted elsewhere, or never synced).
  Future<CredentialListItem?> getById(String id) async {
    try {
      final data = await _api.get<Map<String, dynamic>>(
        '/api/credentials/$id',
        (json) => json as Map<String, dynamic>,
      );
      return CredentialListItem.fromJson(data);
    } on ApiException catch (e) {
      if (e.code != 'NETWORK_ERROR') rethrow;
      final cached = await _db.getCachedCredentials();
      for (final item in cached) {
        if (item.id == id) return item;
      }
      return null;
    }
  }

  /// Assigns (or clears, when [groupId] is null) a credential's Credential Group without
  /// touching its encrypted payload — mirrors the web app's `assignToGroup`: fetch the
  /// current ciphertext blind (no decrypt needed), PUT it back with every other field
  /// unchanged except `credentialGroupId`. Used by the group detail screen's "add
  /// existing" / "remove from group" actions.
  Future<void> setCredentialGroup(String credentialId, String? groupId) async {
    final current = await _api.get<Map<String, dynamic>>(
      '/api/credentials/$credentialId',
      (json) => json as Map<String, dynamic>,
    );
    await _api.put<Map<String, dynamic>>(
      '/api/credentials/$credentialId',
      (json) => json as Map<String, dynamic>,
      data: {
        'encryptedData': current['encryptedData'],
        'dataIv': current['dataIv'],
        'encryptedCredentialKey': current['encryptedCredentialKey'],
        'expiryDate': current['expiryDate'],
        'folderId': current['folderId'],
        'credentialGroupId': groupId,
        'tagIds': ((current['tags'] as List<dynamic>?) ?? [])
            .map((t) => (t as Map<String, dynamic>)['id'])
            .toList(),
      },
    );
  }
}
