// End-to-end proof for Sprint 2.2 (MOB-TEAM-01) against the live Docker dev backend.
//
// The sprint's whole point is a regression guard: the web app had a bug where a
// non-global-admin team admin couldn't add a member, because the picker called the
// admin-gated `/admin/users` endpoint and silently swallowed the resulting 403 (fixed
// this session by switching to `/users`, which GroupsController.cs's `AddMember` was
// always correctly authorizing against — the bug was purely which users-list endpoint
// fed the picker). This test proves mobile was built on the fixed pattern from the
// start: a throwaway *non-admin* user creates a team (auto-becoming that team's own
// Admin), and must be able to add a member without ever holding the global Admin role.
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
      'A non-global-admin team admin (the team creator) can create a team and add a '
      'member — the exact scenario a web-app bug this session silently broke',
      (tester) async {
    final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(6);
    final teamName = 'MobTest Team $suffix';
    final memberUsername = 'teamtest_$suffix';
    final memberEmail = 'teamtest_$suffix@example.com';
    const memberLoginPassword = 'TeamTestLogin#2026';
    const memberMasterPassword = 'TeamTestMaster#2026!!';
    const adminUsername = 'xcred_admin';
    const adminLoginPassword = 'LoginPassword#2026';

    await tester.pumpWidget(const ProviderScope(child: XCredApp()));
    await tester.pumpAndSettle();

    // --- Register the throwaway (non-admin) team-creator account ---
    if (find.text('XCred').evaluate().isNotEmpty) {
      await tester.enterText(
          find.widgetWithText(TextField, 'Server URL'), 'http://10.0.2.2:18080');
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }
    await _pumpUntilAny(tester, [find.text('Welcome back')]);
    await _tapVisible(tester, find.text("Don't have an account? Register"));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), memberUsername);
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), memberEmail);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Login password'), memberLoginPassword);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm login password'), memberLoginPassword);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Master password'), memberMasterPassword);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm master password'), memberMasterPassword);
    await _dismissKeyboard(tester);
    await _tapVisible(tester, find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Create Account'));
    await tester.pumpAndSettle(const Duration(seconds: 10));
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Go to Login'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // --- Approve via a raw admin API call (no UI path for self-approval) ---
    final adminDio =
        Dio(BaseOptions(baseUrl: 'http://10.0.2.2:18080', contentType: 'application/json'));
    final loginResp = await adminDio.post('/api/auth/login',
        data: {'username': adminUsername, 'password': adminLoginPassword});
    final adminToken = ((loginResp.data as Map)['data'] as Map)['accessToken'] as String;
    adminDio.options.headers['Authorization'] = 'Bearer $adminToken';

    final pendingResp =
        await adminDio.get('/api/admin/users', queryParameters: {'pendingOnly': true});
    final pendingUsers = ((pendingResp.data as Map)['data'] as List).cast<Map<String, dynamic>>();
    final memberId = pendingUsers.firstWhere((u) => u['username'] == memberUsername)['id'];
    await adminDio.post('/api/admin/users/$memberId/approve');

    // ============================================================
    // Log in as the non-admin user, create a team, add xcred_admin as a member
    // ============================================================
    await _login(tester,
        username: memberUsername,
        loginPassword: memberLoginPassword,
        masterPassword: memberMasterPassword);

    await _tapVisible(tester, find.text('Teams'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await _tapVisible(tester, find.widgetWithText(FloatingActionButton, 'New Team'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Team name'), teamName);
    await _dismissKeyboard(tester);
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text(teamName), findsOneWidget,
        reason: 'The newly created team must appear in the caller\'s team list');
    await _tapVisible(tester, find.widgetWithText(ListTile, teamName));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // MOB-TEAM-01's crux: the "Add Member" action must be offered to the team's
    // creator (a per-team Admin) even though this account holds no global role at all.
    final addMemberFinder = find.widgetWithText(FloatingActionButton, 'Add Member');
    expect(addMemberFinder, findsOneWidget,
        reason: 'A non-global-admin team admin must still be offered Add Member — this '
            'is the exact permission the web-app bug this session silently broke');
    await _tapVisible(tester, addMemberFinder);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // The picker renders "username (email)" — admin's real email isn't known to this
    // test, so match by username prefix rather than a guessed full string.
    await tester.tap(find.textContaining('$adminUsername (').first);
    // Poll (not a single pumpAndSettle, which can fast-forward straight through a
    // failure SnackBar's whole show/hide cycle and leave nothing to find — same bug
    // class fixed elsewhere this session) for either outcome, so a real failure is
    // reported with its actual message instead of a generic "0 widgets" mismatch.
    final membersUpdatedFinder = find.text('MEMBERS (2)');
    final failedSnackbarFinder = find.text('Failed to add member.');
    await _pumpUntilAny(tester, [membersUpdatedFinder, failedSnackbarFinder], maxTries: 20);
    expect(failedSnackbarFinder, findsNothing,
        reason: 'Add Member reported failure — check GroupsController.AddMember\'s '
            "authorization for a non-global-admin team creator adding to their own team");

    expect(membersUpdatedFinder, findsOneWidget,
        reason: 'MOB-TEAM-01: adding a member as a non-global-admin team admin must '
            'actually reach the server, not just close the dialog');
    expect(find.widgetWithText(ListTile, adminUsername), findsOneWidget,
        reason: 'The newly added member must appear in the team\'s member list');
  });
}
