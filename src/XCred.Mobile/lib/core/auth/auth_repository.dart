import '../api/api_client.dart';
import '../api/api_response.dart';
import '../crypto/crypto_service.dart';
import 'auth_session.dart';

/// Implements the two-secret model confirmed in Requirements-Flutter-Mobile.md
/// FR-AUTH-01/02: the *login password* is the only secret ever sent to the server
/// (as `password`, matching the existing `RegisterRequest`/`LoginRequest` DTOs —
/// no backend changes needed); the *master password* never leaves this method except
/// as the already-derived, already-applied artifacts (`publicKey`,
/// `encryptedPrivateKey`, `keyDerivationSalt`) it produces client-side.
class AuthRepository {
  AuthRepository(this._api, this._crypto);
  final ApiClient _api;
  final CryptoService _crypto;

  Future<String> register({
    required String fullName,
    required String username,
    required String email,
    required String loginPassword,
    required String masterPassword,
  }) async {
    final salt = _crypto.generateSalt();
    final masterKey = await _crypto.deriveKey(masterPassword, salt);
    final keyPair = _crypto.generateKeyPair();
    final wrappedPrivateKey =
        await _crypto.encryptPrivateKey(masterKey, keyPair.privateKeyPkcs8B64);

    return _api.post<String>(
      '/api/auth/register',
      identityFromData<String>,
      data: {
        'fullName': fullName,
        'username': username,
        'email': email,
        'password': loginPassword,
        'publicKey': keyPair.publicKeySpkiB64,
        'encryptedPrivateKey': wrappedPrivateKey.ciphertextB64,
        'privateKeyIv': wrappedPrivateKey.ivB64,
        'keyDerivationSalt': salt,
      },
    );
  }

  /// Throws [ApiException] for server-side auth failures (bad login password,
  /// pending approval, locked account — FR-AUTH-03) and [MasterPasswordException] if
  /// the login password was correct but the master password fails to decrypt the
  /// private key (wrong master password — a purely client-side failure the server
  /// cannot detect, by design).
  Future<AuthSession> login({
    required String username,
    required String loginPassword,
    required String masterPassword,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/auth/login',
      identityFromData<Map<String, dynamic>>,
      data: {'username': username, 'password': loginPassword},
    );

    final masterKey = await _crypto.deriveKey(
      masterPassword,
      response['keyDerivationSalt'] as String,
    );

    final privateKey = await () async {
      try {
        return await _crypto.decryptPrivateKey(
          masterKey,
          response['encryptedPrivateKey'] as String,
          response['privateKeyIv'] as String,
        );
      } catch (_) {
        throw const MasterPasswordException();
      }
    }();

    final user = response['user'] as Map<String, dynamic>;
    return AuthSession(
      userId: user['id'] as String,
      username: user['username'] as String,
      email: user['email'] as String,
      role: user['role'] as String,
      accessToken: response['accessToken'] as String,
      refreshToken: response['refreshToken'] as String,
      expiresAt: DateTime.parse(response['expiresAt'] as String),
      publicKeySpkiB64: response['publicKey'] as String,
      masterKey: masterKey,
      privateKey: privateKey,
    );
  }
}

/// The login password was correct (server accepted it) but the master password could
/// not decrypt the private key — i.e. the two secrets don't belong to the same vault.
class MasterPasswordException implements Exception {
  const MasterPasswordException();
  String get message => 'Incorrect master password.';
}
