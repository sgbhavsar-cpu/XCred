import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xcred_mobile/core/widgets/clearable_search_field.dart';
import 'package:xcred_mobile/core/widgets/option_picker.dart';
import 'package:xcred_mobile/core/widgets/picker_field.dart';

List<PickOption<String?>> _opts(int n) =>
    [for (var i = 0; i < n; i++) PickOption<String?>(value: 'v$i', label: 'Item $i')];

Future<void> _host(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child))));

void main() {
  testWidgets('no search box up to 5 options, a search box beyond that', (tester) async {
    for (final (n, expectSearch) in [(5, false), (6, true)]) {
      late String? picked;
      await _host(
        tester,
        PickerField<String?>(label: 'Pick', value: null, options: _opts(n), onChanged: (v) => picked = v),
      );
      await tester.tap(find.byType(PickerField<String?>));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('picker_search')), expectSearch ? findsOneWidget : findsNothing,
          reason: '$n options');
      await tester.tap(find.text('Item 1'));
      await tester.pumpAndSettle();
      expect(picked, 'v1');
    }
  });

  testWidgets('search filters ignoring punctuation and case, and the X clears it', (tester) async {
    await _host(
      tester,
      PickerField<String?>(
        label: 'Type',
        value: null,
        options: [
          const PickOption<String?>(value: 'wifi', label: 'Wi-Fi'),
          const PickOption<String?>(value: 'rdp', label: 'Remote Desktop (RDP)'),
          for (var i = 0; i < 6; i++) PickOption<String?>(value: 'x$i', label: 'Other $i'),
        ],
        onChanged: (_) {},
      ),
    );
    await tester.tap(find.byType(PickerField<String?>));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('picker_search')), 'WIFI');
    await tester.pump();
    expect(find.text('Wi-Fi'), findsOneWidget);
    expect(find.text('Other 0'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('picker_search')), 'rdp');
    await tester.pump();
    expect(find.text('Remote Desktop (RDP)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('picker_search_clear')));
    await tester.pump();
    expect(find.text('Other 0'), findsOneWidget);
    expect(find.byKey(const ValueKey('picker_search_clear')), findsNothing);
  });

  testWidgets('long lists are capped at 6 rows and scroll', (tester) async {
    await _host(
      tester,
      PickerField<String?>(label: 'Many', value: null, options: _opts(40), onChanged: (_) {}),
    );
    await tester.tap(find.byType(PickerField<String?>));
    await tester.pumpAndSettle();
    final height = tester.getSize(find.byKey(const ValueKey('picker_list'))).height;
    expect(height, lessThanOrEqualTo(52.0 * kPickerVisibleRows));
    expect(find.text('Item 39'), findsNothing); // off-screen until scrolled
    await tester.drag(find.byKey(const ValueKey('picker_list')), const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(find.text('Item 39'), findsOneWidget);
  });

  testWidgets('choosing the null option ("No folder") is distinguishable from dismissing', (tester) async {
    String? value = 'v1';
    var calls = 0;
    await _host(
      tester,
      StatefulBuilder(
        builder: (context, setState) => PickerField<String?>(
          label: 'Folder',
          value: value,
          options: [const PickOption<String?>(value: null, label: 'No Folder'), ..._opts(2)],
          onChanged: (v) => setState(() {
            value = v;
            calls++;
          }),
        ),
      ),
    );
    await tester.tap(find.byType(PickerField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No Folder'));
    await tester.pumpAndSettle();
    expect(value, isNull);
    expect(calls, 1);

    // dismissing (close button) leaves the value alone
    await tester.tap(find.byType(PickerField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('the "+" next to the field creates a record and selects it without opening the list', (tester) async {
    String? value;
    var created = 0;
    await _host(
      tester,
      StatefulBuilder(
        builder: (context, setState) => PickerField<String?>(
          label: 'Folder',
          value: value,
          options: _opts(2),
          onChanged: (v) => setState(() => value = v),
          onCreate: () async {
            created++;
            return 'new-id';
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('picker_field_create')));
    await tester.pumpAndSettle();
    expect(created, 1);
    expect(value, 'new-id');
    expect(find.byKey(const ValueKey('picker_list')), findsNothing);
  });

  testWidgets('"+ New" inside the open list creates, picks and closes', (tester) async {
    String? value;
    await _host(
      tester,
      StatefulBuilder(
        builder: (context, setState) => PickerField<String?>(
          label: 'Folder',
          value: value,
          options: _opts(2),
          onChanged: (v) => setState(() => value = v),
          onCreate: () async => 'made-here',
        ),
      ),
    );
    await tester.tap(find.byType(PickerField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('picker_create')));
    await tester.pumpAndSettle();
    expect(value, 'made-here');
    expect(find.byKey(const ValueKey('picker_list')), findsNothing);
  });

  testWidgets('search field shows an X only when it has text, and X clears + notifies', (tester) async {
    final controller = TextEditingController();
    var latest = 'unset';
    await _host(tester, ClearableSearchField(controller: controller, onChanged: (v) => latest = v));
    expect(find.byKey(const ValueKey('search_clear')), findsNothing);

    await tester.enterText(find.byType(TextField), 'router');
    await tester.pump();
    expect(latest, 'router');
    expect(find.byKey(const ValueKey('search_clear')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('search_clear')));
    await tester.pump();
    expect(controller.text, '');
    expect(latest, '');
    expect(find.byKey(const ValueKey('search_clear')), findsNothing);
  });
}
