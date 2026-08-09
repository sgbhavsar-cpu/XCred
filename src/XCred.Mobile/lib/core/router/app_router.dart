import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/credentials/credential_detail_screen.dart';
import '../../features/credentials/credential_form_screen.dart';
import '../../features/credentials/credential_group_detail_screen.dart';
import '../../features/credentials/credentials_tree_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/folders/folders_screen.dart';
import '../../features/session/unlock_screen.dart';
import '../../features/setup/server_setup_screen.dart';
import '../../features/tags/tags_screen.dart';
import '../providers/core_providers.dart';

/// Bridges Riverpod state into go_router's imperative `refreshListenable` — Sprint 0.1's
/// proof that Riverpod and go_router compose. Redirect logic implements the guard chain
/// from architecture.md §3.2: no server configured -> /setup; server configured, no
/// session, resumable (wrapped key + tokens persisted) -> /unlock; server configured, no
/// session, not resumable -> /login; session present -> /dashboard.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this.ref) {
    ref.listen(serverBaseUrlProvider, (_, _) => notifyListeners());
    ref.listen(authSessionProvider, (_, _) => notifyListeners());
    ref.listen(resumableSessionProvider, (_, _) => notifyListeners());
  }
  final Ref ref;
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/setup',
    refreshListenable: refresh,
    redirect: (context, state) {
      final baseUrl = ref.read(serverBaseUrlProvider).value;
      final session = ref.read(authSessionProvider);
      final resumable = ref.read(resumableSessionProvider).value ?? false;
      final loc = state.matchedLocation;
      final atSetup = loc == '/setup';
      final atAuth = loc == '/login' || loc == '/register';
      final atUnlock = loc == '/unlock';

      if (baseUrl == null || baseUrl.isEmpty) {
        return atSetup ? null : '/setup';
      }
      if (session == null) {
        // A resumable device lands on /unlock by default, but an explicit tap on
        // "enter master password instead" (-> /login) must stick, not bounce straight
        // back to /unlock (architecture.md §3.2 point 4's escape hatch).
        if (resumable && !atAuth) return atUnlock ? null : '/unlock';
        return (atAuth || atUnlock) ? null : '/login';
      }
      if (atSetup || atAuth || atUnlock) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/setup', builder: (context, state) => const ServerSetupScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/unlock', builder: (context, state) => const UnlockScreen()),
      GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
      GoRoute(path: '/credentials', builder: (context, state) => const CredentialsTreeScreen()),
      GoRoute(
        path: '/credentials/new',
        builder: (context, state) => CredentialFormScreen(
          initialGroupId: state.uri.queryParameters['groupId'],
          initialFolderId: state.uri.queryParameters['folderId'],
          initialTagId: state.uri.queryParameters['tagId'],
        ),
      ),
      GoRoute(
        path: '/credentials/:id',
        builder: (context, state) =>
            CredentialDetailScreen(credentialId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/credentials/:id/edit',
        builder: (context, state) =>
            CredentialFormScreen(credentialId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/credential-groups/:id',
        builder: (context, state) =>
            CredentialGroupDetailScreen(groupId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/folders', builder: (context, state) => const FoldersScreen()),
      GoRoute(path: '/tags', builder: (context, state) => const TagsScreen()),
    ],
  );
});
