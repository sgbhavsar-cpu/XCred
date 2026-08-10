import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/error_messages.dart';
import '../../core/models/admin_models.dart';
import '../../core/providers/admin_providers.dart';
import '../../core/providers/core_providers.dart';
import '../../core/widgets/empty_state.dart';

/// MOB-ADMIN-01/02/03 — Users (role change, activate/deactivate), Pending approval,
/// and Audit Log with real filters/pagination. The whole backend controller is
/// global-Admin-gated; the route to this screen (app_router.dart) is reachable
/// regardless, but every action here 403s for a non-admin caller — matching this
/// project's established pattern (e.g. team_detail_screen.dart) of gating destructive
/// actions in the UI rather than only relying on the server's error.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Users'), Tab(text: 'Pending'), Tab(text: 'Audit Log')],
          ),
        ),
        body: const TabBarView(children: [_UsersTab(), _PendingTab(), _AuditLogTab()]),
      ),
    );
  }
}

String _formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _formatDateTime(DateTime d) =>
    '${_formatDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

Widget _statusPill(BuildContext context, AdminUserSummary u) {
  final String label;
  final Color color;
  if (!u.isApproved) {
    label = 'Pending';
    color = Colors.amber.shade700;
  } else if (!u.isActive) {
    label = 'Inactive';
    color = Theme.of(context).colorScheme.error;
  } else {
    label = 'Active';
    color = Colors.green.shade700;
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration:
        BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
    child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );
}

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  String? _busyUserId;

  Future<void> _changeRole(AdminUserSummary user, String newRole) async {
    if (newRole == user.role) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Change ${user.username}'s Role?"),
        content: Text('Change role from ${user.role} to $newRole?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true), child: const Text('Change')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyUserId = user.id);
    try {
      await ref.read(adminRepositoryProvider).setRole(user.id, newRole);
      await ref.read(adminUsersProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to change role.')));
      }
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  Future<void> _toggleActive(AdminUserSummary user) async {
    final activating = !user.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(activating ? 'Activate ${user.username}?' : 'Deactivate ${user.username}?'),
        content: Text(activating
            ? 'They will be able to log in again.'
            : 'They will be signed out and unable to log in until reactivated.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: activating
                ? null
                : FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(activating ? 'Activate' : 'Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyUserId = user.id);
    try {
      if (activating) {
        await ref.read(adminRepositoryProvider).activateUser(user.id);
      } else {
        await ref.read(adminRepositoryProvider).deactivateUser(user.id);
      }
      await ref.read(adminUsersProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(activating ? 'Failed to activate user.' : 'Failed to deactivate user.')));
      }
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUserId = ref.watch(authSessionProvider)?.userId;
    final usersAsync = ref.watch(adminUsersProvider);
    return RefreshIndicator(
      onRefresh: () => ref.read(adminUsersProvider.notifier).refresh(),
      child: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: friendlyErrorMessage(e),
          actionLabel: 'Retry',
          onAction: () => ref.read(adminUsersProvider.notifier).refresh(),
        ),
        data: (users) => users.isEmpty
                  ? const EmptyState(icon: Icons.people_outline, message: 'No users found.')
                  : ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, i) {
                        final u = users[i];
                        final busy = _busyUserId == u.id;
                        final isSelf = u.id == myUserId;
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(u.username,
                                              style: const TextStyle(fontWeight: FontWeight.w600)),
                                          Text(u.email, style: const TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    _statusPill(context, u),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        key: ValueKey('role_${u.id}'),
                                        initialValue: u.role,
                                        isExpanded: true,
                                        decoration:
                                            const InputDecoration(labelText: 'Role', isDense: true),
                                        items: const [
                                          DropdownMenuItem(value: 'User', child: Text('User')),
                                          DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                                        ],
                                        onChanged: busy
                                            ? null
                                            : (v) => v == null ? null : _changeRole(u, v),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (!isSelf)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: OutlinedButton(
                                          onPressed: busy ? null : () => _toggleActive(u),
                                          style: u.isActive
                                              ? OutlinedButton.styleFrom(
                                                  foregroundColor: Theme.of(context).colorScheme.error)
                                              : null,
                                          child: Text(u.isActive ? 'Deactivate' : 'Activate'),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      ),
    );
  }
}

class _PendingTab extends ConsumerStatefulWidget {
  const _PendingTab();

  @override
  ConsumerState<_PendingTab> createState() => _PendingTabState();
}

class _PendingTabState extends ConsumerState<_PendingTab> {
  String? _busyUserId;

  Future<void> _approve(AdminUserSummary user) async {
    setState(() => _busyUserId = user.id);
    try {
      await ref.read(adminRepositoryProvider).approveUser(user.id);
      await ref.read(adminUsersProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to approve user.')));
      }
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);
    return RefreshIndicator(
      onRefresh: () => ref.read(adminUsersProvider.notifier).refresh(),
      child: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: friendlyErrorMessage(e),
          actionLabel: 'Retry',
          onAction: () => ref.read(adminUsersProvider.notifier).refresh(),
        ),
        data: (users) {
          final pending = users.where((u) => !u.isApproved).toList();
          if (pending.isEmpty) {
            return const EmptyState(
                icon: Icons.check_circle_outline, message: 'No pending approvals.');
          }
          return ListView.builder(
            itemCount: pending.length,
            itemBuilder: (context, i) {
              final u = pending[i];
              final busy = _busyUserId == u.id;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(u.username, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${u.email}\nRegistered ${_formatDate(u.createdAt)}'),
                  isThreeLine: true,
                  trailing: FilledButton(
                    onPressed: busy ? null : () => _approve(u),
                    child: const Text('Approve'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AuditLogTab extends ConsumerStatefulWidget {
  const _AuditLogTab();

  @override
  ConsumerState<_AuditLogTab> createState() => _AuditLogTabState();
}

class _AuditLogTabState extends ConsumerState<_AuditLogTab> {
  PagedAuditLog? _result;
  bool _loading = true;
  Object? _error;
  int _page = 1;
  String? _actionFilter;
  String? _userIdFilter;
  DateTime? _from;
  DateTime? _to;

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
      final result = await ref.read(adminRepositoryProvider).getAuditLog(
            page: _page,
            userId: _userIdFilter,
            action: _actionFilter,
            from: _from,
            to: _to,
          );
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setActionFilter(String? action) {
    setState(() {
      _actionFilter = action;
      _page = 1;
    });
    _load();
  }

  void _setUserFilter(String? userId) {
    setState(() {
      _userIdFilter = userId;
      _page = 1;
    });
    _load();
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _from = picked;
      _page = 1;
    });
    _load();
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      // Inclusive of the whole selected day.
      _to = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      _page = 1;
    });
    _load();
  }

  void _clearFilters() {
    setState(() {
      _actionFilter = null;
      _userIdFilter = null;
      _from = null;
      _to = null;
      _page = 1;
    });
    _load();
  }

  void _nextPage() {
    final result = _result;
    if (result == null || _page >= result.totalPages) return;
    setState(() => _page++);
    _load();
  }

  void _prevPage() {
    if (_page <= 1) return;
    setState(() => _page--);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final users = ref.watch(adminUsersProvider).value ?? const <AdminUserSummary>[];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _actionFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Action', isDense: true),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Any action')),
                        for (final a in kAuditActions)
                          DropdownMenuItem<String?>(
                              value: a, child: Text(a, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: _setActionFilter,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _userIdFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'User', isDense: true),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Any user')),
                        for (final u in users)
                          DropdownMenuItem<String?>(
                              value: u.id, child: Text(u.username, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: _setUserFilter,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickFrom,
                      child: Text(_from == null ? 'From date' : _formatDate(_from!)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickTo,
                      child: Text(_to == null ? 'To date' : _formatDate(_to!)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(onPressed: _clearFilters, child: const Text('Clear')),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? EmptyState(
                      icon: Icons.error_outline,
                      message: friendlyErrorMessage(_error!),
                      actionLabel: 'Retry',
                      onAction: _load,
                    )
                  : (result == null || result.items.isEmpty)
                      ? const EmptyState(
                          icon: Icons.receipt_long_outlined,
                          message: 'No matching audit log entries.',
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            itemCount: result.items.length,
                            itemBuilder: (context, i) {
                              final e = result.items[i];
                              return ListTile(
                                dense: true,
                                title: Text(e.action,
                                    style:
                                        const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                subtitle: Text(
                                  [
                                    _formatDateTime(e.timestamp),
                                    e.username ?? 'system',
                                    if (e.resourceType != null) e.resourceType!,
                                    if (e.ipAddress != null) e.ipAddress!,
                                  ].join(' · '),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              );
                            },
                          ),
                        ),
        ),
        if (result != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous page',
                  onPressed: _page > 1 ? _prevPage : null,
                ),
                Text('Page $_page of ${result.totalPages == 0 ? 1 : result.totalPages} '
                    '(${result.total} total)'),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next page',
                  onPressed: _page < result.totalPages ? _nextPage : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
