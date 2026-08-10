// End-to-end proof for Sprint 1.7 (MOB-SYNC-02) against the live Docker dev backend.
//
// Real network-unreachable conditions can't be driven from a WidgetTester, so — the
// same provider-override seam used for the read-path in offline_cache_test.dart —
// [ApiClient.get]/[ApiClient.put] are wrapped in a fake whose `offline` flag can be
// flipped mid-test. Both are toggled (not just `put`): the app's own detail-screen
// reload after an offline edit relies on its GET failing and falling back to the local
// cache to show the optimistically-applied edit, same as Sprint 1.3's read-path. Test
// scaffolding that needs to peek at/mutate real server state regardless of the
// simulated offline flag (verifying a flush actually reached the server, simulating a
// concurrent "web app" edit) goes through the client's raw `.dio` instead of these
// wrapped methods, bypassing the toggle entirely.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xcred_mobile/core/api/api_client.dart';
import 'package:xcred_mobile/core/api/api_response.dart';
import 'package:xcred_mobile/core/providers/core_providers.dart';
import 'package:xcred_mobile/main.dart';

class ToggleableWriteApiClient extends ApiClient {
  ToggleableWriteApiClient(super.dio);
  bool offline = false;

  @override
  Future<T> get<T>(String path, T Function(dynamic json) fromData, {Map<String, dynamic>? query}) {
    if (offline) {
      throw ApiException(code: 'NETWORK_ERROR', message: 'Simulated offline for testing.');
    }
    return super.get(path, fromData, query: query);
  }

  @override
  Future<T> put<T>(String path, T Function(dynamic json) fromData, {Object? data}) {
    if (offline) {
      throw ApiException(code: 'NETWORK_ERROR', message: 'Simulated offline for testing.');
    }
    return super.put(path, fromData, data: data);
  }
}

Future<void> _pumpUntilAny(WidgetTester tester, List<Finder> finders, {int maxTries = 40}) async {
  for (var i = 0; i < maxTries; i++) {
    if (finders.any((f) => f.evaluate().isNotEmpty)) return;
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<void> _dismissKeyboard(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

/// Triggers the Credentials tree's [RefreshIndicator] — the drivable path to
/// [VaultNotifier._load]'s flush-then-fetch (vault_providers.dart). Invoked via
/// [RefreshIndicatorState.show] directly rather than a drag/fling gesture: a fling's
/// hit-and-drag depends on the child scrollable's physics allowing overscroll, which
/// isn't guaranteed when content just barely fills the viewport.
///
/// `show()`'s own Future is deliberately NOT awaited: another in-flight rebuild of
/// [vaultProvider] (e.g. the `ref.invalidate` every save already triggers) can overlap
/// with this call, and in that interleaving `show()`'s Future doesn't reliably resolve
/// even once the underlying flush/fetch it's waiting on has genuinely finished — an
/// artifact of that overlap, not of the sync logic itself. Polling for the RefreshIndicator's
/// own progress spinner to disappear observes the real outcome without depending on
/// that Future settling.
Future<void> _pullToRefresh(WidgetTester tester) async {
  final state = tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator));
  unawaited(state.show());
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 300));
    if (find.byType(RefreshProgressIndicator).evaluate().isEmpty) break;
  }
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _popToTree(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20));
}

