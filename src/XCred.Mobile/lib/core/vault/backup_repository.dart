import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../models/settings_models.dart';

/// MOB-SET-03 — BackupController.cs. The export is a plain JSON file of the caller's
/// own already-encrypted data (credential ciphertext/IV/wrapped-key copied verbatim,
/// no server-side re-encryption — there's nothing meaningful to re-encrypt with in a
/// zero-knowledge system) — decrypting it still needs the original master password.
/// Restore is one dedicated bulk-import endpoint, not a loop of individual creates;
/// duplicates (exact `ownerId + encryptedData` match) are skipped server-side, not
/// re-created.
class BackupRepository {
  BackupRepository(this._api, this._dio);
  final ApiClient _api;
  final Dio _dio;

  /// `GET /api/backup` returns a raw file, not the standard `ApiResponse<T>` envelope
  /// every other endpoint uses — bypasses [ApiClient] (which assumes that envelope) and
  /// reads bytes directly, mirroring how the web app treats this one endpoint specially
  /// (`responseType: 'blob'`).
  Future<Uint8List> export() async {
    final response = await _dio.get<List<int>>(
      '/api/backup',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  }

  Future<BackupRestoreResult> restore(Map<String, dynamic> backup) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/api/backup/restore',
      (json) => json as Map<String, dynamic>,
      data: backup,
    );
    return BackupRestoreResult.fromJson(data);
  }
}
