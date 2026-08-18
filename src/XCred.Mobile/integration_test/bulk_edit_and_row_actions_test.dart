// End-to-end proof for the mobile parity pass brought over from the web app in the same
// session: credential row actions (Edit/Duplicate/Copy Password/Delete via the row's "⋮"
// menu), Folders/Tags search boxes + Unassigned/Untagged sections, and multi-select bulk
// edit (folder/group assignment on Folders/Credentials, tag add/remove on Tags) — all run
// against the live Docker dev backend.
//
// Uses a freshly-registered throwaway account (approved via a raw HTTP call, the same
// technique the web Playwright suite uses) rather than the shared `xcred_admin` account:
// that account has accumulated hundreds of credentials across this whole project's test
// history, and GetAll() for it was independently measured taking ~27s earlier this
// session — nowhere near what a `pumpAndSettle` window can reasonably wait out. One fresh
// account also sidesteps the open question of whether an in-memory-only AuthSession
// (core/auth/auth_session.dart's own docs: lost on "app restart, process death") would
// carry over between separate `testWidgets` blocks in this file — there's only one login
// for the whole test, so it's moot.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xcred_mobile/main.dart';

const _baseUrl = 'http://10.0.2.2:18080';
const _loginPassword = 'LoginPassword#2026';
const _masterPassword = 'Admin@#1234%^&*()';

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

/// Approves a just-registered (non-first, so pending-approval) user via a raw HTTP call
/// using the existing `xcred_admin` account — mirrors the web Playwright suite's
/// `registerAndLoginFreshUser` helper, since the mobile app itself has no admin-approval
/// UI to drive instead.
Future<void> _approveViaAdmin(String username) async {
  final dio = Dio(BaseOptions(baseUrl: _baseUrl));
  final loginRes = await dio.post<Map<String, dynamic>>('/api/auth/login',
      data: {'username': 'xcred_admin', 'password': _loginPassword});
  final token = loginRes.data!['data']['accessToken'] as String;
  final pendingRes = await dio.get<Map<String, dynamic>>('/api/admin/users',
      queryParameters: {'pendingOnly': true},
      options: Options(headers: {'Authorization': 'Bearer $token'}));
  final list = pendingRes.data!['data'] as List<dynamic>;
  final user = list.firstWhere((u) => (u as Map<String, dynamic>)['username'] == username)
      as Map<String, dynamic>;
  await dio.post<void>('/api/admin/users/${user['id']}/approve',
      options: Options(headers: {'Authorization': 'Bearer $token'}));
}

/// Registers a fresh throwaway user, approves it via [_approveViaAdmin], then logs in —
/// leaving the tester on the dashboard, ready to reach "Browse Credentials".
Future<void> _registerApproveAndLogin(WidgetTester tester, String usernamePrefix) async {
  final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(6);
  final username = '$usernamePrefix$suffix';
  final email = '$username@example.com';

  await tester.pumpWidget(const ProviderScope(child: XCredApp()));
  await tester.pumpAndSettle();
  if (find.text('XCred').evaluate().isNotEmpty) {
    await tester.enterText(find.widgetWithText(TextField, 'Server URL'), _baseUrl);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }

  await tester.tap(find.text("Don't have an account? Register"));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, 'Username'), username);
  await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
  await tester.enterText(find.widgetWithText(TextFormField, 'Login password'), _loginPassword);
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm login password'), _loginPassword);
  await tester.enterText(find.widgetWithText(TextFormField, 'Master password'), _masterPassword);
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm master password'), _masterPassword);
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pumpAndSettle();
  final submitButton = find.widgetWithText(FilledButton, 'Create Account');
  await tester.ensureVisible(submitButton);
  await tester.pumpAndSettle();
  await tester.tap(submitButton);
  await tester.pumpAndSettle(const Duration(seconds: 15));
  expect(find.textContaining('Awaiting admin approval'), findsOneWidget);

  await _approveViaAdmin(username);

  // RegisterScreen was reached via context.go('/register'), which replaces the route
  // (no back-stack entry), so tester.pageBack() has nothing to pop — use the screen's own
  // "Go to Login" button shown in the awaiting-approval state instead.
  await _tapVisible(tester, find.widgetWithText(FilledButton, 'Go to Login'));
  await tester.pumpAndSettle(const Duration(seconds: 3));
  await tester.enterText(find.widgetWithText(TextFormField, 'Username'), username);
  await tester.enterText(find.widgetWithText(TextFormField, 'Login password'), _loginPassword);
  await tester.enterText(find.widgetWithText(TextFormField, 'Master password'), _masterPassword);
  await tester.tap(find.text('Log In'));
  final dashboardFinder = find.textContaining('Hi, $username');
  final enrollDialogFinder = find.text('Enable Quick Unlock?');
  await _pumpUntilAny(tester, [dashboardFinder, enrollDialogFinder]);
  if (enrollDialogFinder.evaluate().isNotEmpty) {
    await tester.tap(find.widgetWithText(TextButton, 'Not Now'));
  }
  await _pumpUntilAny(tester, [dashboardFinder]);
  await _pumpUntilAny(tester, [find.text('Browse Credentials')]);
}

Future<void> _createSecureNote(WidgetTester tester, String name) async {
  await _tapVisible(tester, find.widgetWithText(FloatingActionButton, 'Add Credential'));
  await tester.pumpAndSettle();
  await _tapVisible(tester, find.text('Secure Note'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, 'Name'), name);
  await tester.enterText(find.widgetWithText(TextFormField, 'Note Content'), 'irrelevant body');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
  await _tapVisible(tester, find.widgetWithText(FilledButton, 'Save Credential'));
  await tester.pumpAndSettle(const Duration(seconds: 8));
}

