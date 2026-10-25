import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xcred_mobile/core/providers/core_providers.dart';
import 'package:xcred_mobile/core/providers/server_providers.dart';
import 'package:xcred_mobile/features/setup/servers_sheet.dart';

class _ActiveUrl extends ServerBaseUrlNotifier {
  _ActiveUrl(this.url);
  final String? url;
  @override
  Future<String?> build() async => url;
}

ProviderContainer _container({String? active, Map<String, String> stored = const {}, bool reachable = true}) {
  FlutterSecureStorage.setMockInitialValues(Map.of(stored));
  final c = ProviderContainer(overrides: [
    serverBaseUrlProvider.overrideWith(() => _ActiveUrl(active)),
    serverCheckProvider.overrideWithValue((_) async => reachable),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('URL helpers', () {
    test('normalize trims whitespace and trailing slashes', () {
      expect(normalizeServerUrl('  https://a.example.com//  '), 'https://a.example.com');
    });

    test('validation asks for http(s) and a host', () {
      expect(validateServerUrl(''), isNotNull);
      expect(validateServerUrl('vault.example.com'), isNotNull);
      expect(validateServerUrl('ftp://x.com'), isNotNull);
      expect(validateServerUrl('https://'), isNotNull);
      expect(validateServerUrl('https://vault.example.com/'), isNull);
      expect(validateServerUrl('http://10.0.2.2:1507'), isNull);
    });

    test('default name is the host', () {
      expect(defaultServerName('https://vault.example.com:1976/xcred'), 'vault.example.com');
    });
  });

  group('SavedServersNotifier', () {
    test("an existing install's active server is folded into the list", () async {
      final c = _container(active: 'https://old.example.com');
      final list = await c.read(savedServersProvider.future);
      expect(list.map((s) => s.url), ['https://old.example.com']);
      expect(list.single.name, 'old.example.com');
    });

    test('add, rename (same URL does not duplicate), edit URL and remove', () async {
      final c = _container();
      final n = c.read(savedServersProvider.notifier);
      await c.read(savedServersProvider.future);

      final office = await n.upsert(name: 'Office', url: 'https://office.example.com/');
      await n.upsert(name: 'Home', url: 'http://192.168.1.5:1507');
      expect(c.read(savedServersProvider).value!.map((s) => s.name), ['Office', 'Home']);
      expect(office.url, 'https://office.example.com'); // normalized

      await n.upsert(name: 'HQ', url: 'https://office.example.com'); // same address: rename
      expect(c.read(savedServersProvider).value!.map((s) => s.name), ['HQ', 'Home']);

      await n.upsert(id: office.id, name: 'HQ', url: 'https://hq.example.com'); // edit by id
      expect(c.read(savedServersProvider).value!.first.url, 'https://hq.example.com');

      await n.remove(office.id);
      expect(c.read(savedServersProvider).value!.map((s) => s.name), ['Home']);
    });

    test('a blank name falls back to the host', () async {
      final c = _container();
      await c.read(savedServersProvider.future);
      final s = await c.read(savedServersProvider.notifier).upsert(name: '  ', url: 'https://x.example.com');
      expect(s.name, 'x.example.com');
    });

    test('the list survives a restart (read back from secure storage)', () async {
      final c1 = _container();
      await c1.read(savedServersProvider.future);
      await c1.read(savedServersProvider.notifier).upsert(name: 'Office', url: 'https://office.example.com');
      final saved = await const FlutterSecureStorage().read(key: SavedServersNotifier.storageKey);

      final c2 = _container(stored: {SavedServersNotifier.storageKey: saved!});
      final list = await c2.read(savedServersProvider.future);
      expect(list.map((s) => '${s.name}|${s.url}'), ['Office|https://office.example.com']);
    });

    test('a corrupt stored list is ignored rather than crashing', () async {
      final c = _container(active: 'https://a.example.com', stored: {SavedServersNotifier.storageKey: '{nope'});
      final list = await c.read(savedServersProvider.future);
      expect(list.map((s) => s.url), ['https://a.example.com']);
    });

    test('activeServerProvider maps the active URL to its friendly name', () async {
      final c = _container(active: 'https://office.example.com');
      await c.read(savedServersProvider.future);
      await c.read(savedServersProvider.notifier).upsert(name: 'Office', url: 'https://office.example.com');
      expect(c.read(activeServerProvider)?.name, 'Office');
    });
  });

  group('server dialog and list', () {
    Future<void> pump(WidgetTester tester, ProviderContainer c, Widget body) async {
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: body))),
      ));
      await tester.pumpAndSettle();
    }

    Widget openDialogButton() => Consumer(
        builder: (context, ref, _) =>
            TextButton(onPressed: () => showServerEditDialog(context, ref), child: const Text('open')));

    testWidgets('lists saved servers with the active one marked', (tester) async {
      final c = _container(active: 'https://office.example.com');
      await c.read(savedServersProvider.future);
      await c.read(savedServersProvider.notifier).upsert(name: 'Office', url: 'https://office.example.com');
      await c.read(savedServersProvider.notifier).upsert(name: 'Home lab', url: 'http://192.168.1.5:1507');
      await pump(tester, c, const SavedServersList());

      expect(find.text('Office'), findsOneWidget);
      expect(find.text('https://office.example.com'), findsOneWidget);
      expect(find.text('Home lab'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_off), findsOneWidget);
    });

    testWidgets('the add dialog saves a reachable server', (tester) async {
      final c = _container();
      await c.read(savedServersProvider.future);
      await pump(tester, c, openDialogButton());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('server_name')), 'Office');
      await tester.enterText(find.byKey(const ValueKey('server_url')), 'https://office.example.com');
      await tester.tap(find.byKey(const ValueKey('server_save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('server_url')), findsNothing); // dialog closed
      expect(c.read(savedServersProvider).value!.single.name, 'Office');
    });

    testWidgets('the add dialog refuses a bad URL and an unreachable server, saving nothing', (tester) async {
      final c = _container(reachable: false);
      await c.read(savedServersProvider.future);
      await pump(tester, c, openDialogButton());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('server_url')), 'office.example.com');
      await tester.tap(find.byKey(const ValueKey('server_save')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Start with http'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('server_url')), 'https://office.example.com');
      await tester.tap(find.byKey(const ValueKey('server_save')));
      await tester.pumpAndSettle();
      expect(find.text('Could not reach an XCred server at that URL.'), findsOneWidget);
      expect(c.read(savedServersProvider).value, isEmpty);
    });
  });
}
