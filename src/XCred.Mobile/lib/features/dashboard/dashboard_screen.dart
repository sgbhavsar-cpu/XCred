import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/session/org_settings.dart';
import '../../core/session/session_actions.dart';

/// Placeholder landing screen — the real Dashboard (FR-DASH-01..04, stat cards,
/// expiring-soon list, activity feed) is Sprint 1.4+ scope per sprint-plan.md, not this
/// sprint. This exists to prove the full authenticated loop end-to-end: dio attaches
/// the JWT from [authSessionProvider], the request reaches the real dev backend, and the
/// response is unwrapped through [ApiClient] exactly like any other screen will — and,
/// as of Sprint 1.2, to populate [orgSettingsProvider] (the same place the web app's
/// hardcoded-defaults bug originated, per this session's web fix), and as of Sprint
/// 1.3/1.5, link into the real Credentials/Folders/Tags screens. Lock Now / Log Out stay
/// as quick-access AppBar icons here (as of Sprint 2.3, also available from Settings)
/// rather than moving there entirely, so existing flows through this screen don't change.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Map<String, dynamic>? _dashboard;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
            '/api/dashboard',
            (json) => json as Map<String, dynamic>,
          );
      if (!mounted) return;
      setState(() => _dashboard = data);
      final orgSettingsJson = data['orgSettings'] as Map<String, dynamic>?;
      if (orgSettingsJson != null) {
        ref
            .read(orgSettingsProvider.notifier)
            .set(OrgSettings.fromJson(orgSettingsJson));
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load dashboard: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${session?.username ?? ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Lock now',
            onPressed: () => lockNow(ref),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => logOut(ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (_error != null) Text(_error!),
                  if (_dashboard != null) ...[
                    Row(
                      children: [
                        _StatCard(
                          label: 'Credentials',
                          value: '${_dashboard!['totalCredentials']}',
                          onTap: () => context.push('/credentials'),
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          label: 'Shared With Me',
                          value: '${_dashboard!['sharedWithMe']}',
                          onTap: () => context.push('/shares'),
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          label: 'Teams',
                          value: '${_dashboard!['groupCount']}',
                          onTap: () => context.push('/teams'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.push('/credentials'),
                      icon: const Icon(Icons.folder_shared_outlined),
                      label: const Text('Browse Credentials'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context.push('/folders'),
                            icon: const Icon(Icons.folder_outlined),
                            label: const Text('Folders'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context.push('/tags'),
                            icon: const Icon(Icons.label_outline),
                            label: const Text('Tags'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'This is a Sprint 1.4+ placeholder — full Dashboard stats/activity '
                      'and every other screen from docs/planning/high-level-design.md are '
                      'later sprints.',
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
