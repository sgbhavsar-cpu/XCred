// Mirrors XCred.Core.DTOs.Sharing.SharedCredentialDto / UsersController's
// UserSummaryDto — see SharesController.cs / UsersController.cs for the server shape.

/// The recipient picker's entry — `publicKey` is the SPKI-encoded RSA public key used
/// to re-wrap a credential's AES key for sharing (CryptoService.encryptKeyWithPublicKey).
class UserSummary {
  final String id;
  final String username;
  final String email;
  final String publicKey;
  const UserSummary({
    required this.id,
    required this.username,
    required this.email,
    required this.publicKey,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
        id: json['id'] as String,
        username: json['username'] as String,
        email: json['email'] as String,
        publicKey: json['publicKey'] as String,
      );
}

class SharedCredentialSummary {
  final String id;
  final String credentialId;
  final String encryptedData;
  final String dataIv;
  final String encryptedCredentialKey;
  final String credentialType;
  final String sharedByUsername;
  final String? sharedWithUserId;
  final String? sharedWithUsername;
  final String? sharedWithGroupId;
  final String? sharedWithGroupName;
  final DateTime? expiresAt;
  final bool untilChanged;
  final DateTime createdAt;
  final bool isRevoked;

  const SharedCredentialSummary({
    required this.id,
    required this.credentialId,
    required this.encryptedData,
    required this.dataIv,
    required this.encryptedCredentialKey,
    required this.credentialType,
    required this.sharedByUsername,
    this.sharedWithUserId,
    this.sharedWithUsername,
    this.sharedWithGroupId,
    this.sharedWithGroupName,
    this.expiresAt,
    required this.untilChanged,
    required this.createdAt,
    required this.isRevoked,
  });

  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  factory SharedCredentialSummary.fromJson(Map<String, dynamic> json) => SharedCredentialSummary(
        id: json['id'] as String,
        credentialId: json['credentialId'] as String,
        encryptedData: json['encryptedData'] as String,
        dataIv: json['dataIv'] as String,
        encryptedCredentialKey: json['encryptedCredentialKey'] as String,
        credentialType: json['credentialType'] as String,
        sharedByUsername: json['sharedByUsername'] as String,
        sharedWithUserId: json['sharedWithUserId'] as String?,
        sharedWithUsername: json['sharedWithUsername'] as String?,
        sharedWithGroupId: json['sharedWithGroupId'] as String?,
        sharedWithGroupName: json['sharedWithGroupName'] as String?,
        expiresAt:
            json['expiresAt'] == null ? null : DateTime.parse(json['expiresAt'] as String),
        untilChanged: json['untilChanged'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        isRevoked: json['isRevoked'] as bool? ?? false,
      );
}

/// A [SharedCredentialSummary] paired with its decrypted display name — mirrors
/// [DecryptedCredentialMeta] (credential_models.dart), computed once per fetch since
/// decryption needs the session's private key (providers/share_providers.dart).
class SharedItem {
  final SharedCredentialSummary share;
  final String name;
  const SharedItem({required this.share, required this.name});
}
