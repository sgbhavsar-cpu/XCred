// Mirrors XCred.Core.DTOs.Credentials.CredentialDto / CredentialGroupDto — see
// CredentialsController.cs / CredentialGroupsController.cs for the server-side shape.
class TagRef {
  final String id;
  final String name;
  final String color;
  const TagRef({required this.id, required this.name, required this.color});

  factory TagRef.fromJson(Map<String, dynamic> json) => TagRef(
        id: json['id'] as String,
        name: json['name'] as String,
        color: json['color'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};
}

/// Metadata only — the encrypted *content* is fetched on demand
/// (high-level-design.md §2: attachments are deliberately not pre-synced into the
/// offline cache; large, and "know it exists, fetch bytes when opened" is a better
/// tradeoff than bloating local storage with every attachment's ciphertext).
class AttachmentMeta {
  final String id;
  final String encryptedFileName;
  final String? fileNameIv;
  final String encryptedMimeType;
  final String? mimeTypeIv;
  final int fileSizeBytes;
  final DateTime uploadedAt;

  const AttachmentMeta({
    required this.id,
    required this.encryptedFileName,
    this.fileNameIv,
    required this.encryptedMimeType,
    this.mimeTypeIv,
    required this.fileSizeBytes,
    required this.uploadedAt,
  });

  factory AttachmentMeta.fromJson(Map<String, dynamic> json) => AttachmentMeta(
        id: json['id'] as String,
        encryptedFileName: json['encryptedFileName'] as String,
        fileNameIv: json['fileNameIv'] as String?,
        encryptedMimeType: json['encryptedMimeType'] as String,
        mimeTypeIv: json['mimeTypeIv'] as String?,
        fileSizeBytes: json['fileSizeBytes'] as int,
        uploadedAt: DateTime.parse(json['uploadedAt'] as String),
      );
}

class CredentialListItem {
  final String id;
  final String type;
  final String encryptedData;
  final String dataIv;
  final String encryptedCredentialKey;
  final DateTime? expiryDate;
  final String? folderId;
  final String? folderName;
  final String? credentialGroupId;
  final String? credentialGroupName;
  final String ownerId;
  final String ownerUsername;
  final bool isShared;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TagRef> tags;
  final List<AttachmentMeta> attachments;

  const CredentialListItem({
    required this.id,
    required this.type,
    required this.encryptedData,
    required this.dataIv,
    required this.encryptedCredentialKey,
    this.expiryDate,
    this.folderId,
    this.folderName,
    this.credentialGroupId,
    this.credentialGroupName,
    required this.ownerId,
    required this.ownerUsername,
    required this.isShared,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
    this.attachments = const [],
  });

  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());

  factory CredentialListItem.fromJson(Map<String, dynamic> json) => CredentialListItem(
        id: json['id'] as String,
        type: json['type'] as String,
        encryptedData: json['encryptedData'] as String,
        dataIv: json['dataIv'] as String,
        encryptedCredentialKey: json['encryptedCredentialKey'] as String,
        expiryDate:
            json['expiryDate'] == null ? null : DateTime.parse(json['expiryDate'] as String),
        folderId: json['folderId'] as String?,
        folderName: json['folderName'] as String?,
        credentialGroupId: json['credentialGroupId'] as String?,
        credentialGroupName: json['credentialGroupName'] as String?,
        ownerId: json['ownerId'] as String,
        ownerUsername: json['ownerUsername'] as String? ?? '',
        isShared: json['isShared'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        tags: ((json['tags'] as List<dynamic>?) ?? [])
            .map((t) => TagRef.fromJson(t as Map<String, dynamic>))
            .toList(),
        attachments: ((json['attachments'] as List<dynamic>?) ?? [])
            .map((a) => AttachmentMeta.fromJson(a as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'encryptedData': encryptedData,
        'dataIv': dataIv,
        'encryptedCredentialKey': encryptedCredentialKey,
        'expiryDate': expiryDate?.toIso8601String(),
        'folderId': folderId,
        'folderName': folderName,
        'credentialGroupId': credentialGroupId,
        'credentialGroupName': credentialGroupName,
        'ownerId': ownerId,
        'ownerUsername': ownerUsername,
        'isShared': isShared,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'tags': tags.map((t) => t.toJson()).toList(),
      };
}

/// Display-only summary produced by decrypting a [CredentialListItem]'s payload once —
/// mirrors the web app's `DecryptedCredentialMeta` (useDecryptedCredentials.ts).
class DecryptedCredentialMeta {
  final String name;
  final String? subtitle;
  const DecryptedCredentialMeta({required this.name, this.subtitle});
}

class CredentialGroupSummary {
  final String id;
  final String name;
  final String icon;
  final String? teamGroupId;
  final int credentialCount;

  const CredentialGroupSummary({
    required this.id,
    required this.name,
    required this.icon,
    this.teamGroupId,
    required this.credentialCount,
  });

  factory CredentialGroupSummary.fromJson(Map<String, dynamic> json) => CredentialGroupSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String,
        teamGroupId: json['groupId'] as String?,
        credentialCount: json['credentialCount'] as int? ?? 0,
      );
}