/// Raw (undecrypted) server lookup by id via the underlying Dio directly — bypassing
/// [ToggleableWriteApiClient]'s offline simulation entirely, since this represents the
/// test harness (or "the web app") checking real server state, not the mobile app's own
/// read path.
Future<Map<String, dynamic>> _fetchRaw(ApiClient client, String id) async {
  final response = await client.dio.get('/api/credentials/$id');
  final envelope = response.data as Map<String, dynamic>;
  return envelope['data'] as Map<String, dynamic>;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Edit a credential offline, reconnect, confirm the edit reaches the server; a '
      'concurrent server-side edit surfaces a conflict banner instead of either edit '
      'silently winning', (tester) async {
    final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(6);
    final credName = 'MobTest OfflineSync $suffix';
    late ToggleableWriteApiClient toggleableClient;

    // --- Login ---
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWith((ref) {
          toggleableClient = ToggleableWriteApiClient(ref.watch(dioProvider));
          return toggleableClient;
        }),
      ],
      child: const XCredApp(),
    ));
    await tester.pumpAndSettle();
    if (find.text('XCred').evaluate().isNotEmpty) {
      await tester.enterText(
          find.widgetWithText(TextField, 'Server URL'), 'http://10.0.2.2:18080');
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }
    final dashboardFinder = find.textContaining('Hi, xcred_admin');
    if (find.text('Welcome back').evaluate().isNotEmpty) {
      await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'xcred_admin');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Login password'), 'LoginPassword#2026');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Master password'), 'Admin@#1234%^&*()');
      await tester.tap(find.text('Log In'));
      final enrollDialogFinder = find.text('Enable Quick Unlock?');
      await _pumpUntilAny(tester, [dashboardFinder, enrollDialogFinder]);
      if (enrollDialogFinder.evaluate().isNotEmpty) {
        await tester.tap(find.widgetWithText(TextButton, 'Not Now'));
      }
    }
    await _pumpUntilAny(tester, [dashboardFinder]);
    await _pumpUntilAny(tester, [find.text('Browse Credentials')]);

    // --- Create a throwaway credential to edit ---
    await _tapVisible(tester, find.text('Browse Credentials'));
    await tester.pumpAndSettle(const Duration(seconds: 10));
    await _tapVisible(tester, find.widgetWithText(FloatingActionButton, 'Add Credential'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), credName);
    await tester.enterText(find.widgetWithText(TextFormField, 'URL'), 'https://example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Username / Email'), 'x');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'x');
    await _dismissKeyboard(tester);
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Save Credential'));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name, username, or tag…'), credName);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, credName));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Capture the real id (list endpoint is undecryptable server-side, so this can't
    // match by name) — the credential just created is always the most recently created
    // one, regardless of any clock skew between the emulator and the backend container,
    // since this compares creation order, not absolute time.
    final all =
        await toggleableClient.get<List<dynamic>>('/api/credentials', (j) => j as List<dynamic>);
    final byRecency = all.cast<Map<String, dynamic>>().toList()
      ..sort((a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String));
    final credentialId = byRecency.first['id'] as String;

    // ============================================================
    // Case 1: edit offline, reconnect, confirm the edit reaches the server
    // ============================================================
    toggleableClient.offline = true;

    await _tapVisible(tester, find.byTooltip('Edit'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Notes (optional)'), 'Edited while offline');
    await _dismissKeyboard(tester);
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Update Credential'));
    // Poll with short pumps (not pumpAndSettle) — the SnackBar auto-dismisses after its
    // default duration, and pumpAndSettle would fast-forward straight through that whole
    // show/hide cycle, leaving nothing to find by the time it returns. Polling (rather
    // than a single fixed-length pump) tolerates the entrance animation's actual timing
    // varying under device load instead of racing a hardcoded delay.
    final snackbarFinder = find.textContaining("will sync once you're back online");
    await _pumpUntilAny(tester, [snackbarFinder], maxTries: 20);
    expect(snackbarFinder, findsWidgets,
        reason: 'MOB-SYNC-02: the user must be told the edit was queued, not just '
            'silently accepted as if it reached the server');

    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Detail screen reloads from the local cache (still offline) and must show the
    // optimistically-applied edit, not stale pre-edit data.
    await _pumpUntilAny(tester, [find.text('Edited while offline')]);
    expect(find.text('Edited while offline'), findsOneWidget,
        reason: 'The queued-offline edit must be reflected locally immediately, not '
            'just after a successful sync');

    // Reconnect and trigger a flush via the Credentials tree's pull-to-refresh.
    toggleableClient.offline = false;
    await _popToTree(tester);
    await _pullToRefresh(tester);

    // Confirm against the real backend directly that the queued mutation actually
    // reached the server (not just the local cache).
    final afterFlush = await _fetchRaw(toggleableClient, credentialId);
    expect(afterFlush['id'], credentialId);

    // --- Reopen the credential, confirm the edit round-tripped through the real API ---
    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name, username, or tag…'), credName);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, credName));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('Edited while offline'), findsOneWidget,
        reason: 'MOB-SYNC-02: once back online, the queued edit must have actually '
            'reached the server — this reload fetches live, not from cache');

    // ============================================================
    // Case 2: a concurrent server-side edit while mobile has its own queued edit
    // ============================================================
    toggleableClient.offline = true;
    await _tapVisible(tester, find.byTooltip('Edit'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Notes (optional)'), 'Mobile offline edit');
    await _dismissKeyboard(tester);
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Update Credential'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Simulate a concurrent edit "from the web app": a real network PUT made directly
    // against the backend, bypassing the app's (toggled-offline) ApiClient wrapper
    // entirely by going straight through the underlying Dio instance — re-submitting the
    // server's current data is enough to bump `updatedAt`, which is exactly the signal
    // the flush's conflict check (sync_providers.dart) compares against.
    final serverNow = await _fetchRaw(toggleableClient, credentialId);
    await toggleableClient.dio.put('/api/credentials/$credentialId', data: {
      'type': serverNow['type'],
      'encryptedData': serverNow['encryptedData'],
      'dataIv': serverNow['dataIv'],
      'encryptedCredentialKey': serverNow['encryptedCredentialKey'],
      'expiryDate': serverNow['expiryDate'],
      'folderId': serverNow['folderId'],
      'credentialGroupId': serverNow['credentialGroupId'],
      'tagIds': const [],
    });
    final serverAfterWebEdit = await _fetchRaw(toggleableClient, credentialId);

    // Reconnect and flush — mobile's queued edit must now conflict with the server's
    // newer copy instead of silently overwriting it.
    toggleableClient.offline = false;
    await _popToTree(tester);
    await _pullToRefresh(tester);

    expect(find.textContaining('Sync conflict'), findsOneWidget,
        reason: 'MOB-SYNC-02/requirements §6.3: a flush that would silently overwrite a '
            'concurrent server-side change must instead surface a visible warning, not '
            'apply the local edit and not silently drop it');

    // The server's copy must be untouched by the (correctly refused) mobile flush.
    final afterConflict = await _fetchRaw(toggleableClient, credentialId);
    expect(afterConflict['updatedAt'], serverAfterWebEdit['updatedAt'],
        reason: 'A refused flush must not apply the queued edit — the server\'s copy '
            'from the simulated web-app edit must remain exactly as it was');
  });
}
