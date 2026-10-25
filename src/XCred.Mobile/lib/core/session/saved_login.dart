import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Everything needed to log in to one server in a single step.
class SavedLogin {
  const SavedLogin({
    required this.username,
    required this.loginPassword,
    required this.masterPassword,
  });
  final String username;
  final String loginPassword;
  final String masterPassword;
}

/// Opt-in "remember my login" for each saved server, kept in [FlutterSecureStorage]
/// (Android Keystore-backed encryption at rest).
///
/// This deliberately goes further than the app's usual "the master password is never stored"
/// stance, at the user's request, so it is guarded the same way as the biometric Quick Unlock
/// key ([SecureVaultStorage]): [read] must only ever be called after a fresh
/// [BiometricGate.authenticate] succeeds — this class does not prompt by itself. The username is
/// kept in its own entry so the UI can show "saved for alice" without a prompt; the passwords
/// are only ever returned by [read].
class SavedLoginStore {
  SavedLoginStore(this._storage);
  final FlutterSecureStorage _storage;

  static String _key(String serverId, String field) => 'savedlogin.$serverId.$field';

  Future<void> save(String serverId, SavedLogin login) async {
    await Future.wait([
      _storage.write(key: _key(serverId, 'user'), value: login.username),
      _storage.write(key: _key(serverId, 'pass'), value: login.loginPassword),
      _storage.write(key: _key(serverId, 'master'), value: login.masterPassword),
    ]);
  }

  /// The saved username for display only — never the passwords.
  Future<String?> username(String serverId) => _storage.read(key: _key(serverId, 'user'));

  /// The full saved login, or null when none (or an incomplete one) is stored. Gate behind biometrics.
  Future<SavedLogin?> read(String serverId) async {
    final values = await Future.wait([
      _storage.read(key: _key(serverId, 'user')),
      _storage.read(key: _key(serverId, 'pass')),
      _storage.read(key: _key(serverId, 'master')),
    ]);
    if (values.any((v) => v == null)) return null;
    return SavedLogin(username: values[0]!, loginPassword: values[1]!, masterPassword: values[2]!);
  }

  Future<void> forget(String serverId) async {
    await Future.wait([
      _storage.delete(key: _key(serverId, 'user')),
      _storage.delete(key: _key(serverId, 'pass')),
      _storage.delete(key: _key(serverId, 'master')),
    ]);
  }
}
