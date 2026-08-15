// End-to-end proof for Sprint 2.3 (MOB-SET-01/02/03/05) against the live Docker dev
// backend. Uses a throwaway account rather than xcred_admin specifically because this
// test changes the account's login password — every other integration test in this
// project hardcodes xcred_admin's password, so mutating it here would break them all.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xcred_mobile/core/platform/file_exchange.dart';
import 'package:xcred_mobile/core/providers/core_providers.dart';
import 'package:xcred_mobile/main.dart';

class FakeFileExchange implements FileExchange {
  PickedFileData? nextPick;
  String? savedFilename;
  Uint8List? savedBytes;
  String? savedMimeType;

  @override
  Future<PickedFileData?> pickFile() async => nextPick;

  @override
  Future<void> saveOrShare(String filename, Uint8List bytes, String mimeType) async {
    savedFilename = filename;
    savedBytes = bytes;
    savedMimeType = mimeType;
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

Future<void> _login(
  WidgetTester tester, {
  required String username,
  required String loginPassword,
  required String masterPassword,
}) async {
  if (find.text('XCred').evaluate().isNotEmpty) {
    await tester.enterText(
        find.widgetWithText(TextField, 'Server URL'), 'http://10.0.2.2:18080');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }
  final dashboardFinder = find.textContaining('Hi, $username');
  if (find.text('Welcome back').evaluate().isNotEmpty) {
    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), username);
    await tester.enterText(find.widgetWithText(TextFormField, 'Login password'), loginPassword);
    await tester.enterText(find.widgetWithText(TextFormField, 'Master password'), masterPassword);
    await tester.tap(find.text('Log In'));
    final enrollDialogFinder = find.text('Enable Quick Unlock?');
    await _pumpUntilAny(tester, [dashboardFinder, enrollDialogFinder]);
    if (enrollDialogFinder.evaluate().isNotEmpty) {
      await tester.tap(find.widgetWithText(TextButton, 'Not Now'));
    }
  }
  await _pumpUntilAny(tester, [dashboardFinder]);
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Profile displays correctly, changing the login password actually takes effect '
      'server-side, a notification preference persists across a re-visit, and backup '
      'export/restore round-trips with correct dedup', (tester) async {
    final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(6);
    final username = 'settingstest_$suffix';
    final email = 'settingstest_$suffix@example.com';
    const oldLoginPassword = 'SettingsTestOld#2026';
    const newLoginPassword = 'SettingsTestNew#2026!!';
    const masterPassword = 'SettingsTestMaster#2026!!';
    const adminUsername = 'xcred_admin';
    const adminLoginPassword = 'LoginPassword#2026';
    final credName = 'MobTest Settings $suffix';

    final fakeExchange = FakeFileExchange();
    await tester.pumpWidget(ProviderScope(
      overrides: [fileExchangeProvider.overrideWithValue(fakeExchange)],
      child: const XCredApp(),
    ));
    await tester.pumpAndSettle();

    // --- Register the throwaway account ---
    if (find.text('XCred').evaluate().isNotEmpty) {
      await tester.enterText(
          find.widgetWithText(TextField, 'Server URL'), 'http://10.0.2.2:18080');
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }
    await _pumpUntilAny(tester, [find.text('Welcome back')]);
    await _tapVisible(tester, find.text("Don't have an account? Register"));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), username);
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(find.widgetWithText(TextFormField, 'Login password'), oldLoginPassword);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm login password'), oldLoginPassword);
    await tester.enterText(find.widgetWithText(TextFormField, 'Master password'), masterPassword);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm master password'), masterPassword);
    await _dismissKeyboard(tester);
    await _tapVisible(tester, find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Create Account'));
    await tester.pumpAndSettle(const Duration(seconds: 10));
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Go to Login'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // --- Approve via a raw admin API call ---
    final adminDio =
        Dio(BaseOptions(baseUrl: 'http://10.0.2.2:18080', contentType: 'application/json'));
    final loginResp = await adminDio.post('/api/auth/login',
        data: {'username': adminUsername, 'password': adminLoginPassword});
    final adminToken = ((loginResp.data as Map)['data'] as Map)['accessToken'] as String;
    adminDio.options.headers['Authorization'] = 'Bearer $adminToken';
    final pendingResp =
        await adminDio.get('/api/admin/users', queryParameters: {'pendingOnly': true});
    final pendingUsers = ((pendingResp.data as Map)['data'] as List).cast<Map<String, dynamic>>();
    final userId = pendingUsers.firstWhere((u) => u['username'] == username)['id'];
    await adminDio.post('/api/admin/users/$userId/approve');

    // ============================================================
    // Log in, check the Profile section
    // ============================================================
    await _login(tester,
        username: username, loginPassword: oldLoginPassword, masterPassword: masterPassword);

    await _tapVisible(tester, find.byTooltip('Settings'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text(username), findsOneWidget,
        reason: 'MOB-SET-01: the profile section must show the real username from '
            'GET /api/auth/profile');
    expect(find.text(email), findsOneWidget,
        reason: 'MOB-SET-01: the profile section must show the real email');

    // ============================================================
    // Change the login password, confirm it actually takes effect server-side
    // ============================================================
    await _tapVisible(tester, find.widgetWithText(OutlinedButton, 'Change Login Password'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Current password'), oldLoginPassword);
    await tester.enterText(find.widgetWithText(TextField, 'New password'), newLoginPassword);
    await tester.enterText(
        find.widgetWithText(TextField, 'Confirm new password'), newLoginPassword);
    await _dismissKeyboard(tester);
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Change'));
    final passwordChangedFinder = find.text('Login password changed.');
    await _pumpUntilAny(tester, [passwordChangedFinder], maxTries: 20);
    expect(passwordChangedFinder, findsOneWidget,
        reason: 'MOB-SET-01: the app must confirm the password change succeeded');
    // Explicitly wait for the SnackBar to actually disappear — a screenshot confirmed
    // it's docked to the bottom of the *viewport* (not the scrollable content), so it
    // permanently overlaps whatever list content ends up at the bottom edge regardless
    // of scroll position, until it genuinely dismisses.
    for (var i = 0; i < 30 && passwordChangedFinder.evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.fling(find.byType(SingleChildScrollView).first, const Offset(0, -2000), 5000);
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.widgetWithText(ListTile, 'Log Out'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Logging in with the OLD password must now fail, and the NEW one must work —
    // proves the change actually reached the server, not just closed the dialog.
    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), username);
    await tester.enterText(find.widgetWithText(TextFormField, 'Login password'), oldLoginPassword);
    await tester.enterText(find.widgetWithText(TextFormField, 'Master password'), masterPassword);
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('Welcome back'), findsOneWidget,
        reason: 'MOB-SET-01: the OLD login password must no longer work after the change');

    await _login(tester,
        username: username, loginPassword: newLoginPassword, masterPassword: masterPassword);

    // ============================================================
    // Toggle a notification preference, confirm it persists across a re-visit
    // ============================================================
    await _tapVisible(tester, find.byTooltip('Settings'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final expiryToggleFinder = find.widgetWithText(SwitchListTile, 'Expiry Reminders');
    expect(tester.widget<SwitchListTile>(expiryToggleFinder).value, isTrue,
        reason: 'Defaults to on, per NotificationPreferences.defaults');
    await _tapVisible(tester, expiryToggleFinder);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(tester.widget<SwitchListTile>(expiryToggleFinder).value, isFalse,
        reason: 'The tap must have actually reached the switch (local optimistic state)');
    expect(find.text('Failed to save notification preferences.'), findsNothing,
        reason: 'The save must have actually succeeded, not silently failed');

    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _tapVisible(tester, find.byTooltip('Settings'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Expiry Reminders')).value,
        isFalse,
        reason: 'MOB-SET-02: the toggle must actually reach the server and be reflected '
            'on a fresh fetch, not just update local state');

    // ============================================================
    // Backup export/restore round-trip
    // ============================================================
    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 3));
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

    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _tapVisible(tester, find.byTooltip('Settings'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await _tapVisible(tester, find.widgetWithText(OutlinedButton, 'Export'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(fakeExchange.savedBytes, isNotNull,
        reason: 'MOB-SET-03: export must produce real backup bytes');
    final originalBackupBytes = fakeExchange.savedBytes!;

    fakeExchange.nextPick = PickedFileData(
      name: 'backup.xcredbak',
      bytes: originalBackupBytes,
      mimeType: 'application/json',
    );
    await _tapVisible(tester, find.widgetWithText(OutlinedButton, 'Restore'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('Restore Backup?'), findsOneWidget);
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Restore'));
    final restoreCompleteFinder = find.text('Restore Complete');
    await _pumpUntilAny(tester, [restoreCompleteFinder], maxTries: 20);
    expect(restoreCompleteFinder, findsOneWidget);
    expect(find.textContaining('1 already existed'), findsOneWidget,
        reason: 'MOB-SET-03: restoring a backup of data that already exists must be '
            "recognized as a duplicate and skipped, not silently re-created — the "
            'export/restore round trip must preserve identity');
    await _tapVisible(tester, find.widgetWithText(TextButton, 'OK'));
    await tester.pumpAndSettle();

    // ============================================================
    // Plain JSON export (failsafe) — decrypts real data, not a stub
    // ============================================================
    await _tapVisible(tester, find.widgetWithText(OutlinedButton, 'Export All as Plain JSON'));
    await tester.pumpAndSettle();
    expect(find.text('Export as Plain JSON?'), findsOneWidget);
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Export'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final plainJson = jsonDecode(utf8.decode(fakeExchange.savedBytes!)) as Map<String, dynamic>;
    expect(plainJson['warning'], contains('UNENCRYPTED'),
        reason: 'The export must carry an explicit unencrypted warning');
    final exportedCreds = (plainJson['credentials'] as List).cast<Map<String, dynamic>>();
    final exportedCred =
        exportedCreds.firstWhere((c) => c['name'] == credName, orElse: () => <String, dynamic>{});
    expect(exportedCred['password'], 'x',
        reason: 'The plain JSON export must contain the real decrypted password, not a stub');
    expect(exportedCred['username'], 'x');

    // ============================================================
    // Cross-machine backup refusal — MOB-SET-03 fix. Simulates a backup exported by a
    // DIFFERENT account identity (as if from a fresh re-registration on another
    // machine) by swapping in an unrelated publicKey. Full account-key restore
    // (re-wrapping and swapping this account's identity) is deliberately web-only, same
    // as master-password rotation (MOB-SET-04) — mobile's job is just to refuse
    // clearly instead of reproducing the original "silently succeeds, then every
    // credential fails to decrypt" bug on this platform too.
    // ============================================================
    final foreignBackup = jsonDecode(utf8.decode(originalBackupBytes)) as Map<String, dynamic>;
    expect(foreignBackup['publicKey'], isNotNull,
        reason: 'Backups exported by the fixed BackupController must carry account crypto '
            'material for this refusal check to mean anything');
    foreignBackup['publicKey'] = 'not-the-same-account-public-key';
    fakeExchange.nextPick = PickedFileData(
      name: 'foreign-backup.xcredbak',
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(foreignBackup))),
      mimeType: 'application/json',
    );
    await _tapVisible(tester, find.widgetWithText(OutlinedButton, 'Restore'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text("Can't Restore This Backup Here"), findsOneWidget,
        reason: 'A backup from a different account identity must be refused up front, not '
            'silently "restored" into an undecryptable state');
    expect(find.text('Restore Backup?'), findsNothing,
        reason: 'The normal restore confirmation must never appear for a mismatched backup');
  });
}
