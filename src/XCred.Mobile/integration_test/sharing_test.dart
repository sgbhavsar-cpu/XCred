// End-to-end proof for Sprint 2.1 (MOB-SHARE-01/02) against the live Docker dev backend.
//
// Needs a second real account to prove cross-user decryption, so this test: registers a
// throwaway recipient user through the real UI, approves them via a raw admin API call
// (a brand-new user needs admin approval before `GET /api/users` will surface them as a
// share recipient — there's no UI path to self-approve, so this one step legitimately
// has to bypass the app), then logs in and out of both accounts within the app to prove
// the share is actually decryptable by the recipient and that revoking it removes their
// access — not just that the right HTTP calls were made.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xcred_mobile/main.dart';

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

/// Logs in as [username]/[loginPassword]/[masterPassword] from whatever screen the app
/// is currently showing after a connect/logout (Server Setup or Login), handling the
/// one-time-per-session biometric-enrollment dialog exactly like every other sprint's
/// tests.
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

/// Full logout (not "Lock now") so the next [_login] call always lands on a clean
/// `/login` screen rather than `/unlock` — matches dashboard_screen.dart's
/// `_logOut()`, which clears persisted session + secure storage. The "Log out" button
/// only exists on the dashboard's AppBar, and this is called from wherever the test's
/// last action left off (credential detail, the Shares screen, ...), so pop back
/// through the navigation stack until it's reachable rather than assuming a fixed depth.
Future<void> _logout(WidgetTester tester) async {
  for (var i = 0; i < 5 && find.byTooltip('Log out').evaluate().isEmpty; i++) {
    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }
  await _tapVisible(tester, find.byTooltip('Log out'));
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Share a credential, confirm the recipient can decrypt it after logging in as '
      'them; revoke it, confirm it disappears from their Shared With Me', (tester) async {
    final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(6);
    final credName = 'MobTest Sharing $suffix';
    final recipientUsername = 'sharetest_$suffix';
    final recipientEmail = 'sharetest_$suffix@example.com';
    const recipientLoginPassword = 'ShareTestLogin#2026';
    const recipientMasterPassword = 'ShareTestMaster#2026!!';
    const adminUsername = 'xcred_admin';
    const adminLoginPassword = 'LoginPassword#2026';
    const adminMasterPassword = 'Admin@#1234%^&*()';

    await tester.pumpWidget(const ProviderScope(child: XCredApp()));
    await tester.pumpAndSettle();

    // --- Register the throwaway recipient account ---
    if (find.text('XCred').evaluate().isNotEmpty) {
      await tester.enterText(
          find.widgetWithText(TextField, 'Server URL'), 'http://10.0.2.2:18080');
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }
    await _pumpUntilAny(tester, [find.text('Welcome back')]);
    await _tapVisible(tester, find.text("Don't have an account? Register"));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), recipientUsername);
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), recipientEmail);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Login password'), recipientLoginPassword);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm login password'), recipientLoginPassword);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Master password'), recipientMasterPassword);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm master password'), recipientMasterPassword);
    await _dismissKeyboard(tester);
    await _tapVisible(tester, find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Create Account'));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    expect(find.textContaining('Awaiting admin approval'), findsOneWidget,
        reason: 'A second (non-first) user must not be auto-approved.');
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Go to Login'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // --- Approve the new user via a raw admin API call (no UI path for self-approval) ---
    final adminDio =
        Dio(BaseOptions(baseUrl: 'http://10.0.2.2:18080', contentType: 'application/json'));
    final loginResp = await adminDio.post('/api/auth/login',
        data: {'username': adminUsername, 'password': adminLoginPassword});
    final adminToken = ((loginResp.data as Map)['data'] as Map)['accessToken'] as String;
    adminDio.options.headers['Authorization'] = 'Bearer $adminToken';

    final pendingResp =
        await adminDio.get('/api/admin/users', queryParameters: {'pendingOnly': true});
    final pendingUsers = ((pendingResp.data as Map)['data'] as List).cast<Map<String, dynamic>>();
    final recipientId = pendingUsers.firstWhere((u) => u['username'] == recipientUsername)['id'];
    await adminDio.post('/api/admin/users/$recipientId/approve');

    // ============================================================
    // Create a credential as admin and share it with the recipient
    // ============================================================
    await _login(tester,
        username: adminUsername,
        loginPassword: adminLoginPassword,
        masterPassword: adminMasterPassword);

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

    await _tapVisible(tester, find.byTooltip('Share'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    // The dropdown starts with no value selected (nothing to target by displayed text
    // yet, unlike the folder/tag pickers elsewhere), so open it by widget type instead.
    await _tapVisible(tester, find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    // This session has accumulated dozens of throwaway users across every earlier
    // sprint's tests — the dropdown's own popup menu is a Sliver-backed
    // ListView(children:) (same lazy-build class documented in
    // credential_form_screen.dart and admin_test.dart's Users tab), so the newest
    // (target) recipient can be scrolled well past what's initially built.
    // scrollUntilVisible's automatic `find.byType(Scrollable).last` resolution is
    // ambiguous/unstable here (the popup route sits alongside the dialog's own
    // scrollable) — drag the popup's ListView directly instead, which is the only
    // ListView present while the menu is open.
    //
    // Deliberately NOT `.last` here: the `.last`/`.first` finder combinators throw
    // (not return empty) when zero candidates match — fine once existence is
    // confirmed, wrong for a "does it exist yet" polling condition.
    final recipientItemBaseFinder = find.text('$recipientUsername ($recipientEmail)');
    // Two ListViews are on screen while the menu is open (the dialog's own content
    // area is a ListView too) — the popup menu's is the shrink-wrapped one, added
    // most recently, so `.last`.
    final dropdownListFinder = find.byType(ListView).last;
    for (var i = 0; i < 15 && recipientItemBaseFinder.evaluate().isEmpty; i++) {
      await tester.drag(dropdownListFinder, const Offset(0, -300));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(recipientItemBaseFinder, findsWidgets,
        reason: 'The recipient must be reachable in the share-with dropdown after '
            'scrolling');
    await tester.tap(recipientItemBaseFinder.last);
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Share'));
    // Poll with short pumps (not a single long pumpAndSettle) — the confirmation
    // SnackBar auto-dismisses after a few seconds, and pumpAndSettle's duration
    // argument is a poll *interval*, not a wait cap, so it can fast-forward straight
    // through the whole show/hide cycle and find nothing (same bug class fixed in
    // offline_sync_test.dart).
    final sharedSnackbarFinder = find.textContaining('Shared with $recipientUsername');
    await _pumpUntilAny(tester, [sharedSnackbarFinder], maxTries: 20);
    expect(sharedSnackbarFinder, findsOneWidget,
        reason: 'MOB-SHARE-02: the app must confirm who the credential was shared with');
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await _logout(tester);

    // ============================================================
    // Log in as the recipient — confirm the share is decryptable
    // ============================================================
    await _login(tester,
        username: recipientUsername,
        loginPassword: recipientLoginPassword,
        masterPassword: recipientMasterPassword);

    await _tapVisible(tester, find.text('Shared With Me'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text(credName), findsOneWidget,
        reason: 'MOB-SHARE-01/02: the recipient must be able to decrypt the shared '
            "credential's name using their own private key, proving the AES data-key "
            "was correctly re-wrapped under the recipient's public key");
    expect(find.textContaining('Shared by $adminUsername'), findsOneWidget);

    await _logout(tester);

    // ============================================================
    // Log back in as admin and revoke the share
    // ============================================================
    await _login(tester,
        username: adminUsername,
        loginPassword: adminLoginPassword,
        masterPassword: adminMasterPassword);

    await _tapVisible(tester, find.text('Shared With Me').first);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await _tapVisible(tester, find.text('Shared By Me'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Earlier interrupted test runs can leave other "Active" shares behind (each a
    // distinct throwaway credential, never revoked because that run failed before
    // reaching this step) — scope to *this* run's card rather than a bare tooltip
    // lookup, which would match every one of them.
    final activeCardFinder = find.widgetWithText(ListTile, credName);
    expect(activeCardFinder, findsOneWidget,
        reason: 'The owner must see their own active share before revoking it');
    await _tapVisible(
        tester, find.descendant(of: activeCardFinder, matching: find.byTooltip('Revoke')));
    await tester.pumpAndSettle();
    expect(find.text('Revoke Access?'), findsOneWidget);
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Revoke'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await _logout(tester);

    // ============================================================
    // Log back in as the recipient — confirm the share is gone
    // ============================================================
    await _login(tester,
        username: recipientUsername,
        loginPassword: recipientLoginPassword,
        masterPassword: recipientMasterPassword);

    await _tapVisible(tester, find.text('Shared With Me'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text(credName), findsNothing,
        reason: 'MOB-SHARE-02/requirements: revoking a share must remove the '
            "recipient's access immediately — it must not still appear in their "
            'Shared With Me list');
  });
}
