import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/share_models.dart';
import '../../core/models/team_models.dart';
import '../../core/providers/core_providers.dart';
import '../../core/providers/share_providers.dart';
import '../../core/providers/team_providers.dart';

/// MOB-TEAM-01 — member list, add/remove member, delete team. Mirrors the web app's
/// `GroupsPage.tsx` expanded-team view.
class TeamDetailScreen extends ConsumerStatefulWidget {
  const TeamDetailScreen({required this.teamId, super.key});
  final String teamId;

  @override
  ConsumerState<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends ConsumerState<TeamDetailScreen> {
  TeamSummary? _team;
  String? _error;
  bool _loading = true;
  bool _busy = false;

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
      final team = await ref.read(teamsRepositoryProvider).getById(widget.teamId);
      if (mounted) setState(() => _team = team);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load team.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Team-scoped admin (per this team's membership row) or a global Admin — matches
  /// GroupsController.cs's `AddMember`/`RemoveMember` authorization exactly.
  bool _canManageMembers() {
    final session = ref.read(authSessionProvider);
    final team = _team;
    if (team == null || session == null) return false;
    return team.isMyRoleAdmin || session.role == 'Admin';
  }

  Future<void> _addMember() async {
    List<UserSummary> users;
    try {
      users = await ref.read(usersRepositoryProvider).getAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to load users.')));
      }
      return;
    }
    if (!mounted) return;
    final existingIds = _team!.members.map((m) => m.userId).toSet();
    final candidates = users.where((u) => !existingIds.contains(u.id)).toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No other users to add.')));
      return;
    }

    final selectedId = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add Member'),
        children: [
          for (final u in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(u.id),
              child: Text('${u.username} (${u.email})'),
            ),
        ],
      ),
    );
    if (selectedId == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(teamsRepositoryProvider).addMember(widget.teamId, selectedId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to add member.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeMember(TeamMember member) async {
    final myUserId = ref.read(authSessionProvider)?.userId;
    final isSelf = member.userId == myUserId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isSelf ? 'Leave Team?' : 'Remove ${member.username}?'),
        content: Text(isSelf
            ? "You'll lose access to anything shared with this team."
            : '${member.username} will lose access to anything shared with this team.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isSelf ? 'Leave' : 'Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(teamsRepositoryProvider).removeMember(widget.teamId, member.userId);
      ref.invalidate(teamsProvider);
      if (isSelf) {
        if (mounted) context.pop();
        return;
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to remove member.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteTeam() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Team?'),
        content: const Text(
            "This can't be undone. Anything shared with this team must be re-shared "
            'individually afterward.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(teamsRepositoryProvider).delete(widget.teamId);
      ref.invalidate(teamsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to delete team.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final team = _team;
    final session = ref.watch(authSessionProvider);
    final isGlobalAdmin = session?.role == 'Admin';
    final canManageMembers = _canManageMembers();

    return Scaffold(
      appBar: AppBar(
        title: Text(_loading ? '' : (team?.name ?? 'Team')),
        actions: [
          // Delete is global-Admin-only server-side (GroupsController.cs), not
          // per-team-admin — gated the same way here rather than showing an action
          // that would just 403 for a team admin who isn't also a global Admin.
          if (team != null && isGlobalAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete team',
              onPressed: _deleteTeam,
            ),
        ],
      ),
      floatingActionButton: (team == null || !canManageMembers)
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : _addMember,
              icon: const Icon(Icons.person_add_alt_outlined),
              label: const Text('Add Member'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : team == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        children: [
                          if (team.description != null && team.description!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(team.description!),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text('MEMBERS (${team.members.length})',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(letterSpacing: 0.5, color: Theme.of(context).hintColor)),
                          ),
                          for (final m in team.members)
                            ListTile(
                              leading: CircleAvatar(child: Text(m.username[0].toUpperCase())),
                              title: Text(m.username),
                              subtitle: Text(m.email),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: (m.isAdmin
                                              ? Theme.of(context).colorScheme.primary
                                              : Theme.of(context).colorScheme.outline)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(m.role, style: const TextStyle(fontSize: 10)),
                                  ),
                                  if (canManageMembers || m.userId == session?.userId)
                                    IconButton(
                                      icon: const Icon(Icons.person_remove_outlined, size: 20),
                                      tooltip: m.userId == session?.userId ? 'Leave' : 'Remove',
                                      onPressed: _busy ? null : () => _removeMember(m),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
    );
  }
}
