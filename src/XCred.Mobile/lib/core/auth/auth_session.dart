import 'package:cryptography/cryptography.dart' as cg;
import 'package:pointycastle/export.dart' as pc;

/// In-memory-only session state. Per the zero-knowledge model (architecture.md §4),
/// [masterKey] and [privateKey] must never be persisted as-is — only
/// [flutter_secure_storage]-wrapped, biometric-gated forms are (added in a later
/// sprint, per docs/planning/sprint-plan.md's Sprint 1.x unlock work). Losing this
/// object (app restart, process death) means the user must log in again.
class AuthSession {
  final String userId;
  final String username;
  final String email;
  final String role;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String publicKeySpkiB64;

  /// The derived PBKDF2 key — kept only for re-deriving/changing the master password
  /// within this session; never sent to the server. Null when the session came from
  /// [BiometricGate] unlock rather than a full master-password login (FR-AUTH-05's
  /// change-master-password flow re-prompts for it when actually needed).
  final cg.SecretKey? masterKey;

  /// The decrypted RSA private key — used to unwrap per-credential AES keys.
  final pc.RSAPrivateKey privateKey;

  const AuthSession({
    required this.userId,
    required this.username,
    required this.email,
    required this.role,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.publicKeySpkiB64,
    required this.masterKey,
    required this.privateKey,
  });
}
