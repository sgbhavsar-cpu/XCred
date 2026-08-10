import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/error_messages.dart';
import '../../core/models/credential_models.dart';
import '../../core/models/folder_tag_models.dart';
import '../../core/providers/vault_providers.dart';
import '../../core/widgets/empty_state.dart';
import '../credentials/widgets/credential_row.dart';

/// MOB-FOLD-01 — nested folder tree, create/rename/delete, member credentials shown via
/// the same [CredentialRow] pattern as the Credentials screen. Mirrors the web app's
/// `FoldersPage.tsx`.
class FoldersScreen extends ConsumerStatefulWidget {
  const FoldersScreen({super.key});

  @override
  ConsumerState<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends ConsumerState<FoldersScreen> {
  final Set<String> _expanded = {};

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(folderTreeProvider.notifier).refresh(),
      ref.read(vaultProvider.notifier).refresh(),
    ]);
  }

  Future<void> _createFolder() async {
    final tree = ref.read(folderTreeProvider).value ?? const [];
    final flat = flattenFolders(tree);
    final nameController = TextEditingController();
    String? parentId;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Folder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Folder name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: parentId,
                decoration: const InputDecoration(labelText: 'Parent folder (optional)'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('None (top-level)')),
                  for (final f in flat)
                    DropdownMenuItem<String?>(value: f.id, child: Text(f.indentedName)),
                ],
                onChanged: (v) => setDialogState(() => parentId = v),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (created != true || nameController.text.trim().isEmpty) return;
    try {
      await ref
          .read(folderRepositoryProvider)
          .create(name: nameController.text.trim(), parentFolderId: parentId);
      await ref.read(folderTreeProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to create folder.')));
      }
    }
  }

  Future<void> _renameFolder(FolderNode folder) async {
    final nameController = TextEditingController(text: folder.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(controller: nameController, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(nameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    try {
      await ref.read(folderRepositoryProvider).rename(
            folder.id,
            newName,
            parentFolderId: folder.parentFolderId,
          );
      await ref.read(folderTreeProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to rename.')));
      }
    }
  }

  Future<void> _deleteFolder(FolderNode folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder?'),
        content: const Text('Credentials inside will be moved to "No Folder".'),
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
      await ref.read(folderRepositoryProvider).delete(folder.id);
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
    final foldersAsync = ref.watch(folderTreeProvider);
    final vaultAsync = ref.watch(vaultProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Folders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createFolder,
        icon: const Icon(Icons.add),
        label: const Text('New Folder'),
      ),
      body: foldersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: friendlyErrorMessage(e),
          actionLabel: 'Retry',
          onAction: () => ref.read(folderTreeProvider.notifier).refresh(),
        ),
        data: (tree) {
          final vault = vaultAsync.value;
          if (vault == null) return const Center(child: CircularProgressIndicator());

          final byFolder = <String, List<CredentialListItem>>{};
          for (final c in vault.credentials) {
            if (c.folderId != null) (byFolder[c.folderId!] ??= []).add(c);
          }

          if (tree.isEmpty) {
            return EmptyState(
              icon: Icons.folder_outlined,
              message: 'No folders yet.',
              actionLabel: 'Create your first folder',
              onAction: _createFolder,
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              children: _buildFolderList(tree, 0, byFolder, vault),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildFolderList(
    List<FolderNode> folders,
    int depth,
    Map<String, List<CredentialListItem>> byFolder,
    VaultState vault,
  ) {
    final widgets = <Widget>[];
    for (final folder in folders) {
      final members = byFolder[folder.id] ?? const <CredentialListItem>[];
      final isOpen = _expanded.contains(folder.id);
      widgets.add(ListTile(
        contentPadding: EdgeInsets.only(left: 16.0 + depth * 20, right: 8),
        leading: const Icon(Icons.folder_outlined, color: Colors.amber),
        title: Text(folder.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(members.isEmpty ? 'Empty' : '${members.length} credentials'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add, size: 18),
              tooltip: 'Add credential to this folder',
              onPressed: () async {
                final saved =
                    await context.push<bool>('/credentials/new?folderId=${folder.id}');
                if (saved == true) _refresh();
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Rename',
              onPressed: () => _renameFolder(folder),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Delete',
              onPressed: () => _deleteFolder(folder),
            ),
            Icon(isOpen ? Icons.expand_less : Icons.expand_more),
          ],
        ),
        onTap: () => setState(() {
          _expanded.contains(folder.id) ? _expanded.remove(folder.id) : _expanded.add(folder.id);
        }),
      ));
      if (isOpen) {
        for (final cred in members) {
          widgets.add(CredentialRow(
            cred: cred,
            decrypted: vault.decrypted[cred.id],
            indent: true,
            onTap: () => context.push('/credentials/${cred.id}'),
          ));
        }
      }
      if (folder.children.isNotEmpty) {
        widgets.addAll(_buildFolderList(folder.children, depth + 1, byFolder, vault));
      }
    }
    return widgets;
  }
}
