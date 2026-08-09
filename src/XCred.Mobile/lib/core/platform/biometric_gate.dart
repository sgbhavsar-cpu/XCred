import 'package:local_auth/local_auth.dart';

/// Gates access to [SecureVaultStorage] with a fresh OS-level check each time —
/// architecture.md §5. `biometricOnly: false` lets the OS fall back to device PIN/
/// pattern/password after repeated biometric failures (standard Android BiometricPrompt
/// behavior), which satisfies MOB-SESS-02's "PIN fallback" acceptance criterion without
/// a hand-rolled retry counter — the native prompt already owns that UX.
abstract class BiometricGate {
  Future<bool> isAvailable();
  Future<bool> authenticate(String reason);
}

class LocalAuthBiometricGate implements BiometricGate {
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    try {
      final deviceSupported = await _auth.isDeviceSupported();
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      return deviceSupported || canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
