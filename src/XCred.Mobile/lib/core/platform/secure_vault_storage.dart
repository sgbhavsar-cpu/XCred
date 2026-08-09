import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds the wrapped RSA private key — the one deliberate divergence from the web app's
/// "nothing persisted" model (architecture.md §4), justified by requiring a fresh
/// [BiometricGate] check on every retrieval, not just OS-encryption-at-rest. One
/// interface, swapped via Riverpod provider override per platform (architecture.md §5) —
/// currently a single `flutter_secure_storage`-backed implementation since Android and
/// iOS don't yet need divergent behavior; iOS-specific Keychain access-group config, if
/// ever needed, is a Phase 4 concern per the sprint plan.
abstract class SecureVaultStorage {
  Future<void> storeWrappedKey(Uint8List wrapped);

  /// Returns null if no key has been stored (never enrolled, logged out, or cleared by
  /// a master-password rotation). Callers are responsible for gating this call behind a
  /// successful [BiometricGate.authenticate] — this class does not itself prompt;
  /// `flutter_secure_storage`'s own AES-at-rest encryption is what "wraps" the bytes,
  /// the biometric check is an application-level gate in front of the read.
  Future<Uint8List?> retrieveWrappedKey();

  Future<bool> hasWrappedKey();
  Future<void> clear();
}

class FlutterSecureVaultStorage implements SecureVaultStorage {
  FlutterSecureVaultStorage(this._storage);
  final FlutterSecureStorage _storage;

  static const _key = 'vault.wrappedPrivateKeyPkcs8';

  @override
  Future<void> storeWrappedKey(Uint8List wrapped) =>
      _storage.write(key: _key, value: base64Encode(wrapped));

  @override
  Future<Uint8List?> retrieveWrappedKey() async {
    final b64 = await _storage.read(key: _key);
    return b64 == null ? null : base64Decode(b64);
  }

  @override
  Future<bool> hasWrappedKey() => _storage.containsKey(key: _key);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
