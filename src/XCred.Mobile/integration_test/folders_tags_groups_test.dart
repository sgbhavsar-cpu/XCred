// End-to-end proof for Sprint 1.5 (MOB-CGRP-01/MOB-FOLD-01/MOB-TAG-01) against the live
// Docker dev backend: create a fresh Credential Group + Folder + Tag, assign one
// credential to all three, then delete each one in turn and confirm the credential
// survives with that association cleared — the core "unlink, don't cascade-delete"
// acceptance criterion shared by all three entities.
//
// Deliberately creates its own throwaway fixtures rather than reusing the account's
// existing "E2E ..." seed data from earlier web testing — this test is destructive
// (delete flows), and the seed data may still be relied on by re-runs of earlier
// sprints' tests.
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Create a group/folder/tag, assign one credential to all three, delete each — '
      'the credential survives, unlinked each time', (tester) async {
    final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(6);
    final groupName = 'MobTest Group $suffix';
    final folderName = 'MobTest Folder $suffix';
    final tagName = 'MobTest Tag $suffix';
    final credName = 'MobTest SecureNote $suffix';

    // --- Login ---
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
    await _pumpUntilAny(tester, [find.text('Browse Credentials')]);

    // --- Create Credential Group ---
    await _tapVisible(tester, find.text('Browse Credentials'));
    await tester.pumpAndSettle(const Duration(seconds: 10));
    await _tapVisible(tester, find.byTooltip('New Credential Group'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, groupName);
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text(groupName), findsOneWidget);

    // --- Create Folder ---
    // Navigate back to Dashboard, then into Folders.
    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _tapVisible(tester, find.widgetWithText(OutlinedButton, 'Folders'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await _tapVisible(tester, find.widgetWithText(FloatingActionButton, 'New Folder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Folder name'), folderName);
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text(folderName), findsOneWidget);

    // --- Create Tag ---
    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _tapVisible(tester, find.widgetWithText(OutlinedButton, 'Tags'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await _tapVisible(tester, find.widgetWithText(FloatingActionButton, 'New Tag'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Tag name'), tagName);
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text(tagName), findsOneWidget);

    // --- Create a credential assigned to all three ---
    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Browse Credentials'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await _tapVisible(tester, find.widgetWithText(FloatingActionButton, 'Add Credential'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Secure Note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), credName);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Note Content'), 'irrelevant body');
    // The multi-line Note Content field leaves the on-screen keyboard open; dismiss it
    // before scrolling to later widgets, or the viewport resizes *after* ensureVisible
    // computed a scroll target, leaving the tap aimed at a now-stale position.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Tap the FilterChip itself, not its inner Text — the text glyphs' own hit-test
    // region can land on an overlapping layer and silently miss (same class of bug as
    // Sprint 1.1's off-screen-tap issue, just via a different mechanism).
    await _tapVisible(tester, find.widgetWithText(FilterChip, tagName));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.widgetWithText(DropdownButtonFormField<String?>, 'No Folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(folderName).last);
    await tester.pumpAndSettle();
    await _tapVisible(
        tester, find.widgetWithText(DropdownButtonFormField<String?>, 'No Credential Group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🏦 $groupName').last);
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Save Credential'));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // --- Verify the credential shows all three associations ---
    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name, username, or tag…'), credName);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, credName));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.textContaining('Folder:'), findsOneWidget);
    expect(find.textContaining('Credential Group:'), findsOneWidget);
    expect(find.text(tagName), findsOneWidget);

    // --- Delete the folder -> credential survives, folder unlinked ---
    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _tapVisible(tester, find.widgetWithText(OutlinedButton, 'Folders'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await _tapVisible(
        tester,
        find.descendant(
            of: find.ancestor(of: find.text(folderName), matching: find.byType(ListTile)),
            matching: find.byTooltip('Delete')));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text(folderName), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Browse Credentials'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name, username, or tag…'), credName);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, credName));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.textContaining('Folder:'), findsNothing,
        reason: 'Deleting the folder must unlink the credential, not delete it');
    expect(find.textContaining('Credential Group:'), findsOneWidget,
        reason: 'The group association must be unaffected by the folder deletion');

    // --- Delete the tag -> credential survives, tag removed ---
    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _tapVisible(tester, find.widgetWithText(OutlinedButton, 'Tags'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await _tapVisible(
        tester,
        find.descendant(
            of: find.ancestor(of: find.text(tagName), matching: find.byType(ListTile)),
            matching: find.byTooltip('Delete')));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text(tagName), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Browse Credentials'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name, username, or tag…'), credName);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, credName));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text(tagName), findsNothing,
        reason: 'Deleting the tag must remove it from the credential, not delete the '
            'credential');
    expect(find.textContaining('Credential Group:'), findsOneWidget);

    // --- Delete the credential group (from the tree row) -> credential survives ---
    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name, username, or tag…'), '');
    await tester.pumpAndSettle();
    await _tapVisible(
        tester,
        find.descendant(
            of: find.ancestor(of: find.text(groupName), matching: find.byType(ListTile)),
            matching: find.byTooltip('Delete group')));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text(groupName), findsNothing);

    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name, username, or tag…'), credName);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, credName));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.textContaining('Credential Group:'), findsNothing,
        reason: 'Deleting the group must unlink the credential, not delete it — the '
            'credential itself must still open and decrypt correctly');
    expect(find.text(credName), findsWidgets,
        reason: 'The credential must still exist and be viewable after all three '
            'associations were removed');
  });
}
