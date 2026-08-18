import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/credential_models.dart';
import '../models/folder_tag_models.dart';
import '../vault/attachment_repository.dart';
import '../vault/credential_fields.dart';
import '../vault/credential_group_repository.dart';
import '../vault/credential_repository.dart';
import '../vault/credential_type_meta.dart';
import '../vault/folder_repository.dart';
import '../vault/tag_repository.dart';
import 'core_providers.dart';
import 'sync_providers.dart';

final credentialRepositoryProvider = Provider<CredentialRepository>((ref) {
  return CredentialRepository(ref.watch(apiClientProvider), ref.watch(databaseProvider));
});

final attachmentRepositoryProvider = Provider<AttachmentRepository>((ref) {
  return AttachmentRepository(ref.watch(apiClientProvider));
});

final credentialGroupRepositoryProvider = Provider<CredentialGroupRepository>((ref) {
  return CredentialGroupRepository(ref.watch(apiClientProvider), ref.watch(databaseProvider));
});

final folderRepositoryProvider = Provider<FolderRepository>((ref) {
  return FolderRepository(ref.watch(apiClientProvider));
});

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepository(ref.watch(apiClientProvider));
});

/// MOB-FOLD-01 — no offline cache (folders are metadata; re-fetched on every visit,
/// matching the web app's own `loadFolders()`). Also used by the credential form's
/// folder picker (flattened via [flattenFolders]).
class FolderTreeNotifier extends AsyncNotifier<List<FolderNode>> {
  @override
  Future<List<FolderNode>> build() => ref.read(folderRepositoryProvider).getAll();

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final folderTreeProvider =
    AsyncNotifierProvider<FolderTreeNotifier, List<FolderNode>>(FolderTreeNotifier.new);

/// MOB-TAG-01 — same reasoning as [folderTreeProvider].
class TagListNotifier extends AsyncNotifier<List<TagSummary>> {
  @override
  Future<List<TagSummary>> build() => ref.read(tagRepositoryProvider).getAll();

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final tagListProvider =
    AsyncNotifierProvider<TagListNotifier, List<TagSummary>>(TagListNotifier.new);

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

  CredentialListItem? _find(String id) {
    for (final c in state.value?.credentials ?? const <CredentialListItem>[]) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Copies this credential's primary sensitive field (the first `password`-type field
  /// for its type — "password" for a login, "passphrase" for an SSH key, "keyValue" for
  /// an API key, etc.) to the clipboard, with the same audit-log call and auto-clear
  /// countdown as [CredentialDetailScreen]'s own per-field copy buttons. Returns false if
  /// the type has no password-type field at all, or the credential can't be decrypted —
  /// callers show a clear error rather than a silent no-op.
  Future<bool> copyPassword(String id) async {
    final session = ref.read(authSessionProvider);
    final item = _find(id);
    if (session == null || item == null) return false;

    FieldDef? passwordField;
    for (final f in kCredentialFields[item.type] ?? const <FieldDef>[]) {
      if (f.type == 'password') { passwordField = f; break; }
    }
    if (passwordField == null) return false;

    final crypto = ref.read(cryptoServiceProvider);
    final data = await crypto.decryptCredentialFields(
      encryptedData: item.encryptedData,
      dataIv: item.dataIv,
      encryptedCredentialKey: item.encryptedCredentialKey,
      privateKey: session.privateKey,
    );
    final value = data[passwordField.key] as String?;
    if (value == null || value.isEmpty) return false;

    await Clipboard.setData(ClipboardData(text: value));
    unawaited(ref
        .read(apiClientProvider)
        .post<String>('/api/credentials/$id/copy?field=${passwordField.key}',
            identityFromData<String>, data: null)
        .catchError((_) => ''));

    final seconds = ref.read(orgSettingsProvider).clipboardClearSeconds;
    Future.delayed(Duration(seconds: seconds), () async {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      if (current?.text == value) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
    return true;
  }

  /// Decrypts a credential and re-encrypts the same data (with " (Copy)" appended to the
  /// name) as a brand-new credential carrying the same type/folder/group/tags — mirrors
  /// the web app's `duplicateCredential`. Returns the new id (caller navigates to
  /// `/credentials/<id>/edit` with it), or null if it couldn't be duplicated.
  Future<String?> duplicateCredential(String id) async {
    final session = ref.read(authSessionProvider);
    final item = _find(id);
    if (session == null || item == null) return null;

    final crypto = ref.read(cryptoServiceProvider);
    final data = await crypto.decryptCredentialFields(
      encryptedData: item.encryptedData,
      dataIv: item.dataIv,
      encryptedCredentialKey: item.encryptedCredentialKey,
      privateKey: session.privateKey,
    );
    final name = data['name'] as String?;
    final payload = {
      ...data,
      'name': '${(name != null && name.isNotEmpty) ? name : credentialTypeLabel(item.type)} (Copy)',
    };
    final enc = await crypto.encryptCredentialFields(
      payload: payload,
      publicKeySpkiB64: session.publicKeySpkiB64,
    );

    final newId = await ref.read(credentialRepositoryProvider).create({
      'type': item.type,
      'encryptedData': enc.encryptedData,
      'dataIv': enc.dataIv,
      'encryptedCredentialKey': enc.encryptedCredentialKey,
      'expiryDate': item.expiryDate?.toIso8601String(),
      'folderId': item.folderId,
      'credentialGroupId': item.credentialGroupId,
      'tagIds': item.tags.map((t) => t.id).toList(),
    });
    await refresh();
    return newId;
  }

  Future<void> deleteCredential(String id) async {
    await ref.read(credentialRepositoryProvider).delete(id);
    await refresh();
  }

  /// See [CredentialRepository.bulkAssign] — this wrapper just also refreshes the vault
  /// afterward, so every screen watching [vaultProvider] picks up the change reactively.
  Future<BulkResult> bulkAssign({
    required List<String> credentialIds,
    bool updateFolder = false,
    String? folderId,
    bool updateCredentialGroup = false,
    String? credentialGroupId,
  }) async {
    final result = await ref.read(credentialRepositoryProvider).bulkAssign(
          credentialIds: credentialIds,
          updateFolder: updateFolder,
          folderId: folderId,
          updateCredentialGroup: updateCredentialGroup,
          credentialGroupId: credentialGroupId,
        );
    await refresh();
    return result;
  }

  /// See [CredentialRepository.bulkTags].
  Future<BulkResult> bulkTags({
    required List<String> credentialIds,
    List<String> addTagIds = const [],
    List<String> removeTagIds = const [],
  }) async {
    final result = await ref.read(credentialRepositoryProvider).bulkTags(
          credentialIds: credentialIds,
          addTagIds: addTagIds,
          removeTagIds: removeTagIds,
        );
    await refresh();
    return result;
  }

  Future<VaultState> _load() async {
    // MOB-SYNC-02 — replay any offline-queued edits before fetching, so a load right
    // after reconnecting (cold start or pull-to-refresh) both flushes and shows the
    // resulting server state in one action.
    await ref.read(syncProvider.notifier).flush();
    // A logout/dispose (or, in tests, a torn-down ProviderScope) can land while flush()
    // is still awaiting its network round-trip — reading through a disposed ref throws,
    // and since nothing is left to observe this build's result anyway, bail instead.
    if (!ref.mounted) return const VaultState(credentials: [], decrypted: {}, offline: false);

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
