import '../api/api_client.dart';
import '../api/api_response.dart';
import '../db/app_database.dart';
import '../models/credential_models.dart';
import 'credential_repository.dart';

class CredentialGroupRepository {
  CredentialGroupRepository(this._api, this._db);
  final ApiClient _api;
  final AppDatabase _db;

  Future<VaultFetchResult<CredentialGroupSummary>> getAll() async {
    try {
      final data = await _api.get<List<dynamic>>(
        '/api/credential-groups',
        (json) => json as List<dynamic>,
      );
      final items = data
          .map((e) => CredentialGroupSummary.fromJson(e as Map<String, dynamic>))
          .toList();
      await _db.replaceCachedCredentialGroups(items);
      return VaultFetchResult(items: items, servedFromCache: false);
    } on ApiException catch (e) {
      if (e.code != 'NETWORK_ERROR') rethrow;
      final cached = await _db.getCachedCredentialGroups();
      return VaultFetchResult(items: cached, servedFromCache: true);
    }
  }

  /// Returns the group's own metadata plus its member credentials in one call
  /// (CredentialGroupsController.cs's GetById) — no offline fallback, matching
  /// Folder/TagRepository (this is a detail screen, not a cached list).
  Future<Map<String, dynamic>> getById(String id) {
    return _api.get<Map<String, dynamic>>(
      '/api/credential-groups/$id',
      (json) => json as Map<String, dynamic>,
    );
  }

  Future<void> create({required String name, required String icon}) {
    return _api.post<Map<String, dynamic>>(
      '/api/credential-groups',
      (json) => json as Map<String, dynamic>,
      data: {'name': name, 'icon': icon},
    );
  }

  Future<void> rename(String id, {required String name, required String icon}) {
    return _api.put<Map<String, dynamic>>(
      '/api/credential-groups/$id',
      (json) => json as Map<String, dynamic>,
      data: {'name': name, 'icon': icon},
    );
  }

  /// Server-side, member credentials are unlinked (credentialGroupId set null), never
  /// deleted — CredentialGroupsController.cs's Delete confirms this.
  Future<void> delete(String id) {
    return _api.delete<String>('/api/credential-groups/$id', identityFromData<String>);
  }
}
