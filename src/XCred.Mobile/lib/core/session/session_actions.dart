import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';

/// Shared by the dashboard's quick-access icons and the Settings screen's Account
/// section — same two actions, two entry points. Soft lock: clears the in-memory
/// session only, wrapped key + persisted tokens stay put, so the next app open goes to
/// `/unlock` (fast re-entry), not `/login` — MOB-SESS-03's distinction from Log Out.
void lockNow(WidgetRef ref) {
  ref.read(authSessionProvider.notifier).clear();
}

/// Full wipe — tokens, persisted session, and the wrapped biometric-unlock key are all
/// cleared, so the next app open goes to `/login`, not `/unlock`.
Future<void> logOut(WidgetRef ref) async {
  await ref.read(sessionPersistenceProvider).clear();
  await ref.read(secureVaultStorageProvider).clear();
  ref.invalidate(resumableSessionProvider);
  ref.read(authSessionProvider.notifier).clear();
}
