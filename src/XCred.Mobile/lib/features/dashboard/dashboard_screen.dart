import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/session/org_settings.dart';

/// Placeholder landing screen — the real Dashboard (FR-DASH-01..04, stat cards,
/// expiring-soon list, activity feed) is Sprint 1.3+ scope per sprint-plan.md, not this
/// sprint. This exists to prove the full authenticated loop end-to-end: dio attaches
/// the JWT from [authSessionProvider], the request reaches the real dev backend, and the
/// response is unwrapped through [ApiClient] exactly like any other screen will — and,
/// as of Sprint 1.2, to populate [orgSettingsProvider] (the same place the web app's
/// hardcoded-defaults bug originated, per this session's web fix) and host the
/// Lock Now / Log Out actions until Settings (later sprint) exists.
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
      setState(() => _dashboard = data);
      final orgSettingsJson = data['orgSettings'] as Map<String, dynamic>?;
      if (orgSettingsJson != null) {
        ref
            .read(orgSettingsProvider.notifier)
            .set(OrgSettings.fromJson(orgSettingsJson));
      }
    } catch (e) {
      setState(() => _error = 'Could not load dashboard: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _lockNow() async {
    // Soft lock: clears the in-memory session only. The wrapped key in
    // SecureVaultStorage and the persisted tokens stay put, so the next app open goes
    // to /unlock (fast re-entry), not /login — MOB-SESS-03's distinction from Log Out.
    ref.read(authSessionProvider.notifier).clear();
  }

  Future<void> _logOut() async {
    await ref.read(sessionPersistenceProvider).clear();
    await ref.read(secureVaultStorageProvider).clear();
    ref.invalidate(resumableSessionProvider);
    ref.read(authSessionProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${session?.username ?? ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Lock now',
            onPressed: _lockNow,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: _logOut,
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
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          label: 'Shared With Me',
                          value: '${_dashboard!['sharedWithMe']}',
                        ),
                        const SizedBox(width: 12),
                        _StatCard(label: 'Teams', value: '${_dashboard!['groupCount']}'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'This is a Sprint 1.2 placeholder — full Dashboard, Credentials '
                      'tree, and every other screen from docs/planning/high-level-design.md '
                      'are later sprints.',
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
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
    );
  }
}
