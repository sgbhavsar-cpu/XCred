import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/error_messages.dart';
import '../../core/models/share_models.dart';
import '../../core/providers/share_providers.dart';
import '../../core/vault/credential_type_meta.dart';
import '../../core/widgets/empty_state.dart';

/// MOB-SHARE-01 — "Shared With Me" / "Shared By Me", mirroring the web app's
/// `SharesPage` two-tab layout. Revoke lives only on "Shared By Me" — only the
/// credential owner can revoke (SharesController.cs), recipients can only view.
class SharesScreen extends ConsumerStatefulWidget {
  const SharesScreen({super.key});

  @override
  ConsumerState<SharesScreen> createState() => _SharesScreenState();
}

class _SharesScreenState extends ConsumerState<SharesScreen> {
  @override
  void initState() {
    super.initState();
    // Unlike vaultProvider (invalidated on every mutation elsewhere), these providers
    // aren't tied to anything that would refresh them on their own — a revoke acted on
    // from the "Shared By Me" tab, or simply a different account having logged in since
    // this screen was last open, would otherwise still show whatever was cached from an
    // earlier visit. Refresh both every time this screen opens.
    ref.read(sharedWithMeProvider.notifier).refresh();
    ref.read(sharedByMeProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Shared'),
          bottom: const TabBar(tabs: [Tab(text: 'Shared With Me'), Tab(text: 'Shared By Me')]),
        ),
        body: const TabBarView(
          children: [_SharedWithMeTab(), _SharedByMeTab()],
        ),
      ),
    );
  }
}

String _formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _SharedWithMeTab extends ConsumerWidget {
  const _SharedWithMeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sharedWithMeProvider);
    return RefreshIndicator(
      onRefresh: () => ref.read(sharedWithMeProvider.notifier).refresh(),
      child: async.when(
        data: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.inbox_outlined,
                message: 'Nothing has been shared with you yet.',
              )
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) => _SharedWithMeCard(item: items[i]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: friendlyErrorMessage(e),
          actionLabel: 'Retry',
          onAction: () => ref.read(sharedWithMeProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

class _SharedWithMeCard extends StatelessWidget {
  const _SharedWithMeCard({required this.item});
  final SharedItem item;

  @override
  Widget build(BuildContext context) {
    final s = item.share;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Text(credentialTypeIcon(s.credentialType), style: const TextStyle(fontSize: 24)),
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(credentialTypeLabel(s.credentialType)),
            Text('Shared by ${s.sharedByUsername}', style: const TextStyle(fontSize: 12)),
            if (s.expiresAt != null)
              Text('Expires ${_formatDate(s.expiresAt!)}',
                  style: TextStyle(
                      fontSize: 12, color: s.isExpired ? Theme.of(context).colorScheme.error : null)),
            if (s.untilChanged)
              const Text('Access revokes if the credential is updated', style: TextStyle(fontSize: 12)),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _SharedByMeTab extends ConsumerWidget {
  const _SharedByMeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sharedByMeProvider);
    return RefreshIndicator(
      onRefresh: () => ref.read(sharedByMeProvider.notifier).refresh(),
      child: async.when(
        data: (items) {
          final active = items.where((i) => !i.share.isRevoked && !i.share.isExpired).toList();
          final inactive = items.where((i) => i.share.isRevoked || i.share.isExpired).toList();
          if (active.isEmpty && inactive.isEmpty) {
            return const EmptyState(
              icon: Icons.share_outlined,
              message: "You haven't shared anything yet.",
            );
          }
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text('Active (${active.length})', style: Theme.of(context).textTheme.labelLarge),
              ),
              for (final item in active) _SharedByMeActiveCard(item: item),
              if (inactive.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Revoked / Expired (${inactive.length})',
                      style: Theme.of(context).textTheme.labelLarge),
                ),
                for (final item in inactive) _SharedByMeInactiveRow(item: item),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: friendlyErrorMessage(e),
          actionLabel: 'Retry',
          onAction: () => ref.read(sharedByMeProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

class _SharedByMeActiveCard extends ConsumerWidget {
  const _SharedByMeActiveCard({required this.item});
  final SharedItem item;

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Access?'),
        content: const Text('Revoke this share? The recipient will lose access immediately.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(sharesRepositoryProvider).revoke(item.share.id);
      await ref.read(sharedByMeProvider.notifier).refresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to revoke share.')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = item.share;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Text(credentialTypeIcon(s.credentialType), style: const TextStyle(fontSize: 24)),
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.sharedWithUsername != null
                  ? 'Shared with ${s.sharedWithUsername}'
                  : 'Shared with ${s.sharedWithGroupName ?? 'a team'}',
              style: const TextStyle(fontSize: 12),
            ),
            if (s.expiresAt != null)
              Text('Expires ${_formatDate(s.expiresAt!)}', style: const TextStyle(fontSize: 12)),
          ],
        ),
        isThreeLine: s.expiresAt != null,
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          tooltip: 'Revoke',
          onPressed: () => _revoke(context, ref),
        ),
      ),
    );
  }
}

class _SharedByMeInactiveRow extends StatelessWidget {
  const _SharedByMeInactiveRow({required this.item});
  final SharedItem item;

  @override
  Widget build(BuildContext context) {
    final s = item.share;
    return Opacity(
      opacity: 0.6,
      child: ListTile(
        dense: true,
        leading: Text(credentialTypeIcon(s.credentialType), style: const TextStyle(fontSize: 18)),
        title: Text(item.name),
        subtitle: Text(s.isRevoked ? 'Revoked' : 'Expired', style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
