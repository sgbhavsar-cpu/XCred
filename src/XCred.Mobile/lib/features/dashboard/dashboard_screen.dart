import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';

/// Placeholder landing screen — the real Dashboard (FR-DASH-01..04, stat cards,
/// expiring-soon list, activity feed) is Sprint 1.x scope per sprint-plan.md, not this
/// sprint. This exists only to prove the full authenticated loop end-to-end: dio attaches
/// the JWT from [authSessionProvider], the request reaches the real dev backend, and the
/// response is unwrapped through [ApiClient] exactly like any other screen will.
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
    } catch (e) {
      setState(() => _error = 'Could not load dashboard: $e');
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
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(authSessionProvider.notifier).clear(),
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
                      'This is a Sprint 1.1 placeholder — full Dashboard, Credentials '
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
