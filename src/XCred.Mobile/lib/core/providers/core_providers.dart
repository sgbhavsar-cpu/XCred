import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import '../auth/auth_repository.dart';
import '../auth/auth_session.dart';
import '../crypto/crypto_service.dart';
import '../db/app_database.dart';
import '../platform/biometric_gate.dart';
import '../platform/file_exchange.dart';
import '../platform/secure_vault_storage.dart';
import '../session/org_settings.dart';
import '../session/session_persistence.dart';

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

final secureVaultStorageProvider = Provider<SecureVaultStorage>((ref) {
  return FlutterSecureVaultStorage(ref.watch(secureStorageProvider));
});

final biometricGateProvider = Provider<BiometricGate>((ref) => LocalAuthBiometricGate());

final fileExchangeProvider = Provider<FileExchange>((ref) => DefaultFileExchange());

final sessionPersistenceProvider = Provider<SessionPersistence>((ref) {
  return SessionPersistence(ref.watch(secureStorageProvider));
});

/// True when a wrapped private key *and* persisted tokens/user info both exist — the
/// precondition for showing `/unlock` instead of `/login` on app start
/// (architecture.md §3.2). Re-read via `ref.invalidate` whenever either half changes
/// (enrollment, logout) so the router redirect reflects it immediately.
final resumableSessionProvider = FutureProvider<bool>((ref) async {
  final persisted = await ref.watch(sessionPersistenceProvider).load();
  final hasKey = await ref.watch(secureVaultStorageProvider).hasWrappedKey();
  return persisted != null && hasKey;
});

/// Populated from `GET /api/dashboard`'s `orgSettings` field once per session (matching
/// the web app's `AppLayout` pattern) — see [OrgSettings] for why this can't default to
/// hardcoded literals.
class OrgSettingsNotifier extends Notifier<OrgSettings> {
  @override
  OrgSettings build() => OrgSettings.defaults;

  void set(OrgSettings settings) => state = settings;
}

final orgSettingsProvider =
    NotifierProvider<OrgSettingsNotifier, OrgSettings>(OrgSettingsNotifier.new);
