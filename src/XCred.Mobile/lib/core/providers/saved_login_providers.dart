import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/saved_login.dart';
import 'core_providers.dart';
import 'server_providers.dart';

final savedLoginStoreProvider =
    Provider<SavedLoginStore>((ref) => SavedLoginStore(ref.watch(secureStorageProvider)));

/// Whether this device can show a biometric / device-unlock prompt. "Remember login" is only
/// offered when it can — a saved password with nothing guarding it would be worse than none.
final biometricAvailableProvider = FutureProvider<bool>((ref) async {
  return ref
      .read(biometricGateProvider)
      .isAvailable()
      .timeout(const Duration(seconds: 3), onTimeout: () => false);
});

/// Which saved servers have a remembered login, as serverId -> username. Usernames only: safe
/// to read without a prompt, used for the "saved for alice" hints and the login shortcut.
class SavedLoginUsernamesNotifier extends AsyncNotifier<Map<String, String>> {
  @override
  Future<Map<String, String>> build() async {
    final servers = await ref.watch(savedServersProvider.future);
    final store = ref.read(savedLoginStoreProvider);
    final result = <String, String>{};
    for (final s in servers) {
      final user = await store.username(s.id);
      if (user != null && user.isNotEmpty) result[s.id] = user;
    }
    return result;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final savedLoginUsernamesProvider =
    AsyncNotifierProvider<SavedLoginUsernamesNotifier, Map<String, String>>(
        SavedLoginUsernamesNotifier.new);
