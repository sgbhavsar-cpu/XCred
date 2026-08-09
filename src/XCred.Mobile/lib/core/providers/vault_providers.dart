import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/credential_models.dart';
import '../vault/credential_group_repository.dart';
import '../vault/credential_repository.dart';
import '../vault/credential_type_meta.dart';
import 'core_providers.dart';

final credentialRepositoryProvider = Provider<CredentialRepository>((ref) {
  return CredentialRepository(ref.watch(apiClientProvider), ref.watch(databaseProvider));
});

final credentialGroupRepositoryProvider = Provider<CredentialGroupRepository>((ref) {
  return CredentialGroupRepository(ref.watch(apiClientProvider), ref.watch(databaseProvider));
});

class VaultState {
  final List<CredentialListItem> credentials;
  final Map<String, DecryptedCredentialMeta> decrypted;
  final bool offline;
  final DateTime? lastSyncedAt;

  const VaultState({
    required this.credentials,
    required this.decrypted,
    required this.offline,
    this.lastSyncedAt,
  });
}

/// MOB-CRED-01/MOB-SYNC-01 — fetches every credential the user can see and decrypts
/// each one's display name/username once (mirrors the web app's
/// `useDecryptedCredentials` hook), so screens just group/filter/search the result.
///
/// Decryption runs sequentially per credential rather than in parallel: PointyCastle's
/// RSA-OAEP unwrap is synchronous CPU work on this isolate, so `Future.wait` wouldn't
/// actually parallelize it anyway. Fine at the current (tens of credentials) scale;
/// worth moving to a background isolate if real vaults get into the thousands.
class VaultNotifier extends AsyncNotifier<VaultState> {
  DateTime? _lastSyncedAt;

  @override
  Future<VaultState> build() => _load();

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<VaultState> _load() async {
    final result = await ref.read(credentialRepositoryProvider).getAll();
    if (!result.servedFromCache) _lastSyncedAt = DateTime.now();

    final session = ref.read(authSessionProvider);
    final crypto = ref.read(cryptoServiceProvider);
    final decrypted = <String, DecryptedCredentialMeta>{};

    if (session != null) {
      for (final item in result.items) {
        try {
          final fields = await crypto.decryptCredentialFields(
            encryptedData: item.encryptedData,
            dataIv: item.dataIv,
            encryptedCredentialKey: item.encryptedCredentialKey,
            privateKey: session.privateKey,
          );
          final name = fields['name'] as String?;
          final subtitle = (fields['username'] ?? fields['email'] ?? fields['emailAddress'] ??
              fields['cardholderName'] ?? fields['ssid']) as String?;
          decrypted[item.id] = DecryptedCredentialMeta(
            name: (name != null && name.isNotEmpty) ? name : credentialTypeLabel(item.type),
            subtitle: subtitle,
          );
        } catch (_) {
          // A single undecryptable credential (corrupt cache row, key mismatch after a
          // master-password rotation elsewhere) must not take down the whole list.
          decrypted[item.id] = DecryptedCredentialMeta(name: credentialTypeLabel(item.type));
        }
      }
    }

    return VaultState(
      credentials: result.items,
      decrypted: decrypted,
      offline: result.servedFromCache,
      lastSyncedAt: _lastSyncedAt,
    );
  }
}

final vaultProvider = AsyncNotifierProvider<VaultNotifier, VaultState>(VaultNotifier.new);

class CredentialGroupsNotifier extends AsyncNotifier<List<CredentialGroupSummary>> {
  @override
  Future<List<CredentialGroupSummary>> build() async {
    final result = await ref.read(credentialGroupRepositoryProvider).getAll();
    return result.items;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final credentialGroupsProvider =
    AsyncNotifierProvider<CredentialGroupsNotifier, List<CredentialGroupSummary>>(
        CredentialGroupsNotifier.new);
