import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xcred_mobile/core/models/folder_tag_models.dart';
import 'package:xcred_mobile/core/providers/vault_providers.dart';
import 'package:xcred_mobile/features/credentials/widgets/bulk_assign_sheet.dart';

class _FakeTags extends TagListNotifier {
  @override
  Future<List<TagSummary>> build() async => const [
        TagSummary(id: 't1', name: 'Production', color: '#ef4444', credentialCount: 0),
        TagSummary(id: 't2', name: 'Office', color: '#6366f1', credentialCount: 0),
      ];
}

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [tagListProvider.overrideWith(_FakeTags.new)],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showBulkAssignSheet(context, credentialIds: const ['a', 'b'], onApplied: () {}),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

FilledButton _apply(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply'));

void main() {
  testWidgets('starts with nothing to apply and lists every bulk section', (tester) async {
    await _open(tester);
    expect(find.text('Bulk edit 2 credentials'), findsOneWidget);
    for (final section in ['Folder', 'Credential Group', 'Tags', 'Expiry date', 'Notes', 'Custom fields']) {
      expect(find.text(section), findsOneWidget, reason: section);
    }
    expect(_apply(tester).onPressed, isNull);
  });

  testWidgets('tapping a tag chip enables Apply; a third tap disables it again', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Production'));
    await tester.pump();
    expect(_apply(tester).onPressed, isNotNull); // add
    await tester.tap(find.text('Production'));
    await tester.pump();
    expect(_apply(tester).onPressed, isNotNull); // remove
    await tester.tap(find.text('Production'));
    await tester.pump();
    expect(_apply(tester).onPressed, isNull); // back to untouched
  });

  testWidgets('"Add change" adds a custom-field row, but a blank label alone is not a change', (tester) async {
    await _open(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('bulk_add_field')));
    await tester.tap(find.byKey(const ValueKey('bulk_add_field')));
    await tester.pump();
    expect(find.byKey(const ValueKey('bulk_field_0')), findsOneWidget);
    expect(_apply(tester).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Label'), 'Owner');
    await tester.pump();
    expect(_apply(tester).onPressed, isNotNull);
  });
}
