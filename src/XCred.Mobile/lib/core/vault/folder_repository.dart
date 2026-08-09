import '../api/api_client.dart';
import '../models/folder_tag_models.dart';

/// MOB-FOLD-01 — no offline cache (folders are metadata, not ciphertext; re-fetched on
/// every screen visit, matching the web app's own `loadFolders()` pattern).
class FolderRepository {
  FolderRepository(this._api);
  final ApiClient _api;

  Future<List<FolderNode>> getAll() async {
    final data = await _api.get<List<dynamic>>('/api/folders', (json) => json as List<dynamic>);
    return data.map((e) => FolderNode.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> create({required String name, String? parentFolderId}) {
    return _api.post<Map<String, dynamic>>(
      '/api/folders',
      (json) => json as Map<String, dynamic>,
      data: {'name': name, 'parentFolderId': parentFolderId},
    );
  }

  /// [parentFolderId] must be the folder's *current* parent — the update endpoint
  /// takes the full parent/sortOrder, not a partial patch, so omitting it would
  /// silently move a nested folder to the top level.
  Future<void> rename(String id, String name, {String? parentFolderId, int sortOrder = 0}) {
    return _api.put<Map<String, dynamic>>(
      '/api/folders/$id',
      (json) => json as Map<String, dynamic>,
      data: {'name': name, 'parentFolderId': parentFolderId, 'sortOrder': sortOrder},
    );
  }

  /// Server-side, credentials in the deleted folder are unlinked (folderId set null),
  /// never deleted — FoldersController.cs's Delete confirms this; MOB-FOLD-01's
  /// acceptance criteria depends on it.
  Future<void> delete(String id) {
    return _api.delete<String>('/api/folders/$id', identityFromData<String>);
  }
}
