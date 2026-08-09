// End-to-end proof for Sprint 1.6 (MOB-ATT-01/02) against the live Docker dev backend.
// Real OS file-picker/share-sheet dialogs are outside what WidgetTester can drive (they
// render outside the Flutter app's own tree), so — the same provider-override seam
// already used for BiometricGate/ApiClient in earlier sprints — [FileExchange] is
// swapped for a fake that returns known bytes on "pick" and records what it's given on
// "save". Everything else (encryption, upload, the real backend, decryption on
// download) is completely real.
//
// The size-limit assertion needs a *non-default* `orgSettings.maxAttachmentSizeMb` —
// same discipline as Sprint 1.3's clipboard-clear test — set via a one-off admin API
// call before this test runs (see the accompanying shell command in session notes);
// this test does not restore it, that's done by the harness driving the test run.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xcred_mobile/core/platform/file_exchange.dart';
import 'package:xcred_mobile/core/providers/core_providers.dart';
import 'package:xcred_mobile/main.dart';

class FakeFileExchange implements FileExchange {
  PickedFileData? nextPick;
  String? savedFilename;
  Uint8List? savedBytes;
  String? savedMimeType;

  @override
  Future<PickedFileData?> pickFile() async => nextPick;

  @override
  Future<void> saveOrShare(String filename, Uint8List bytes, String mimeType) async {
    savedFilename = filename;
    savedBytes = bytes;
    savedMimeType = mimeType;
  }
}

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
      'Upload a file, download it with filename/MIME intact, reject an oversized file '
      'against the real configured limit', (tester) async {
    final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(6);
    final credName = 'MobTest Attachment $suffix';
    final fakeExchange = FakeFileExchange();

    // --- Login ---
    await tester.pumpWidget(ProviderScope(
      overrides: [fileExchangeProvider.overrideWithValue(fakeExchange)],
      child: const XCredApp(),
    ));
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

    // --- Create a throwaway credential to attach files to ---
    await _tapVisible(tester, find.text('Browse Credentials'));
    await tester.pumpAndSettle(const Duration(seconds: 10));
    await _tapVisible(tester, find.widgetWithText(FloatingActionButton, 'Add Credential'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), credName);
    await tester.enterText(find.widgetWithText(TextFormField, 'URL'), 'https://example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Username / Email'), 'x');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'x');
    // Dismiss the keyboard before scrolling to/tapping Save — otherwise ensureVisible's
    // scroll target is computed against the keyboard-open viewport and goes stale once
    // it closes (same bug class hit in folders_tags_groups_test.dart).
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Save Credential'));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name, username, or tag…'), credName);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, credName));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // --- Upload a small "PDF" ---
    final smallBytes = Uint8List.fromList(utf8.encode('%PDF-1.4 fake pdf content for testing'));
    fakeExchange.nextPick = PickedFileData(
      name: 'test-document.pdf',
      bytes: smallBytes,
      mimeType: 'application/pdf',
    );
    await _tapVisible(tester, find.widgetWithText(TextButton, 'Add File'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('test-document.pdf'), findsOneWidget,
        reason: 'The uploaded attachment must appear with its decrypted original filename');

    // --- Download it, confirm filename/MIME/bytes round-tripped exactly ---
    await _tapVisible(tester, find.byTooltip('Download'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(fakeExchange.savedFilename, 'test-document.pdf',
        reason: 'MOB-ATT-02: the original filename must survive encrypt/upload/'
            'download/decrypt — this is the exact bug fixed in the web app earlier in '
            'this project, must not be reintroduced on mobile');
    expect(fakeExchange.savedMimeType, 'application/pdf',
        reason: 'The original MIME type must survive too, or the OS won\'t recognize '
            'the file type on open');
    expect(fakeExchange.savedBytes, smallBytes,
        reason: 'The file content itself must round-trip byte-for-byte');

    // --- Attempt to upload an oversized file against the real configured limit ---
    // (backend's orgSettings.maxAttachmentSizeMb set to 1 MB before this test run —
    // see the file header comment)
    final oversizedBytes = Uint8List(2 * 1024 * 1024); // 2 MB, over the 1 MB test limit
    fakeExchange.nextPick = PickedFileData(
      name: 'too-big.bin',
      bytes: oversizedBytes,
      mimeType: 'application/octet-stream',
    );
    await _tapVisible(tester, find.widgetWithText(TextButton, 'Add File'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.textContaining('Maximum size is 1 MB'), findsOneWidget,
        reason: 'The rejection message must show the real configured limit (1 MB, set '
            'for this test), not a hardcoded default like 10 MB');
    expect(find.text('too-big.bin'), findsNothing,
        reason: 'An oversized file must never actually be uploaded');
    expect(find.text('Attachments (1)'), findsOneWidget,
        reason: 'The attachment count must still show only the one valid upload');

    // --- Delete the attachment (with its confirmation dialog), confirm it's gone ---
    await _tapVisible(tester, find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Attachment?'), findsOneWidget);
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('test-document.pdf'), findsNothing);
    expect(find.text('No attachments yet. Files are encrypted before upload.'),
        findsOneWidget);
  });
}
