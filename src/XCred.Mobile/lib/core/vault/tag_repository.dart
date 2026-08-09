import '../api/api_client.dart';
import '../models/folder_tag_models.dart';

/// MOB-TAG-01 — no offline cache, matching FolderRepository's reasoning.
class TagRepository {
  TagRepository(this._api);
  final ApiClient _api;

  Future<List<TagSummary>> getAll() async {
    final data = await _api.get<List<dynamic>>('/api/tags', (json) => json as List<dynamic>);
    return data.map((e) => TagSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> create({required String name, required String color}) {
    return _api.post<Map<String, dynamic>>(
      '/api/tags',
      (json) => json as Map<String, dynamic>,
      data: {'name': name, 'color': color},
    );
  }

  Future<void> update(String id, {required String name, required String color}) {
    return _api.put<Map<String, dynamic>>(
      '/api/tags/$id',
      (json) => json as Map<String, dynamic>,
      data: {'name': name, 'color': color},
    );
  }

  /// Server-side, the tag is removed from every credential it was applied to
  /// (TagsController.cs's Delete cascades the CredentialTag join rows) — MOB-TAG-01's
  /// acceptance criteria depends on it.
  Future<void> delete(String id) {
    return _api.delete<String>('/api/tags/$id', identityFromData<String>);
  }
}
