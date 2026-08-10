import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/error_messages.dart';
import '../../core/models/credential_models.dart';
import '../../core/models/folder_tag_models.dart';
import '../../core/providers/vault_providers.dart';
import '../../core/widgets/empty_state.dart';
import '../credentials/widgets/credential_row.dart';

const _kPresetColors = [
  '#6366f1', '#3b82f6', '#10b981', '#f59e0b', '#ef4444',
  '#8b5cf6', '#ec4899', '#14b8a6', '#f97316', '#64748b',
];

Color _hexToColor(String hex) =>
    Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));

/// MOB-TAG-01 — flat tag list, create/rename/recolor/delete, member credentials shown
/// via the same [CredentialRow] pattern as the Credentials screen. Mirrors the web
/// app's `TagsPage.tsx`.
class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  final Set<String> _expanded = {};

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(tagListProvider.notifier).refresh(),
      ref.read(vaultProvider.notifier).refresh(),
    ]);
  }

  Future<void> _createTag() async {
    final result = await _showTagEditor(name: '', color: _kPresetColors[0], title: 'New Tag');
    if (result == null) return;
    try {
      await ref.read(tagRepositoryProvider).create(name: result.$1, color: result.$2);
      await ref.read(tagListProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to create tag.')));
      }
    }
  }

  Future<void> _editTag(TagSummary tag) async {
    final result =
        await _showTagEditor(name: tag.name, color: tag.color, title: 'Edit Tag');
    if (result == null) return;
    try {
      await ref.read(tagRepositoryProvider).update(tag.id, name: result.$1, color: result.$2);
      await ref.read(tagListProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to update tag.')));
      }
    }
  }

  Future<(String, String)?> _showTagEditor({
    required String name,
    required String color,
    required String title,
  }) {
    final nameController = TextEditingController(text: name);
    var selectedColor = color;
    return showDialog<(String, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final c in _kPresetColors)
                    GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = c),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: _hexToColor(c),
                        child: selectedColor == c
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Tag name'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.of(context)
                  .pop((nameController.text.trim(), selectedColor)),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTag(TagSummary tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tag?'),
        content: const Text('It will be removed from all credentials.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
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
      await ref.read(tagRepositoryProvider).delete(tag.id);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to delete.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagListProvider);
    final vaultAsync = ref.watch(vaultProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tags')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createTag,
        icon: const Icon(Icons.add),
        label: const Text('New Tag'),
      ),
      body: tagsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: friendlyErrorMessage(e),
          actionLabel: 'Retry',
          onAction: () => ref.read(tagListProvider.notifier).refresh(),
        ),
        data: (tags) {
          final vault = vaultAsync.value;
          if (vault == null) return const Center(child: CircularProgressIndicator());

          final byTag = <String, List<CredentialListItem>>{};
          for (final c in vault.credentials) {
            for (final t in c.tags) {
              (byTag[t.id] ??= []).add(c);
            }
          }

          if (tags.isEmpty) {
            return EmptyState(
              icon: Icons.label_outline,
              message: 'No tags yet.',
              actionLabel: 'Create your first tag',
              onAction: _createTag,
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              children: [
                for (final tag in tags) ..._buildTagSection(tag, byTag, vault),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildTagSection(
    TagSummary tag,
    Map<String, List<CredentialListItem>> byTag,
    VaultState vault,
  ) {
    final members = byTag[tag.id] ?? const <CredentialListItem>[];
    final isOpen = _expanded.contains(tag.id);
    return [
      ListTile(
        leading: CircleAvatar(radius: 8, backgroundColor: _hexToColor(tag.color)),
        title: Text(tag.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(members.isEmpty ? 'No credentials' : '${members.length} credentials'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add, size: 18),
              tooltip: 'Add credential with this tag',
              onPressed: () async {
                final saved = await context.push<bool>('/credentials/new?tagId=${tag.id}');
                if (saved == true) _refresh();
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Edit',
              onPressed: () => _editTag(tag),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Delete',
              onPressed: () => _deleteTag(tag),
            ),
            Icon(isOpen ? Icons.expand_less : Icons.expand_more),
          ],
        ),
        onTap: () => setState(() {
          _expanded.contains(tag.id) ? _expanded.remove(tag.id) : _expanded.add(tag.id);
        }),
      ),
      if (isOpen)
        for (final cred in members)
          CredentialRow(
            cred: cred,
            decrypted: vault.decrypted[cred.id],
            indent: true,
            onTap: () => context.push('/credentials/${cred.id}'),
          ),
    ];
  }
}
