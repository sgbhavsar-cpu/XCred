import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/auth_session.dart';

/// Everything needed to reconstruct a session on the Unlock path (architecture.md §3.2)
/// *except* the private key itself, which comes from [SecureVaultStorage] separately —
/// keeping the two concerns apart matches the security table's distinction between
/// "no biometric gate needed" (tokens) and "biometric/PIN-gated per retrieval" (key).
class PersistedSession {
  final String userId;
  final String username;
  final String email;
  final String role;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String publicKeySpkiB64;

  const PersistedSession({
    required this.userId,
    required this.username,
    required this.email,
    required this.role,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.publicKeySpkiB64,
  });
}

class SessionPersistence {
  SessionPersistence(this._storage);
  final FlutterSecureStorage _storage;

  static const _kUserId = 'session.userId';
  static const _kUsername = 'session.username';
  static const _kEmail = 'session.email';
  static const _kRole = 'session.role';
  static const _kAccessToken = 'session.accessToken';
  static const _kRefreshToken = 'session.refreshToken';
  static const _kExpiresAt = 'session.expiresAt';
  static const _kPublicKey = 'session.publicKeySpkiB64';
  static const _kEnrollAsked = 'session.biometricEnrollAsked';

  Future<void> save(AuthSession session) async {
    await Future.wait([
      _storage.write(key: _kUserId, value: session.userId),
      _storage.write(key: _kUsername, value: session.username),
      _storage.write(key: _kEmail, value: session.email),
      _storage.write(key: _kRole, value: session.role),
      _storage.write(key: _kAccessToken, value: session.accessToken),
      _storage.write(key: _kRefreshToken, value: session.refreshToken),
      _storage.write(key: _kExpiresAt, value: session.expiresAt.toIso8601String()),
      _storage.write(key: _kPublicKey, value: session.publicKeySpkiB64),
    ]);
  }

  /// Null if no persisted session exists (fresh install, logged out) or the data is
  /// incomplete (partial write, manual tampering) — callers fall back to full login.
  Future<PersistedSession?> load() async {
    final values = await Future.wait([
      _storage.read(key: _kUserId),
      _storage.read(key: _kUsername),
      _storage.read(key: _kEmail),
      _storage.read(key: _kRole),
      _storage.read(key: _kAccessToken),
      _storage.read(key: _kRefreshToken),
      _storage.read(key: _kExpiresAt),
      _storage.read(key: _kPublicKey),
    ]);
    if (values.any((v) => v == null)) return null;
    return PersistedSession(
      userId: values[0]!,
      username: values[1]!,
      email: values[2]!,
      role: values[3]!,
      accessToken: values[4]!,
      refreshToken: values[5]!,
      expiresAt: DateTime.parse(values[6]!),
      publicKeySpkiB64: values[7]!,
    );
  }

  /// Clears tokens/user info only — deliberately doesn't touch the
  /// biometric-enrollment-asked flag (re-asking on every logout would defeat "once per
  /// device," MOB-SESS-01) or [SecureVaultStorage]'s wrapped key (a separate concern,
  /// cleared explicitly by callers that mean "Log Out", not by this alone).
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _kUserId),
      _storage.delete(key: _kUsername),
      _storage.delete(key: _kEmail),
      _storage.delete(key: _kRole),
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
      _storage.delete(key: _kExpiresAt),
      _storage.delete(key: _kPublicKey),
    ]);
  }

  Future<bool> hasAskedBiometricEnrollment() async =>
      (await _storage.read(key: _kEnrollAsked)) == 'true';

  Future<void> markBiometricEnrollmentAsked() =>
      _storage.write(key: _kEnrollAsked, value: 'true');
}
