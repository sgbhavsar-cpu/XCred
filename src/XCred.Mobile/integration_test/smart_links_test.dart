// End-to-end proof for Sprint 3.1 (MOB-LINK-01) against the live Docker dev backend.
// Before this sprint, openSmartLink had zero test coverage and no failure handling —
// tapping an ssh:/rdp: link with no registered handler app on the device either did
// nothing visible or (depending on platform behavior) could throw uncaught. The sprint's
// own test-case wording is "ssh:/rdp: links degrade gracefully (no crash) when no
// handler app is installed" — this is exactly that case: a fresh Android emulator has no
// app registered for the ssh: scheme, so tapping the SSH Key credential's "Open" action
// must show the new fallback SnackBar rather than crash or silently no-op.
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

Future<void> _login(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: XCredApp()));
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
  expect(dashboardFinder, findsOneWidget);
  await _pumpUntilAny(tester, [find.text('Browse Credentials')]);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'MOB-LINK-01: tapping an ssh: link with no registered handler app shows a '
      "fallback SnackBar instead of crashing or silently doing nothing", (tester) async {
    final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(6);
    final credName = 'MobTest SshKey $suffix';

    await _login(tester);
    await tester.tap(find.text('Browse Credentials'));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Credential'));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('SSH Key'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), credName);
    // host/username are optional fields for SshKey (credential_fields.dart) — optional
    // fields get ' (optional)' appended to their rendered label
    // (credential_form_screen.dart's _buildField).
    await tester.enterText(find.widgetWithText(TextFormField, 'Host / Server (optional)'),
        'no-handler-host.example.com');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username (optional)'), 'sshuser');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Private Key'), '-----BEGIN KEY-----dummy-----END KEY-----');
    await _dismissKeyboard(tester);

    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Save Credential'));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    expect(find.text('Credentials'), findsOneWidget,
        reason: 'Saving must pop back to the Credentials tree');
    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name, username, or tag…'), credName);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, credName));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // The Host / Server field is the only one on this credential type with an "Open"
    // action (linkType: 'ssh') — its tooltip comes straight from smart_links.dart's
    // linkTooltip, which also doubles as a11y coverage for MOB-A11Y-01.
    final openButtonFinder = find.byTooltip(
        'Open with your registered SSH handler, if one is configured — otherwise '
        'nothing will happen');
    expect(openButtonFinder, findsOneWidget,
        reason: 'The Host / Server field must render an Open action for its ssh: link');

    await _tapVisible(tester, openButtonFinder);
    // No spinner covers this action; launchUrl's failure path resolves asynchronously —
    // poll for the fallback SnackBar rather than asserting immediately.
    final fallbackSnackBarFinder = find.text('No app installed that can open this link.');
    await _pumpUntilAny(tester, [fallbackSnackBarFinder]);
    expect(fallbackSnackBarFinder, findsOneWidget,
        reason: 'MOB-LINK-01: a device with no registered ssh: handler must surface a '
            'visible fallback instead of crashing or silently doing nothing');

    // The app must still be alive and responsive afterwards — the whole point of this
    // test is proving the tap does not crash the app.
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text(credName), findsWidgets,
        reason: 'The credential detail screen must still be intact after the failed '
            'launch attempt');
  });
}
