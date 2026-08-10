import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/error_messages.dart';
import '../../core/models/team_models.dart';
import '../../core/providers/team_providers.dart';
import '../../core/widgets/empty_state.dart';

/// MOB-TEAM-01 — list of teams the caller is a member of (there is no "browse all
/// teams", even for a global Admin — GroupsController.cs's `GetAll` scopes strictly by
/// membership). Mirrors the web app's `GroupsPage.tsx`, minus its inline-accordion
/// layout — mobile navigates to a separate detail screen instead, matching this app's
/// existing Credential Group screen pair.
class TeamsScreen extends ConsumerStatefulWidget {
  const TeamsScreen({super.key});

  @override
  ConsumerState<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends ConsumerState<TeamsScreen> {
  Future<void> _createTeam() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Team'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Team name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created != true || nameController.text.trim().isEmpty) return;
    try {
      await ref.read(teamsRepositoryProvider).create(
            name: nameController.text.trim(),
            description: descController.text.trim().isEmpty ? null : descController.text.trim(),
          );
      await ref.read(teamsProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to create team.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(teamsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Teams')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createTeam,
        icon: const Icon(Icons.add),
        label: const Text('New Team'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(teamsProvider.notifier).refresh(),
        child: async.when(
          data: (teams) => teams.isEmpty
              ? const EmptyState(
                  icon: Icons.groups_outlined,
                  message: "You're not on any teams yet.",
                )
              : ListView.builder(
                  itemCount: teams.length,
                  itemBuilder: (context, i) => _TeamCard(team: teams[i]),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(
            icon: Icons.error_outline,
            message: friendlyErrorMessage(e),
            actionLabel: 'Retry',
            onAction: () => ref.read(teamsProvider.notifier).refresh(),
          ),
        ),
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team});
  final TeamSummary team;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.groups_outlined, size: 28),
        title: Row(
          children: [
            Flexible(
                child: Text(team.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: (team.isMyRoleAdmin
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(team.myRole, style: const TextStyle(fontSize: 10)),
            ),
          ],
        ),
        subtitle: Text(
          [
            '${team.memberCount} member${team.memberCount == 1 ? '' : 's'}',
            if (team.description != null && team.description!.isNotEmpty) team.description!,
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => context.push('/teams/${team.id}'),
      ),
    );
  }
}
