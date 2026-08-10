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

/// MOB-SYNC-02 — whether [CredentialRepository.update] reached the server immediately
/// or had to be queued for later (no connectivity right now).
enum CredentialWriteOutcome { synced, queuedOffline }

class CredentialWriteResult {
  final CredentialWriteOutcome outcome;
  const CredentialWriteResult(this.outcome);
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

  /// MOB-SYNC-02 — edits an existing credential. On a genuine network failure, the edit
  /// is queued as a [PendingMutation] and applied optimistically to the local read
  /// cache instead of surfacing an error, matching "changes I make while offline are
  /// saved locally and sent once I'm back online" (requirements §6.3). A real server
  /// rejection (validation, auth) still propagates — only `NETWORK_ERROR` is queued.
  ///
  /// [baseUpdatedAt] must be the credential's `updatedAt` as last fetched from the
  /// server (i.e. what the edit was actually based on) — the flush path
  /// (core/providers/sync_providers.dart) compares it against the server's current
  /// value to detect "someone else changed this while I was offline."
  Future<CredentialWriteResult> update(
    String id,
    Map<String, dynamic> body,
    DateTime baseUpdatedAt,
  ) async {
    try {
      await _api.put<Map<String, dynamic>>(
        '/api/credentials/$id',
        (json) => json as Map<String, dynamic>,
        data: body,
      );
      return const CredentialWriteResult(CredentialWriteOutcome.synced);
    } on ApiException catch (e) {
      if (e.code != 'NETWORK_ERROR') rethrow;
      await _db.queuePendingMutation(entityId: id, payload: body, baseUpdatedAt: baseUpdatedAt);
      await _db.applyOptimisticCredentialUpdate(id, body, DateTime.now());
      return const CredentialWriteResult(CredentialWriteOutcome.queuedOffline);
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
