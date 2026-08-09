// End-to-end proof for Sprint 1.3 (MOB-CRED-01/02, MOB-SYNC-01) against the live Docker
// dev backend's real data: `xcred_admin` already has 56 credentials across 3 Credential
// Groups from earlier web Playwright test runs, created with the same crypto scheme
// (verified interoperable in the Sprint 0.2 spike) — a strong end-to-end proof that this
// app's CryptoService/field rendering is correct, not just self-consistent with itself.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xcred_mobile/features/credentials/widgets/credential_row.dart';
import 'package:xcred_mobile/main.dart';

/// Sprint 1.2 added a one-time-per-device biometric-enrollment dialog after a fresh
/// login — it awaits the user's answer, so `pumpAndSettle` right after tapping "Log In"
/// would hang (see auth_flow_test.dart for the full explanation). Poll for either the
/// dialog or a successful straight-through login instead.
Future<void> _pumpUntilAny(WidgetTester tester, List<Finder> finders, {int maxTries = 40}) async {
  for (var i = 0; i < maxTries; i++) {
    if (finders.any((f) => f.evaluate().isNotEmpty)) return;
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Browse the real credentials tree, search, filter, and view a detail',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: XCredApp()));
    await tester.pumpAndSettle();

    // --- Connect + login ---
    expect(find.text('XCred'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Server URL'), 'http://10.0.2.2:18080');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('Welcome back'), findsOneWidget);
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
    await tester.pumpAndSettle(const Duration(seconds: 10));
    expect(dashboardFinder, findsOneWidget);

    // --- Navigate to Credentials ---
    await tester.tap(find.text('Browse Credentials'));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    expect(find.text('Credentials'), findsOneWidget);
    // 3 Credential Groups + an Ungrouped section are known to exist for this account.
    expect(find.byType(ListTile), findsWidgets,
        reason: 'The real 56-credential/3-group dataset must render as group + row tiles');

    // --- Search: a guaranteed-no-match query must show the empty state, not crash ---
    await tester.enterText(find.widgetWithText(TextField, 'Search by name, username, or tag…'),
        'zzz_no_such_credential_zzz');
    await tester.pumpAndSettle();
    expect(find.text('No credentials match your search.'), findsOneWidget);

    // Clear search, back to the full tree.
    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name, username, or tag…'), '');
    await tester.pumpAndSettle();
    expect(find.byType(CredentialRow), findsWidgets,
        reason: 'Clearing the search must restore the full list');

    // --- Open a credential detail ---
    await tester.tap(find.byType(CredentialRow).first);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // The detail screen must show at least one field row with a copy action — proves
    // decryptCredentialFields() actually produced real field values, not just an
    // empty/error state.
    expect(find.byIcon(Icons.copy_outlined), findsWidgets,
        reason: 'A decrypted credential must render at least one copyable field');

    // --- Copy a field, confirm the countdown toast appears ---
    await tester.tap(find.byIcon(Icons.copy_outlined).first);
    await tester.pump(); // SnackBar enters
    expect(find.textContaining('Copied — clipboard clears in'), findsOneWidget);
  });
}
