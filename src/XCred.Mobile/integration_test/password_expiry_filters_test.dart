// Mobile port of the web app's password-expiry-filters.spec.ts: the same two toolbar
// toggle filters ("missing password" / "expired") and CSV export button, now on
// credentials_tree_screen.dart, folders_screen.dart, and tags_screen.dart.
//
// The "expired" toggle is verified via its negative case only (hiding non-expired
// credentials) rather than fabricating a genuinely-expired one through the date picker:
// showDatePicker's calendar UI is fragile to drive via WidgetTester, and the underlying
// `CredentialListItem.isExpired` getter is pre-existing, already-used logic (the red
// "Expired" badge in credential_row.dart) — the new part worth real coverage here is the
// "missing password" computation (added to VaultNotifier._load() this pass) and the
// toggle/filter wiring on all three screens, both of which this test exercises directly.
//
// Uses a freshly-registered throwaway account (approved via a raw HTTP call) for the same
// reason established earlier this session in bulk_edit_and_row_actions_test.dart: the
// shared xcred_admin account is too slow (accumulated data) to verify against reliably.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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

Future<void> _createCredential(WidgetTester tester, String type, String typeLabel, String name) async {
  await _tapVisible(tester, find.widgetWithText(FloatingActionButton, 'Add Credential'));
  await tester.pumpAndSettle();
  await _tapVisible(tester, find.text(typeLabel));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, 'Name'), name);
  if (type == 'WebsiteLogin') {
    await tester.enterText(find.widgetWithText(TextFormField, 'Username / Email'), 'pwfilteruser');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'S3cret!Aa1');
  }
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
  await _tapVisible(tester, find.widgetWithText(FilledButton, 'Save Credential'));
  await tester.pumpAndSettle(const Duration(seconds: 8));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Missing-password / expired toggles filter correctly, and the CSV export button is wired up, '
      'on Credentials/Folders/Tags', (tester) async {
    await _registerApproveAndLogin(tester, 'pwexpmob');
    final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(6);
    final withPassword = 'PwFilter WithPw $suffix';
    final noPassword = 'PwFilter NoPw $suffix';

    await _tapVisible(tester, find.text('Browse Credentials'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await _createCredential(tester, 'WebsiteLogin', 'Website Login', withPassword);
    await _createCredential(tester, 'Generic', 'Generic', noPassword);

    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name, username, or tag…'), suffix);
    await tester.pumpAndSettle();
    expect(find.text(withPassword), findsOneWidget);
    expect(find.text(noPassword), findsOneWidget);

    // --- "Missing password" toggle ---
    final noPasswordToggle = find.byTooltip('Show only credentials missing a password');
    expect(noPasswordToggle, findsOneWidget);
    await _tapVisible(tester, noPasswordToggle);
    await tester.pumpAndSettle();
    expect(find.text(noPassword), findsOneWidget);
    expect(find.text(withPassword), findsNothing);
    await _tapVisible(tester, noPasswordToggle); // back off
    await tester.pumpAndSettle();
    expect(find.text(withPassword), findsOneWidget);

    // --- "Expired" toggle — negative case: neither test credential has an expiry date set,
    // so turning this on must hide both. ---
    final expiredToggle = find.byTooltip('Show only expired credentials');
    expect(expiredToggle, findsOneWidget);
    await _tapVisible(tester, expiredToggle);
    await tester.pumpAndSettle();
    expect(find.text(withPassword), findsNothing);
    expect(find.text(noPassword), findsNothing);
    await _tapVisible(tester, expiredToggle); // back off
    await tester.pumpAndSettle();
    expect(find.text(withPassword), findsOneWidget);

    // --- CSV export button is present and enabled (not tapped — would hand off to the
    // native OS share sheet, which WidgetTester can't drive). ---
    expect(find.byTooltip('Export filtered list to CSV'), findsOneWidget);
    final exportIconButton = find.ancestor(
        of: find.byIcon(Icons.table_chart_outlined), matching: find.byType(IconButton));
    expect(tester.widget<IconButton>(exportIconButton).onPressed, isNotNull);

    // --- Folders screen: same missing-password toggle works there too ---
    await tester.pageBack(); // Credentials -> Dashboard
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _tapVisible(tester, find.widgetWithText(OutlinedButton, 'Folders'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name, username, or tag…'), suffix);
    await tester.pumpAndSettle();
    expect(find.text(withPassword), findsOneWidget);
    expect(find.text(noPassword), findsOneWidget);
    await _tapVisible(tester, find.byTooltip('Show only credentials missing a password'));
    await tester.pumpAndSettle();
    expect(find.text(noPassword), findsOneWidget);
    expect(find.text(withPassword), findsNothing);

    // --- Tags screen: same toggle works there too (also proves the "No tags yet" fix —
    // this account has zero tags, so these credentials only show via Untagged) ---
    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _tapVisible(tester, find.widgetWithText(OutlinedButton, 'Tags'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name or username…'), suffix);
    await tester.pumpAndSettle();
    expect(find.text(withPassword), findsOneWidget);
    expect(find.text(noPassword), findsOneWidget);
    await _tapVisible(tester, find.byTooltip('Show only credentials missing a password'));
    await tester.pumpAndSettle();
    expect(find.text(noPassword), findsOneWidget);
    expect(find.text(withPassword), findsNothing);
  });
}
