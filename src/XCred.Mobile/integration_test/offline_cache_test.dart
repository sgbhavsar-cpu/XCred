// MOB-SYNC-01 proof: after a successful sync, a network failure must show the cached
// tree with an offline indicator, not an error screen or a blank list.
//
// Real `adb shell svc data disable` connectivity cuts turned out to be too fragile to
// orchestrate deterministically alongside a running `flutter test` process (no way to
// interleave the two reliably), so — matching the same provider-override seam already
// used for BiometricGate in session_lifecycle_test.dart — this wraps the real
// [ApiClient] in a toggleable fake that can simulate "network unreachable" for every
// request with a plain Dart boolean flip. Everything else (drift cache, real login,
// real decryption of the real 56-credential dataset) is completely real.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xcred_mobile/core/api/api_client.dart';
import 'package:xcred_mobile/core/api/api_response.dart';
import 'package:xcred_mobile/core/providers/core_providers.dart';
import 'package:xcred_mobile/features/credentials/widgets/credential_row.dart';
import 'package:xcred_mobile/main.dart';

class ToggleableApiClient extends ApiClient {
  ToggleableApiClient(Dio dio) : super(dio);
  bool offline = false;

  @override
  Future<T> get<T>(String path, T Function(dynamic json) fromData,
      {Map<String, dynamic>? query}) {
    if (offline) {
      throw const ApiException(code: 'NETWORK_ERROR', message: 'Simulated offline.');
    }
    return super.get(path, fromData, query: query);
  }
}

Future<void> _pumpUntilAny(WidgetTester tester, List<Finder> finders, {int maxTries = 40}) async {
  for (var i = 0; i < maxTries; i++) {
    if (finders.any((f) => f.evaluate().isNotEmpty)) return;
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Credentials tree falls back to the drift cache with an offline banner '
      'when the network fails', (tester) async {
    late ToggleableApiClient toggleableClient;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWith((ref) {
          toggleableClient = ToggleableApiClient(ref.watch(dioProvider));
          return toggleableClient;
        }),
      ],
      child: const XCredApp(),
    ));
    await tester.pumpAndSettle();

    // --- Real login, network up ---
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

    // --- Load the real tree once, online — populates the drift cache ---
    await tester.tap(find.text('Browse Credentials'));
    await tester.pumpAndSettle(const Duration(seconds: 10));
    expect(find.byType(CredentialRow), findsWidgets,
        reason: 'Must successfully load the real dataset online before this test can '
            'prove anything about the offline fallback');
    expect(find.text('Offline — showing last synced data'), findsNothing);

    // --- Flip to simulated-offline, pull to refresh ---
    toggleableClient.offline = true;
    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('Offline — showing last synced data'), findsOneWidget,
        reason: 'A failed network fetch must fall back to the drift cache with a '
            'visible offline indicator, per architecture.md §3.3 and requirements §6.3');
    expect(find.byType(CredentialRow), findsWidgets,
        reason: 'The cached tree must still render the real, previously-decrypted '
            'credentials, not an empty or error state');
  });
}
