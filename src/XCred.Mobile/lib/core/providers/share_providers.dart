import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/share_models.dart';
import '../vault/credential_type_meta.dart';
import '../vault/shares_repository.dart';
import '../vault/users_repository.dart';
import 'core_providers.dart';
import 'vault_providers.dart';

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(ref.watch(apiClientProvider));
});

final sharesRepositoryProvider = Provider<SharesRepository>((ref) {
  return SharesRepository(ref.watch(apiClientProvider));
});

/// MOB-SHARE-02's recipient picker — no offline cache (metadata, re-fetched on every
/// visit), matching folderTreeProvider/tagListProvider's reasoning.
class UsersNotifier extends AsyncNotifier<List<UserSummary>> {
  @override
  Future<List<UserSummary>> build() => ref.read(usersRepositoryProvider).getAll();

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final usersProvider = AsyncNotifierProvider<UsersNotifier, List<UserSummary>>(UsersNotifier.new);

/// A single undecryptable share must not take down the whole list — same resilience
/// reasoning as VaultNotifier's per-credential decrypt step.
SharedItem _fallback(SharedCredentialSummary s) =>
    SharedItem(share: s, name: credentialTypeLabel(s.credentialType));

/// "Shared With Me" — the share row's own `encryptedCredentialKey` is wrapped under
/// *this* user's public key (that's the whole point of the envelope re-wrap on share
/// creation), so it decrypts directly, identically to an owned credential.
Future<List<SharedItem>> _decorateSharedWithMe(Ref ref, List<SharedCredentialSummary> shares) async {
  final session = ref.read(authSessionProvider);
  if (session == null) return shares.map(_fallback).toList();
  final crypto = ref.read(cryptoServiceProvider);
  final items = <SharedItem>[];
  for (final s in shares) {
    try {
      final fields = await crypto.decryptCredentialFields(
        encryptedData: s.encryptedData,
        dataIv: s.dataIv,
        encryptedCredentialKey: s.encryptedCredentialKey,
        privateKey: session.privateKey,
      );
      final name = fields['name'] as String?;
      items.add(SharedItem(
        share: s,
        name: (name != null && name.isNotEmpty) ? name : credentialTypeLabel(s.credentialType),
      ));
    } catch (_) {
      items.add(_fallback(s));
    }
  }
  return items;
}

/// "Shared By Me" — the share row's `encryptedCredentialKey` is wrapped under the
/// *recipient's* public key, useless to the owner. The owner already has a correctly
/// (self-)wrapped copy of the same underlying AES key on their own owned credential
/// (`encryptedData`/`dataIv` are identical, unchanged since the share was created), so
/// decrypting the name here goes through that instead of the share row's own key.
Future<List<SharedItem>> _decorateSharedByMe(Ref ref, List<SharedCredentialSummary> shares) async {
  final session = ref.read(authSessionProvider);
  if (session == null) return shares.map(_fallback).toList();
  final crypto = ref.read(cryptoServiceProvider);
  final credentialRepo = ref.read(credentialRepositoryProvider);
  final items = <SharedItem>[];
  for (final s in shares) {
    try {
      final owned = await credentialRepo.getById(s.credentialId);
      if (owned == null) {
        items.add(_fallback(s));
        continue;
      }
      final fields = await crypto.decryptCredentialFields(
        encryptedData: owned.encryptedData,
        dataIv: owned.dataIv,
        encryptedCredentialKey: owned.encryptedCredentialKey,
        privateKey: session.privateKey,
      );
      final name = fields['name'] as String?;
      items.add(SharedItem(
        share: s,
        name: (name != null && name.isNotEmpty) ? name : credentialTypeLabel(s.credentialType),
      ));
    } catch (_) {
      items.add(_fallback(s));
    }
  }
  return items;
}

class SharedWithMeNotifier extends AsyncNotifier<List<SharedItem>> {
  @override
  Future<List<SharedItem>> build() async {
    final shares = await ref.read(sharesRepositoryProvider).getSharedWithMe();
    return _decorateSharedWithMe(ref, shares);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final sharedWithMeProvider =
    AsyncNotifierProvider<SharedWithMeNotifier, List<SharedItem>>(SharedWithMeNotifier.new);

class SharedByMeNotifier extends AsyncNotifier<List<SharedItem>> {
  @override
  Future<List<SharedItem>> build() async {
    final shares = await ref.read(sharesRepositoryProvider).getSharedByMe();
    return _decorateSharedByMe(ref, shares);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final sharedByMeProvider =
    AsyncNotifierProvider<SharedByMeNotifier, List<SharedItem>>(SharedByMeNotifier.new);