Future<void> _createWebsiteLogin(WidgetTester tester, String name, String password) async {
  await _tapVisible(tester, find.widgetWithText(FloatingActionButton, 'Add Credential'));
  await tester.pumpAndSettle();
  await _tapVisible(tester, find.text('Website Login'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, 'Name'), name);
  await tester.enterText(find.widgetWithText(TextFormField, 'Username / Email'), 'rowuser');
  await tester.enterText(find.widgetWithText(TextFormField, 'Password'), password);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
  await _tapVisible(tester, find.widgetWithText(FilledButton, 'Save Credential'));
  await tester.pumpAndSettle(const Duration(seconds: 8));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Row "⋮" menu (Edit/Duplicate/Copy Password/Delete), Folders/Tags search + '
      'Unassigned/Untagged, and multi-select bulk edit — all against a fresh account',
      (tester) async {
    await _registerApproveAndLogin(tester, 'mobparity');
    final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(6);

    await _tapVisible(tester, find.text('Browse Credentials'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // ================== Row actions: Edit, Copy Password, Duplicate, Delete ==================
    final loginName = 'MobRow WebsiteLogin $suffix';
    const password = 'RowActionsPass#1';
    await _createWebsiteLogin(tester, loginName, password);
    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name, username, or tag…'), loginName);
    await tester.pumpAndSettle();

    // --- Edit ---
    await _tapVisible(tester, find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Edit'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(
        (tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Name')))
            .controller
            ?.text,
        loginName,
        reason: 'Edit should open directly in edit mode, pre-filled');
    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // --- Copy Password ---
    await _tapVisible(tester, find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.text('Copy Password'), findsOneWidget,
        reason: 'WebsiteLogin has a password field, so the action must be offered');
    await _tapVisible(tester, find.text('Copy Password'));
    await tester.pumpAndSettle();
    expect(find.text('Password copied to clipboard.'), findsOneWidget);
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    expect(clipboard?.text, password);

    // --- Duplicate ---
    await _tapVisible(tester, find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Duplicate'));
    await tester.pumpAndSettle(const Duration(seconds: 8));
    expect(find.text('Credential duplicated.'), findsOneWidget);
    expect(
        (tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Name')))
            .controller
            ?.text,
        '$loginName (Copy)',
        reason: 'Duplicate should open the new copy directly in edit mode');
    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // --- Delete the duplicate ---
    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name, username, or tag…'), loginName);
    await tester.pumpAndSettle();
    expect(find.textContaining(loginName), findsWidgets,
        reason: 'Both the original and its duplicate should now exist');
    await _tapVisible(
        tester,
        find.descendant(
            of: find.ancestor(
                of: find.text('$loginName (Copy)'), matching: find.byType(ListTile)),
            matching: find.byIcon(Icons.more_vert)));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Delete'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('Credential deleted.'), findsOneWidget);
    expect(find.text('$loginName (Copy)'), findsNothing);

    // ================== Folders: search, Unassigned, multi-select bulk-assign ==================
    final folderName = 'MobBulk Folder $suffix';
    final folderCredName = 'MobBulk FolderCred $suffix';
    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name, username, or tag…'), '');
    await tester.pumpAndSettle();
    await _createSecureNote(tester, folderCredName);

    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _tapVisible(tester, find.widgetWithText(OutlinedButton, 'Folders'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.widgetWithText(TextField, 'Search by name, username, or tag…'), findsOneWidget);

    await _tapVisible(tester, find.widgetWithText(FloatingActionButton, 'New Folder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Folder name'), folderName);
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name, username, or tag…'), folderCredName);
    await tester.pumpAndSettle();
    expect(find.text('UNASSIGNED'), findsOneWidget,
        reason: 'A credential with no folder must show under Unassigned');
    expect(find.widgetWithText(ListTile, folderCredName), findsOneWidget);

    await tester.longPress(find.widgetWithText(ListTile, folderCredName));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    await _tapVisible(tester, find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bulk edit 1 credential'), findsOneWidget);
    await _tapVisible(tester, find.widgetWithText(TextButton, 'Change').first);
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.widgetWithText(ListTile, folderName));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.textContaining('Updated 1 credential'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name, username, or tag…'), folderCredName);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, folderName), findsOneWidget,
        reason: 'The folder must show as a search match now that it contains the credential');

    // ================== Tags: search, Untagged, multi-select bulk-add ==================
    // Back to the dashboard first — Folders' FAB is "New Folder", not "Add Credential",
    // so a fresh credential must be created from the Credentials tree screen instead.
    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _tapVisible(tester, find.text('Browse Credentials'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final tagName = 'MobBulkTag$suffix';
    final tagCredName = 'MobBulk TagCred $suffix';
    await _createSecureNote(tester, tagCredName);

    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _tapVisible(tester, find.widgetWithText(OutlinedButton, 'Tags'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.widgetWithText(TextField, 'Search by name or username…'), findsOneWidget);

    await _tapVisible(tester, find.widgetWithText(FloatingActionButton, 'New Tag'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Tag name'), tagName);
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name or username…'), tagCredName);
    await tester.pumpAndSettle();
    expect(find.text('UNTAGGED'), findsOneWidget,
        reason: 'A credential with no tags must show under Untagged');

    await tester.longPress(find.widgetWithText(ListTile, tagCredName));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    await _tapVisible(tester, find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bulk edit tags on 1 credential'), findsOneWidget);
    await _tapVisible(tester, find.text(tagName)); // first tap = add
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.textContaining('Updated 1 credential'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name or username…'), tagCredName);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, tagName), findsOneWidget,
        reason: 'The tag must show as a search match now that the credential carries it');
  });
}
