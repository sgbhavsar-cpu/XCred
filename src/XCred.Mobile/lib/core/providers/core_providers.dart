import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import '../auth/auth_repository.dart';
import '../auth/auth_session.dart';
import '../crypto/crypto_service.dart';
import '../db/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final cryptoServiceProvider = Provider<CryptoService>((ref) => CryptoService());

/// The configured backend base URL (e.g. `http://localhost:18080`), persisted in drift
/// (Sprint 0.1's proof that Riverpod + drift compose correctly). `null`/empty means
/// first-run — the router redirects to `/setup`.
class ServerBaseUrlNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final db = ref.watch(databaseProvider);
    final url = await db.getServerBaseUrl();
    return (url == null || url.isEmpty) ? null : url;
  }

  Future<void> set(String url) async {
    final db = ref.read(databaseProvider);
    await db.setServerBaseUrl(url);
    state = AsyncData(url);
  }

  Future<void> clear() async {
    final db = ref.read(databaseProvider);
    await db.clearServerBaseUrl();
    state = const AsyncData(null);
  }
}

final serverBaseUrlProvider =
    AsyncNotifierProvider<ServerBaseUrlNotifier, String?>(ServerBaseUrlNotifier.new);

/// Ephemeral, in-memory session — see [AuthSession] for why this can't be persisted
/// as-is. `null` means logged out.
class AuthSessionNotifier extends Notifier<AuthSession?> {
  @override
  AuthSession? build() => null;

  void setSession(AuthSession session) => state = session;
  void clear() => state = null;
}

final authSessionProvider =
    NotifierProvider<AuthSessionNotifier, AuthSession?>(AuthSessionNotifier.new);

/// Rebuilds whenever the configured server URL changes. JWT attachment for
/// authenticated calls is added per-request by [ApiClient] callers reading
/// [authSessionProvider] directly (kept out of the interceptor so 401s from a stale
/// token surface as a normal [ApiException] the caller can react to, rather than
/// triggering an implicit refresh loop before that flow is designed in a later sprint).
final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(serverBaseUrlProvider).value;
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl ?? '',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    contentType: 'application/json',
  ));
  final session = ref.watch(authSessionProvider);
  if (session != null) {
    dio.options.headers['Authorization'] = 'Bearer ${session.accessToken}';
  }
  return dio;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider), ref.watch(cryptoServiceProvider));
});
