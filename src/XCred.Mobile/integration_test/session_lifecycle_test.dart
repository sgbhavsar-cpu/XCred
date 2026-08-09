// End-to-end proof for Sprint 1.2 (MOB-SESS-01/02/03) against the live Docker dev
// backend on a real Android emulator. Real biometric hardware isn't available on this
// AVD (no fingerprint/PIN enrolled), so [BiometricGate] is swapped for a fake via a
// Riverpod provider override — exactly the seam architecture.md §5 describes existing
// for this purpose. Everything else (SecureVaultStorage/flutter_secure_storage,
// SessionPersistence, the router redirect guard, drift) is real.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xcred_mobile/core/platform/biometric_gate.dart';
import 'package:xcred_mobile/core/providers/core_providers.dart';
import 'package:xcred_mobile/main.dart';

class FakeBiometricGate implements BiometricGate {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> authenticate(String reason) async => true;
}

/// The login button's spinner keeps animating while the enrollment dialog awaits the
/// user's answer (correct app behavior — the request genuinely hasn't finished from the
/// screen's point of view), so `pumpAndSettle` can never return here: it waits for all
/// animation to stop, but nothing stops it until this same test taps the dialog, which
/// can't happen until `pumpAndSettle` returns. Poll for a specific widget instead.
Future<void> _pumpUntilFound(WidgetTester tester, Finder finder, {int maxTries = 40}) async {
  for (var i = 0; i < maxTries; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<void> _connectAndLogin(WidgetTester tester) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [biometricGateProvider.overrideWithValue(FakeBiometricGate())],
    child: const XCredApp(),
  ));
  await tester.pumpAndSettle();

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
  await _pumpUntilFound(tester, find.text('Enable Quick Unlock?'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Enroll on first login, resume via Unlock on restart, Lock Now, Log Out',
      (tester) async {
    await _connectAndLogin(tester);

    // --- MOB-SESS-01: enrollment prompt (first login on this device) ---
    expect(find.text('Enable Quick Unlock?'), findsOneWidget,
        reason: 'A device with biometrics available and never asked before must be '
            'offered enrollment right after a full login');
    await tester.tap(find.widgetWithText(FilledButton, 'Enable'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.textContaining('Hi, xcred_admin'), findsOneWidget,
        reason: 'Accepting enrollment must still land on the dashboard, not get stuck');

    // --- MOB-SESS-02: simulate app restart with a fresh provider tree ---
    await tester.pumpWidget(ProviderScope(
      overrides: [biometricGateProvider.overrideWithValue(FakeBiometricGate())],
      child: const XCredApp(),
    ));
    // UnlockScreen auto-triggers the biometric check in initState; with the fake gate
    // this resolves immediately, so settle straight through to the dashboard.
    await tester.pumpAndSettle(const Duration(seconds: 8));

    expect(find.textContaining('Hi, xcred_admin'), findsOneWidget,
        reason: 'A resumable session (wrapped key + persisted tokens) must reach the '
            'dashboard via Unlock, with no master password re-entry and no network '
            'login call');

    // --- MOB-SESS-03: Lock Now clears the in-memory session but stays resumable ---
    await tester.tap(find.byTooltip('Lock now'));
    await tester.pumpAndSettle(const Duration(seconds: 8));

    expect(find.textContaining('Hi, xcred_admin'), findsOneWidget,
        reason: 'Lock Now must re-reach the dashboard automatically via the still-valid '
            'wrapped key (Unlock path), proving Lock Now did not clear persisted '
            'material the way Log Out does');

    // --- MOB-SESS-03: Log Out clears persisted material entirely ---
    await tester.tap(find.byTooltip('Log out'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('Welcome back'), findsOneWidget,
        reason: 'Log Out must land on Login, not Unlock — the wrapped key and tokens '
            'must be gone');
  });
}
