import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:xcred_mobile/core/auth/auth_repository.dart';
import 'package:xcred_mobile/core/auth/auth_session.dart';
import 'package:xcred_mobile/core/platform/biometric_gate.dart';
import 'package:xcred_mobile/core/providers/core_providers.dart';
import 'package:xcred_mobile/core/providers/saved_login_providers.dart';
import 'package:xcred_mobile/core/providers/server_providers.dart';
import 'package:xcred_mobile/core/session/saved_login.dart';
import 'package:xcred_mobile/features/auth/login_screen.dart';
import 'package:xcred_mobile/features/setup/servers_sheet.dart';

class _ActiveUrl extends ServerBaseUrlNotifier {
  @override
  Future<String?> build() async => 'https://office.example.com';
}

class _FakeGate implements BiometricGate {
  _FakeGate({this.available = true});
  final bool available;
  bool allow = true;
  final List<String> prompts = [];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    prompts.add(reason);
    return allow;
  }
}

class _FakeAuth implements AuthRepository {
  final List<({String username, String loginPassword, String masterPassword})> calls = [];

  @override
  Future<AuthSession> login({
    required String username,
    required String loginPassword,
    required String masterPassword,
  }) async {
    calls.add((username: username, loginPassword: loginPassword, masterPassword: masterPassword));
    return AuthSession(
      userId: 'u1',
      username: username,
      email: '$username@example.com',
      role: 'User',
      accessToken: 't',
      refreshToken: 'r',
      expiresAt: DateTime(2100),
      publicKeySpkiB64: 'pk',
      masterKey: null,
      privateKey: pc.RSAPrivateKey(BigInt.from(3233), BigInt.from(2753), BigInt.from(61), BigInt.from(53)),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Env {
  _Env(this.container, this.gate, this.auth, this.serverId);
  final ProviderContainer container;
  final _FakeGate gate;
  final _FakeAuth auth;
  final String serverId;
  SavedLoginStore get store => container.read(savedLoginStoreProvider);
}

Future<_Env> _env({bool biometrics = true, SavedLogin? saved}) async {
  // 'asked' is pre-set so a successful login doesn't stop on the Quick Unlock dialog.
  FlutterSecureStorage.setMockInitialValues({'session.biometricEnrollAsked': 'true'});
  final gate = _FakeGate(available: biometrics);
  final auth = _FakeAuth();
  final container = ProviderContainer(overrides: [
    serverBaseUrlProvider.overrideWith(_ActiveUrl.new),
    biometricGateProvider.overrideWithValue(gate),
    authRepositoryProvider.overrideWithValue(auth),
  ]);
  addTearDown(container.dispose);
  final server = (await container.read(savedServersProvider.future)).single;
  if (saved != null) await container.read(savedLoginStoreProvider).save(server.id, saved);
  return _Env(container, gate, auth, server.id);
}

Future<void> _pumpLogin(WidgetTester tester, _Env env) async {
  await tester.pumpWidget(UncontrolledProviderScope(
    container: env.container,
    child: const MaterialApp(home: LoginScreen()),
  ));
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester, {String user = 'alice', String pass = 'LoginPass1', String master = 'MasterPass1'}) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), user);
  await tester.enterText(fields.at(1), pass);
  await tester.enterText(fields.at(2), master);
}

