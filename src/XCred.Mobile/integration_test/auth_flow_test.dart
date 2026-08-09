// End-to-end proof for Sprint 1.1 (MOB-SRV-01/MOB-AUTH-01/MOB-AUTH-02): drives the real
// app UI — not a mocked layer — against the live Docker dev backend (docker-compose.yml,
// reachable from the Android emulator at 10.0.2.2:18080, its alias for the host's
// localhost:18080). This is the mobile equivalent of the web app's Playwright e2e suite.
//
// Split into two flows because the dev DB already has an approved admin user from earlier
// web e2e runs (docs/Requirements — `xcred_admin` / `LoginPassword#2026` login password /
// `Admin@#1234%^&*()` master password, confirmed live against this exact backend before
// writing this test): a freshly-registered user here is never the first user, so it lands
// in "awaiting approval", not an active session.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xcred_mobile/main.dart';

/// Sprint 1.2 added a one-time-per-device biometric-enrollment dialog after a fresh
/// login (MOB-SESS-01) — it awaits the user's answer, so `pumpAndSettle` right after
/// tapping "Log In" would hang forever (the button's spinner keeps animating until the
/// dialog is answered, but nothing answers it until `pumpAndSettle` returns). Poll for
/// either outcome, then dismiss the dialog if it showed up — this test isn't about
/// enrollment, see session_lifecycle_test.dart for that.
Future<void> _pumpUntilAny(WidgetTester tester, List<Finder> finders,
    {int maxTries = 40}) async {
  for (var i = 0; i < maxTries; i++) {
    if (finders.any((f) => f.evaluate().isNotEmpty)) return;
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// The server URL persists in drift across app launches, so within one test binary run
/// (both `testWidgets` blocks share the same on-device SQLite file) the second test's
/// fresh `pumpWidget` lands directly on /login, skipping /setup entirely — this is
/// correct app behavior (architecture.md §3.2's redirect guard), not something to work
/// around by resetting state; the helper just needs to tolerate either starting point.
Future<void> _connectToServer(WidgetTester tester) async {
  if (find.text('Welcome back').evaluate().isNotEmpty) return;
  expect(find.text('XCred'), findsOneWidget);
  final urlField = find.widgetWithText(TextField, 'Server URL');
  await tester.enterText(urlField, 'http://10.0.2.2:18080');
  await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
  await tester.pumpAndSettle(const Duration(seconds: 5));
  expect(find.text('Welcome back'), findsOneWidget);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Register a new user client-side and reach the pending-approval message',
      (tester) async {
    final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(6);
    final username = 'mobtest$suffix';
    final email = 'mobtest$suffix@example.com';
    const loginPassword = 'LoginPassword#2026';
    const masterPassword = 'Admin@#1234%^&*()';

    await tester.pumpWidget(const ProviderScope(child: XCredApp()));
    await tester.pumpAndSettle();
    await _connectToServer(tester);

    await tester.tap(find.text("Don't have an account? Register"));
    await tester.pumpAndSettle();

    expect(find.text('Create Account'), findsWidgets); // AppBar title + submit button
    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), username);
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Login password'), loginPassword);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm login password'), loginPassword);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Master password'), masterPassword);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm master password'), masterPassword);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    // The submit button sits below the on-screen keyboard once every field has been
    // focused — scroll it into view before tapping, or the tap silently hits whatever
    // is actually at that now-stale offset instead of the button.
    final submitButton = find.widgetWithText(FilledButton, 'Create Account');
    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(submitButton);
    // Registration derives PBKDF2 (600k) + generates an RSA-2048 keypair on-device —
    // give it real headroom (measured ~3.3s for PBKDF2 alone in pbkdf2_perf_test.dart).
    await tester.pumpAndSettle(const Duration(seconds: 15));

    expect(find.textContaining('Awaiting admin approval'), findsOneWidget,
        reason: 'A non-first registration must round-trip through the real backend and '
            'land in the pending-approval state, proving the full client-side crypto + '
            'API payload (publicKey/encryptedPrivateKey/privateKeyIv/keyDerivationSalt) '
            'was accepted');
  });

  testWidgets('Log in with an existing approved account and reach the dashboard',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: XCredApp()));
    await tester.pumpAndSettle();
    await _connectToServer(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'xcred_admin');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Login password'), 'LoginPassword#2026');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Master password'), 'Admin@#1234%^&*()');
    await tester.tap(find.text('Log In'));
    final dashboardFinder = find.textContaining('Hi, xcred_admin');
    final enrollDialogFinder = find.text('Enable Quick Unlock?');
    await _pumpUntilAny(tester, [dashboardFinder, enrollDialogFinder]);
    if (enrollDialogFinder.evaluate().isNotEmpty) {
      await tester.tap(find.widgetWithText(TextButton, 'Not Now'));
    }
    await tester.pumpAndSettle(const Duration(seconds: 15));

    // Reaching the dashboard proves: server accepted the login password, the derived
    // PBKDF2 key decrypted the real encryptedPrivateKey (master password correct), and
    // the resulting JWT was attached and accepted by an authenticated GET /api/dashboard.
    expect(find.textContaining('Hi, xcred_admin'), findsOneWidget,
        reason: 'Login must derive the correct key, decrypt the private key, and reach '
            'the dashboard with a valid JWT attached');
    expect(find.text('Credentials'), findsOneWidget);
    expect(find.text('Shared With Me'), findsOneWidget);
    expect(find.text('Teams'), findsOneWidget);
  });
}
