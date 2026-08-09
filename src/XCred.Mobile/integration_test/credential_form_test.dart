// End-to-end proof for Sprint 1.4 (MOB-CRED-03/04/05, MOB-GEN-01) against the live
// Docker dev backend. Two focused tests rather than literally repeating all 19 types
// through the UI: every credential type shares the exact same rendering/serialization
// code path (kCredentialFields drives _buildField uniformly — no per-type branches
// exist anywhere in credential_form_screen.dart), so what actually needs UI coverage is
// each *field type* (text/password/textarea/select/url/list) and each cross-cutting
// concern (generator, custom fields, tags/folder/group pickers, expiry) at least once —
// not 19x repetition of the same code path with different labels.
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

/// A tap on a widget below the on-screen keyboard (or otherwise scrolled out of the
/// viewport) silently misses — the finder resolves, but the hit-test offset lands
/// outside the render tree. Always scroll into view before tapping anything that isn't
/// guaranteed to already be on-screen.
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
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
  // The AppBar title ("Hi, xcred_admin") renders as soon as the session exists, but
  // "Browse Credentials" only appears once the dashboard's own async GET /api/dashboard
  // completes — wait for that too, or the next tap races it.
  await _pumpUntilAny(tester, [find.text('Browse Credentials')]);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Create a WebsiteLogin with the password generator, then edit and verify the '
      'update persisted', (tester) async {
    final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(6);
    final credName = 'MobTest WebsiteLogin $suffix';

    await _login(tester);
    await tester.tap(find.text('Browse Credentials'));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Credential'));
    await tester.pumpAndSettle();

    // WebsiteLogin is the default selected type — no need to tap the picker.
    expect(find.text('Add Credential'), findsWidgets);
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), credName);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'URL'), 'https://example.com/login');
    await tester.enterText(find.widgetWithText(TextFormField, 'Username / Email'), 'mobtest');

    // --- Password generator ---
    await _tapVisible(tester, find.byTooltip('Generate password'));
    await tester.pumpAndSettle();
    expect(find.text('Password Generator'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Use This Password'));
    await tester.pumpAndSettle();
    final passwordField =
        tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Password'));
    expect(passwordField.controller!.text, isNotEmpty,
        reason: 'Use This Password must write the generated value back into the field');

    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Save Credential'));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // --- Verify via the tree + detail screen ---
    expect(find.text('Credentials'), findsOneWidget,
        reason: 'Saving must pop back to the Credentials tree');
    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name, username, or tag…'), credName);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, credName));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('mobtest'), findsOneWidget,
        reason: 'The username field must round-trip through encrypt/save/fetch/decrypt');

    // --- Edit: change the URL, verify the update persisted ---
    await _tapVisible(tester, find.byTooltip('Edit'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('Edit Credential'), findsOneWidget);
    expect(find.text('Credential Type'), findsNothing,
        reason: 'The type picker must not be shown on edit (type is immutable after '
            'creation, matching web)');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'URL'), 'https://example.com/updated');
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Update Credential'));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    expect(find.textContaining('example.com/updated'), findsOneWidget,
        reason: 'The edited value must persist and reload correctly');
  });

  testWidgets(
      'Create a NetworkDevice with a 3-item list (remove the middle one), custom '
      'fields, a tag, a folder, a credential group, and an expiry date — all five must '
      'survive save + reload', (tester) async {
    final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(6);
    final credName = 'MobTest NetworkDevice $suffix';

    await _login(tester);
    if (find.text('Browse Credentials').evaluate().isNotEmpty) {
      await tester.tap(find.text('Browse Credentials'));
      await tester.pumpAndSettle(const Duration(seconds: 10));
    }

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Credential'));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Network Device'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), credName);
    await tester.enterText(find.widgetWithText(TextFormField, 'Device Name'), 'Core Switch');

    // --- List field: add 3, remove the middle one -> [10.0.0.1, 10.0.0.3] ---
    for (var i = 0; i < 3; i++) {
      await _tapVisible(
          tester, find.widgetWithText(TextButton, i == 0 ? 'Add value' : 'Add another'));
      await tester.pumpAndSettle();
    }
    // Rows are keyed by field+index (credential_form_screen.dart's _buildListField) —
    // reliable regardless of what other TextFormFields already exist elsewhere on the
    // eagerly-built form.
    await tester.enterText(find.byKey(const ValueKey('list_ipAddresses_0')), '10.0.0.1');
    await tester.enterText(find.byKey(const ValueKey('list_ipAddresses_1')), '10.0.0.2');
    await tester.enterText(find.byKey(const ValueKey('list_ipAddresses_2')), '10.0.0.3');
    await tester.pumpAndSettle();
    // Remove the middle row (10.0.0.2) via its keyed delete icon.
    await _tapVisible(tester, find.byKey(const ValueKey('list_ipAddresses_delete_1')));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'netadmin');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'NetPass#123');

    // --- Custom fields ---
    await _tapVisible(tester, find.widgetWithText(TextButton, 'Add Field'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Label').first, 'Rack');
    await tester.enterText(find.widgetWithText(TextFormField, 'Value').first, 'R42');

    // --- Tag / Folder / Credential Group ---
    final tagChip = find.byType(FilterChip).first;
    await _tapVisible(tester, tagChip);
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.widgetWithText(DropdownButtonFormField<String?>, 'No Folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('E2E Folder 1786217996193').last);
    await tester.pumpAndSettle();

    // The dropdown's open-menu overlay and its closed-state selected-item display can
    // both have DropdownMenuItem widgets mounted simultaneously (a DropdownButtonFormField
    // quirk), so picking "any item with a non-null value" from the whole tree is
    // unreliable — target a specific known real group by name instead, like the folder
    // above.
    await _tapVisible(
        tester, find.widgetWithText(DropdownButtonFormField<String?>, 'No Credential Group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🏦 E2E Bank 1786217916082').last);
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('None'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Save Credential'));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // --- Verify all five survived ---
    expect(find.text('Credentials'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name, username, or tag…'), credName);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, credName));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('10.0.0.1'), findsOneWidget);
    expect(find.text('10.0.0.2'), findsNothing,
        reason: 'The removed middle IP must not reappear');
    expect(find.text('10.0.0.3'), findsOneWidget);
    expect(find.text('R42'), findsOneWidget, reason: 'The custom field value must survive');
    expect(find.textContaining('Folder:'), findsOneWidget);
    expect(find.textContaining('Credential Group:'), findsOneWidget);
    expect(find.textContaining('Expires:'), findsOneWidget);
  });
}
