import '../api/api_client.dart';
import '../models/share_models.dart';

/// MOB-SHARE-01/02's recipient picker source — `GET /api/users` is intentionally not
/// admin-gated (UsersController.cs), and already excludes the caller and any
/// inactive/unapproved account server-side.
class UsersRepository {
  UsersRepository(this._api);
  final ApiClient _api;

  Future<List<UserSummary>> getAll() async {
    final data = await _api.get<List<dynamic>>('/api/users', (json) => json as List<dynamic>);
    return data.map((e) => UserSummary.fromJson(e as Map<String, dynamic>)).toList();
  }
}
