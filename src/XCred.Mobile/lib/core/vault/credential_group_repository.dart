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
}
