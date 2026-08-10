import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_response.dart';
import '../auth/auth_session.dart';
import '../crypto/crypto_service.dart';
import 'core_providers.dart';

/// MOB-SYNC-02 — a queued offline edit whose flush was refused because the server's
/// copy changed underneath it (requirements §6.3: "last write wins with a visible
/// warning" — the warning half; the mutation is left queued, not silently applied or
/// dropped, so the user can decide).
class PendingMutationConflict {
  final int mutationId;
  final String entityId;
  final String entityLabel;
  const PendingMutationConflict({
    required this.mutationId,
    required this.entityId,
    required this.entityLabel,
  });
}

class SyncState {
  final bool syncing;
  final List<PendingMutationConflict> conflicts;
  const SyncState({this.syncing = false, this.conflicts = const []});
}

/// Replays [PendingMutation]s in order on reconnect. Flush is triggered from
/// [VaultNotifier._load] (vault_providers.dart) — i.e. on every credentials-list
/// load/pull-to-refresh — rather than a dedicated connectivity listener, since that
/// already covers this sprint's tested paths (cold start, pull-to-refresh after coming
/// back online) without adding a new platform dependency just to detect reconnection.
class SyncNotifier extends Notifier<SyncState> {
  @override
  SyncState build() => const SyncState();

  Future<void> flush() async {
    if (state.syncing) return;
    final db = ref.read(databaseProvider);
    final pending = await db.getPendingMutations();
    if (pending.isEmpty || !ref.mounted) return;

    final api = ref.read(apiClientProvider);
    final crypto = ref.read(cryptoServiceProvider);
    final session = ref.read(authSessionProvider);
    state = SyncState(syncing: true, conflicts: state.conflicts);

    final conflicts = <PendingMutationConflict>[];
    for (final mutation in pending) {
      try {
        final current = await api.get<Map<String, dynamic>>(
          '/api/credentials/${mutation.entityId}',
          (json) => json as Map<String, dynamic>,
        );
        final serverUpdatedAt = DateTime.parse(current['updatedAt'] as String);
        // [PendingMutation.baseUpdatedAt] can come from the local cache (when the edit
        // was made while already offline) — drift stores DateTime as whole-second Unix
        // timestamps, so a cache-sourced value is always truncated by up to ~1s versus
        // the server's real (sub-second-precision) value. A tolerance well above that
        // truncation error avoids flagging every flush as a false-positive conflict
        // while still catching genuinely concurrent edits, which differ by much more.
        if (serverUpdatedAt.difference(mutation.baseUpdatedAt) > const Duration(seconds: 2)) {
          conflicts.add(PendingMutationConflict(
            mutationId: mutation.id,
            entityId: mutation.entityId,
            entityLabel: await _describe(crypto, session, current),
          ));
          continue;
        }

        await api.put<Map<String, dynamic>>(
          '/api/credentials/${mutation.entityId}',
          (json) => json as Map<String, dynamic>,
          data: jsonDecode(mutation.payloadJson) as Map<String, dynamic>,
        );
        await db.deletePendingMutation(mutation.id);
      } on ApiException catch (e) {
        if (e.code == 'NETWORK_ERROR') break; // still offline — stop, retry on next flush
        // A real server rejection (e.g. the credential was deleted elsewhere) leaves the
        // mutation queued rather than looping on it forever or silently dropping it —
        // full resolution UI for this case is a follow-up, not this sprint's scope.
        break;
      }
      // Each mutation does at least one network round-trip — the notifier (and its ref)
      // can be disposed mid-loop if the widget tree unmounts (e.g. logout) while a flush
      // is in flight. Bail before touching `state` again rather than throwing.
      if (!ref.mounted) return;
    }

    if (!ref.mounted) return;
    state = SyncState(syncing: false, conflicts: conflicts);
  }

  /// The user chooses to discard their offline edit rather than resolve the conflict —
  /// clears the queued mutation without touching the server's (newer) copy.
  Future<void> discardConflict(int mutationId) async {
    await ref.read(databaseProvider).deletePendingMutation(mutationId);
    if (!ref.mounted) return;
    state = SyncState(
      syncing: state.syncing,
      conflicts: state.conflicts.where((c) => c.mutationId != mutationId).toList(),
    );
  }

  Future<String> _describe(
    CryptoService crypto,
    AuthSession? session,
    Map<String, dynamic> current,
  ) async {
    if (session == null) return current['type'] as String? ?? 'credential';
    try {
      final fields = await crypto.decryptCredentialFields(
        encryptedData: current['encryptedData'] as String,
        dataIv: current['dataIv'] as String,
        encryptedCredentialKey: current['encryptedCredentialKey'] as String,
        privateKey: session.privateKey,
      );
      final name = fields['name'] as String?;
      return (name != null && name.isNotEmpty) ? name : (current['type'] as String? ?? 'credential');
    } catch (_) {
      return current['type'] as String? ?? 'credential';
    }
  }
}

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);