void main() {
  group('SavedLoginStore', () {
    test('saves per server; the username is readable alone, the passwords only via read()', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final store = SavedLoginStore(const FlutterSecureStorage());
      await store.save('s1', const SavedLogin(username: 'alice', loginPassword: 'p1', masterPassword: 'm1'));
      await store.save('s2', const SavedLogin(username: 'bob', loginPassword: 'p2', masterPassword: 'm2'));

      expect(await store.username('s1'), 'alice');
      final login = await store.read('s2');
      expect((login!.username, login.loginPassword, login.masterPassword), ('bob', 'p2', 'm2'));
      expect(await store.read('nope'), isNull);
    });

    test('forget removes one server only, and an incomplete entry reads as nothing', () async {
      FlutterSecureStorage.setMockInitialValues({'savedlogin.s3.user': 'carol'}); // no passwords
      final store = SavedLoginStore(const FlutterSecureStorage());
      expect(await store.read('s3'), isNull);

      await store.save('s1', const SavedLogin(username: 'a', loginPassword: 'p', masterPassword: 'm'));
      await store.save('s2', const SavedLogin(username: 'b', loginPassword: 'p', masterPassword: 'm'));
      await store.forget('s1');
      expect(await store.username('s1'), isNull);
      expect(await store.read('s1'), isNull);
      expect(await store.username('s2'), 'b');
    });
  });

  group('login screen', () {
    testWidgets('the remember switch is not offered when the device has no biometric / unlock', (tester) async {
      final env = await _env(biometrics: false);
      await _pumpLogin(tester, env);
      expect(find.byKey(const ValueKey('remember_login')), findsNothing);
    });

    testWidgets('turning it on stores the username and both passwords for this server after a good login', (tester) async {
      final env = await _env();
      await _pumpLogin(tester, env);
      expect(find.byKey(const ValueKey('login_with_saved')), findsNothing);

      await _fill(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('remember_login')));
      await tester.tap(find.byKey(const ValueKey('remember_login')));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Log In'));
      await tester.pumpAndSettle();

      expect(env.auth.calls.single.username, 'alice');
      final saved = await env.store.read(env.serverId);
      expect((saved!.username, saved.loginPassword, saved.masterPassword), ('alice', 'LoginPass1', 'MasterPass1'));
      expect(env.container.read(savedLoginUsernamesProvider).value, {env.serverId: 'alice'});
    });

    testWidgets('with the switch off nothing is stored', (tester) async {
      final env = await _env();
      await _pumpLogin(tester, env);
      await _fill(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Log In'));
      await tester.pumpAndSettle();

      expect(env.auth.calls, hasLength(1));
      expect(await env.store.read(env.serverId), isNull);
    });

    testWidgets('a saved login shows a one-tap button; biometric first, then the saved details log in', (tester) async {
      final env = await _env(
          saved: const SavedLogin(username: 'alice', loginPassword: 'LoginPass1', masterPassword: 'MasterPass1'));
      await _pumpLogin(tester, env);
      expect(find.text('Log in as alice'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('remember_login'))).value, isTrue);

      await tester.tap(find.byKey(const ValueKey('login_with_saved')));
      await tester.pumpAndSettle();

      expect(env.gate.prompts.single, contains('office.example.com'));
      expect(env.auth.calls.single.loginPassword, 'LoginPass1');
      expect(env.auth.calls.single.masterPassword, 'MasterPass1');
      expect(env.container.read(authSessionProvider)?.username, 'alice');
    });

    testWidgets('if the biometric / unlock check fails, the saved passwords are never used', (tester) async {
      final env = await _env(
          saved: const SavedLogin(username: 'alice', loginPassword: 'LoginPass1', masterPassword: 'MasterPass1'));
      env.gate.allow = false;
      await _pumpLogin(tester, env);

      await tester.tap(find.byKey(const ValueKey('login_with_saved')));
      await tester.pumpAndSettle();

      expect(find.text('Authentication failed or was cancelled.'), findsOneWidget);
      expect(env.auth.calls, isEmpty);
      expect(find.widgetWithText(TextFormField, 'LoginPass1'), findsNothing);
    });

    testWidgets('logging in with the switch turned off forgets the saved login', (tester) async {
      final env = await _env(
          saved: const SavedLogin(username: 'alice', loginPassword: 'LoginPass1', masterPassword: 'MasterPass1'));
      await _pumpLogin(tester, env);
      await _fill(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('remember_login')));
      await tester.tap(find.byKey(const ValueKey('remember_login'))); // on -> off
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Log In'));
      await tester.pumpAndSettle();

      expect(await env.store.read(env.serverId), isNull);
      expect(env.container.read(savedLoginUsernamesProvider).value, isEmpty);
    });
  });

  group('server list', () {
    testWidgets('shows who is saved on each server and can forget just the login', (tester) async {
      final env = await _env(
          saved: const SavedLogin(username: 'alice', loginPassword: 'p', masterPassword: 'm'));
      await tester.pumpWidget(UncontrolledProviderScope(
        container: env.container,
        child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: SavedServersList()))),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Saved login: alice'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('server_menu_${env.serverId}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forget saved login'));
      await tester.pumpAndSettle();

      expect(find.text('Saved login: alice'), findsNothing);
      expect(await env.store.read(env.serverId), isNull);
      expect(find.text('office.example.com'), findsOneWidget); // the server itself stays
    });
  });
}
