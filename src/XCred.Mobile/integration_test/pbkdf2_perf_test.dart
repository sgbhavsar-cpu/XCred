// MOB-SETUP-03 — PBKDF2 performance measurement (docs/planning/sprint-plan.md Phase 0
// spike). Must run on-device (`flutter test integration_test/...` via a real emulator/
// device), not `flutter test`, because the whole point is measuring the native-accelerated
// path cryptography_flutter provides — `flutter test` runs pure-Dart on the host machine's
// CPU, which tells us nothing about real Android unlock latency.
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xcred_mobile/core/crypto/crypto_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PBKDF2-SHA256 600k iterations timing', (tester) async {
    FlutterCryptography.enable();
    final service = CryptoService();
    const password = 'Admin@#1234%^&*()';
    final salt = service.generateSalt();

    // Warm-up run (excludes plugin-channel / JIT warmup from the measured figure).
    await service.deriveKey(password, salt);

    const runs = 5;
    final timings = <int>[];
    for (var i = 0; i < runs; i++) {
      final sw = Stopwatch()..start();
      await service.deriveKey(password, salt);
      sw.stop();
      timings.add(sw.elapsedMilliseconds);
    }

    final avg = timings.reduce((a, b) => a + b) / timings.length;
    // ignore: avoid_print
    print('PBKDF2_PERF_RESULT runs=$timings avg_ms=$avg');

    expect(timings, isNotEmpty);
  });
}
