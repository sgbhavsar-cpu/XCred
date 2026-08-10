import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart';
import '../vault/admin_repository.dart';
import 'core_providers.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(apiClientProvider));
});

/// Shared by the Users and Pending tabs (admin_screen.dart) — the Pending tab is just
/// this same list filtered client-side for `!isApproved`, rather than its own separate
/// fetch. A single shared source means approving/changing-role/activating from either
/// tab is reflected on both immediately: `TabBarView` keeps adjacent tabs' State alive
/// rather than rebuilding them on every switch, so a tab-local fetch-once-in-initState
/// approach would otherwise keep showing stale data after an action taken on another
/// tab (this was a real bug, caught by the sprint's own integration test).
class AdminUsersNotifier extends AsyncNotifier<List<AdminUserSummary>> {
  @override
  Future<List<AdminUserSummary>> build() =>
      ref.read(adminRepositoryProvider).getUsers(includeInactive: true);

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final adminUsersProvider =
    AsyncNotifierProvider<AdminUsersNotifier, List<AdminUserSummary>>(AdminUsersNotifier.new);
