// End-to-end proof for Sprint 2.4 (MOB-ADMIN-01/02/03) against the live Docker dev
// backend. The audit log's explicit sprint test cases — filtering actually changes the
// results, and paginating past page 1 actually loads different results — are proven
// against this session's real accumulated history (many hundreds of prior actions
// across every earlier sprint's test runs), which is exactly why they're meaningful
// here: the web app's equivalent screen never wires these at all (always page 1 of 50,
// no filters), so there's no shortcut of "reuse what web already proved works."
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

/// pumpAndSettle only waits for scheduled frames/animations to stop — an in-flight
/// async network call with no visible spinner doesn't keep it waiting, so a bare
/// pumpAndSettle right after a tap can return before the request (and the refresh it
/// triggers) has actually finished. Poll for the real outcome instead.
Future<void> _pumpUntilGone(WidgetTester tester, Finder finder, {int maxTries = 40}) async {
  for (var i = 0; i < maxTries; i++) {
    if (finder.evaluate().isEmpty) return;
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Admin approves a pending user, changes their role and activation state, and the '
      'Audit Log tab\'s action filter and pagination both actually reach the server',
      (tester) async {
    final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(6);
    final memberUsername = 'admintest_$suffix';
    final memberEmail = 'admintest_$suffix@example.com';
    const memberLoginPassword = 'AdminTestLogin#2026';
    const memberMasterPassword = 'AdminTestMaster#2026!!';
    const adminUsername = 'xcred_admin';
    const adminLoginPassword = 'LoginPassword#2026';
    const adminMasterPassword = 'Admin@#1234%^&*()';

    await tester.pumpWidget(const ProviderScope(child: XCredApp()));
    await tester.pumpAndSettle();

    // --- Register the throwaway account (left pending — approved via the Admin UI
    // itself below, not a raw API call, so MOB-ADMIN-02's Approve action is genuinely
    // exercised) ---
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

    // ============================================================
    // Log in as admin, open the Admin Panel
    // ============================================================
    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), adminUsername);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Login password'), adminLoginPassword);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Master password'), adminMasterPassword);
    await tester.tap(find.text('Log In'));
    final adminDashboardFinder = find.textContaining('Hi, $adminUsername');
    final enrollDialogFinder = find.text('Enable Quick Unlock?');
    await _pumpUntilAny(tester, [adminDashboardFinder, enrollDialogFinder]);
    if (enrollDialogFinder.evaluate().isNotEmpty) {
      await tester.tap(find.widgetWithText(TextButton, 'Not Now'));
    }
    await _pumpUntilAny(tester, [adminDashboardFinder]);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await _tapVisible(tester, find.byTooltip('Settings'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await _tapVisible(tester, find.widgetWithText(OutlinedButton, 'Admin Panel'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // ============================================================
    // Pending tab: approve the throwaway user through the real UI
    // ============================================================
    // find.text('Pending') would also match the Users tab's "Pending" status pill on
    // the not-yet-approved account's own row — scope to the actual Tab widget.
    await _tapVisible(tester, find.widgetWithText(Tab, 'Pending'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final pendingRowFinder = find.widgetWithText(Card, memberUsername);
    await _pumpUntilAny(tester, [pendingRowFinder]);
    expect(pendingRowFinder, findsOneWidget,
        reason: 'MOB-ADMIN-02: the newly registered account must appear pending approval');
    await _tapVisible(
        tester, find.descendant(of: pendingRowFinder, matching: find.widgetWithText(FilledButton, 'Approve')));
    final approvedCardFinder = find.widgetWithText(Card, memberUsername);
    await _pumpUntilGone(tester, approvedCardFinder);
    expect(approvedCardFinder, findsNothing,
        reason: 'MOB-ADMIN-02: an approved user must disappear from Pending');

    // ============================================================
    // Users tab: role change and deactivate/activate, both round-tripping the server
    // ============================================================
    await _tapVisible(tester, find.widgetWithText(Tab, 'Users'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // This session has accumulated many throwaway accounts across every earlier
    // sprint's tests (~30 by now) — GetUsers sorts pending-first then approved
    // alphabetically, so the target (now approved) user can easily be scrolled well
    // past ListView.builder's lazily-built viewport window. Scroll to it explicitly
    // rather than assuming it's already built (same "off-screen, not just present but
    // unfound" class of issue as the Sliver-backed ListView(children:) bug documented
    // in credential_form_screen.dart, just triggered by list length here instead).
    // find.byType(Scrollable) matches both TabBarView's own PageView *and* the list
    // inside the current tab — .last targets the innermost (the list), not the tab
    // pager itself.
    final userCardFinder = find.widgetWithText(Card, memberUsername);
    await tester.scrollUntilVisible(userCardFinder, 300, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    expect(userCardFinder, findsOneWidget,
        reason: 'The just-approved user must now appear in the Users list');
    expect(
        find.descendant(
            of: userCardFinder, matching: find.widgetWithText(DropdownButtonFormField<String>, 'User')),
        findsOneWidget,
        reason: 'A newly approved user must start with the User role');

    await _tapVisible(tester,
        find.descendant(of: userCardFinder, matching: find.byType(DropdownButtonFormField<String>)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admin').last);
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Change'));
    // No spinner/animation covers this action (just a disabled button), so a bare
    // pumpAndSettle can return before the setRole call + refresh actually finish —
    // poll for the real outcome instead (same fix as the Pending-tab approve above).
    final adminRoleFinder = find.descendant(
        of: find.widgetWithText(Card, memberUsername),
        matching:
            find.byWidgetPredicate((w) => w is DropdownButtonFormField<String> && w.initialValue == 'Admin'));
    await _pumpUntilAny(tester, [adminRoleFinder]);
    expect(adminRoleFinder, findsOneWidget,
        reason: 'MOB-ADMIN-01: the role change must actually reach the server — this '
            'reload fetches live, not from any cache');

    final refreshedCardFinder = find.widgetWithText(Card, memberUsername);
    await _tapVisible(
        tester, find.descendant(of: refreshedCardFinder, matching: find.widgetWithText(OutlinedButton, 'Deactivate')));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Deactivate'));
    final activateButtonFinder = find.descendant(
        of: find.widgetWithText(Card, memberUsername),
        matching: find.widgetWithText(OutlinedButton, 'Activate'));
    await _pumpUntilAny(tester, [activateButtonFinder]);
    expect(activateButtonFinder, findsOneWidget,
        reason: 'MOB-ADMIN-01: deactivating must flip the button to Activate and (via '
            'the status pill) show Inactive');

    // ============================================================
    // Audit Log tab: the action filter and pagination must reach the server
    // ============================================================
    await _tapVisible(tester, find.widgetWithText(Tab, 'Audit Log'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await _tapVisible(
        tester, find.widgetWithText(DropdownButtonFormField<String?>, 'Any action'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LoginSuccess').last);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final auditTiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(auditTiles, isNotEmpty, reason: 'This session has logged in many times.');
    for (final tile in auditTiles) {
      final titleText = (tile.title! as Text).data;
      expect(titleText, 'LoginSuccess',
          reason: 'MOB-ADMIN-03: every visible row must match the selected action '
              'filter — it must actually be applied server-side, not just present in '
              'the UI with no effect (the exact gap the web app has)');
    }

    final firstEntryBeforePaging = (auditTiles.first.subtitle! as Text).data;
    final nextPageButton =
        find.ancestor(of: find.byIcon(Icons.chevron_right), matching: find.byType(IconButton));
    final canPaginate = tester.widget<IconButton>(nextPageButton).onPressed != null;
    expect(canPaginate, isTrue,
        reason: 'This session has generated far more than one page of LoginSuccess '
            'events — Next must be enabled');
    await _tapVisible(tester, nextPageButton);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.textContaining('Page 2 of'), findsOneWidget,
        reason: 'MOB-ADMIN-03: the page number must actually reach the API and change '
            'which page is displayed');
    final auditTilesPage2 = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(auditTilesPage2, isNotEmpty);
    final firstEntryAfterPaging = (auditTilesPage2.first.subtitle! as Text).data;
    expect(firstEntryAfterPaging, isNot(firstEntryBeforePaging),
        reason: 'MOB-ADMIN-03: page 2 must show genuinely different results, proving '
            'the page param reached the API rather than the UI silently re-showing '
            'page 1 (the exact gap the web app has)');
  });
}
