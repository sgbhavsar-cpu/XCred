import '../api/api_client.dart';

/// MOB-ATT-01/02 — no offline cache: attachment content is fetched fresh on every
/// upload/download, matching high-level-design.md §2's explicit decision not to
/// pre-sync attachment ciphertext into the local cache. Decryption stays out of this
/// class (needs the credential's per-record AES key, a screen-layer concern) — this
/// only knows about the wire shape.
class AttachmentRepository {
  AttachmentRepository(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> upload(
    String credentialId, {
    required String encryptedFileName,
    required String fileNameIv,
    required String encryptedMimeType,
    required String mimeTypeIv,
    required String encryptedData,
    required String dataIv,
    required int fileSizeBytes,
  }) {
    return _api.post<Map<String, dynamic>>(
      '/api/credentials/$credentialId/attachments',
      (json) => json as Map<String, dynamic>,
      data: {
        'encryptedFileName': encryptedFileName,
        'fileNameIv': fileNameIv,
        'encryptedMimeType': encryptedMimeType,
        'mimeTypeIv': mimeTypeIv,
        'encryptedData': encryptedData,
        'dataIv': dataIv,
        'fileSizeBytes': fileSizeBytes,
      },
    );
  }

  Future<Map<String, dynamic>> download(String credentialId, String attachmentId) {
    return _api.get<Map<String, dynamic>>(
      '/api/credentials/$credentialId/attachments/$attachmentId',
      (json) => json as Map<String, dynamic>,
    );
  }

  Future<void> delete(String credentialId, String attachmentId) {
    return _api.delete<String>(
      '/api/credentials/$credentialId/attachments/$attachmentId',
      identityFromData<String>,
    );
  }
}
