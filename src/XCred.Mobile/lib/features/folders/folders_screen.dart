import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/error_messages.dart';
import '../../core/models/credential_models.dart';
import '../../core/models/folder_tag_models.dart';
import '../../core/providers/core_providers.dart';
import '../../core/providers/vault_providers.dart';
import '../../core/vault/credential_csv.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/selection_app_bar.dart';
import '../../core/widgets/toolbar_icon_button.dart';
import '../credentials/widgets/bulk_assign_sheet.dart';
import '../credentials/widgets/credential_row.dart';

/// MOB-FOLD-01 — nested folder tree, create/rename/delete, member credentials shown via
/// the same [CredentialRow] pattern as the Credentials screen. Mirrors the web app's
/// `FoldersPage.tsx`, including its search box, "Unassigned" section, and multi-select
/// bulk edit (all added to web after this screen's first pass — see FoldersPage.tsx's
/// git history for the reference implementation this ports).
class FoldersScreen extends ConsumerStatefulWidget {
  const FoldersScreen({super.key});

  @override
  ConsumerState<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends ConsumerState<FoldersScreen> {
  final Set<String> _expanded = {};
  final _searchController = TextEditingController();
  String _search = '';
  bool _noPasswordFilter = false;
  bool _expiredFilter = false;
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(CredentialListItem c, Map<String, DecryptedCredentialMeta> decrypted) {
    if (_noPasswordFilter && (decrypted[c.id]?.hasPassword ?? true)) return false;
    if (_expiredFilter && !c.isExpired) return false;
    if (_search.isEmpty) return true;
    final q = _search.toLowerCase();
    final meta = decrypted[c.id];
    if ((meta?.name ?? '').toLowerCase().contains(q)) return true;
    if ((meta?.subtitle ?? '').toLowerCase().contains(q)) return true;
    return c.tags.any((t) => t.name.toLowerCase().contains(q));
  }

  Future<void> _exportCsv(List<CredentialListItem> items, Map<String, DecryptedCredentialMeta> decrypted) async {
    final csv = buildCredentialsCsv(items, decrypted);
    final filename = 'xcred-folders-${DateTime.now().toIso8601String().split('T').first}.csv';
    await ref.read(fileExchangeProvider).saveOrShare(filename, Uint8List.fromList(utf8.encode(csv)), 'text/csv');
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(folderTreeProvider.notifier).refresh(),
      ref.read(vaultProvider.notifier).refresh(),
    ]);
  }

  void _toggleSelect(String id) => setState(() {
        _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id);
      });

  void _selectAllVisible(List<CredentialListItem> visible) => setState(() {
        final allSelected = visible.isNotEmpty && visible.every((c) => _selectedIds.contains(c.id));
        _selectedIds.clear();
        if (!allSelected) _selectedIds.addAll(visible.map((c) => c.id));
      });

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

  /// True if [folder] directly holds a search-matching credential, or any descendant
  /// folder does — a parent stays visible while searching as long as something in its
  /// subtree matches, even if nothing directly in the parent itself does.
  bool _folderSubtreeHasMatch(FolderNode folder, Map<String, List<CredentialListItem>> byFolder) {
    if ((byFolder[folder.id]?.isNotEmpty ?? false)) return true;
    return folder.children.any((child) => _folderSubtreeHasMatch(child, byFolder));
  }

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(folderTreeProvider);
    final vaultAsync = ref.watch(vaultProvider);
    final activeFilter = _search.isNotEmpty || _noPasswordFilter || _expiredFilter;

    final vault = vaultAsync.value;
    final byFolder = <String, List<CredentialListItem>>{};
    final unassigned = <CredentialListItem>[];
    if (vault != null) {
      for (final c in vault.credentials) {
        if (!_matchesSearch(c, vault.decrypted)) continue;
        if (c.folderId != null) {
          (byFolder[c.folderId!] ??= []).add(c);
        } else {
          unassigned.add(c);
        }
      }
    }
    final visibleCredentials = [...byFolder.values.expand((v) => v), ...unassigned];

    return Scaffold(
      appBar: buildSelectionAwareAppBar(
        normalTitle: 'Folders',
        selectedCount: _selectedIds.length,
        onClearSelection: () => setState(_selectedIds.clear),
        onSelectAll: () => _selectAllVisible(visibleCredentials),
        onBulkEdit: () => showBulkAssignSheet(
          context,
          credentialIds: _selectedIds.toList(),
          onApplied: () => setState(_selectedIds.clear),
        ),
      ),
      floatingActionButton: _selectedIds.isEmpty
          ? FloatingActionButton.extended(
              onPressed: _createFolder,
              icon: const Icon(Icons.add),
              label: const Text('New Folder'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.search, size: 20),
                      hintText: 'Search by name, username, or tag…',
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                ToolbarIconButton(
                  icon: Icons.no_encryption_outlined,
                  active: _noPasswordFilter,
                  tooltip: 'Show only credentials missing a password',
                  onPressed: () => setState(() => _noPasswordFilter = !_noPasswordFilter),
                ),
                ToolbarIconButton(
                  icon: Icons.warning_amber_outlined,
                  active: _expiredFilter,
                  tooltip: 'Show only expired credentials',
                  onPressed: () => setState(() => _expiredFilter = !_expiredFilter),
                ),
                ToolbarIconButton(
                  icon: Icons.table_chart_outlined,
                  tooltip: 'Export filtered list to CSV',
                  onPressed: visibleCredentials.isEmpty ? null : () => _exportCsv(visibleCredentials, vault?.decrypted ?? const {}),
                ),
              ],
            ),
          ),
          Expanded(
            child: foldersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState(
                icon: Icons.error_outline,
                message: friendlyErrorMessage(e),
                actionLabel: 'Retry',
                onAction: () => ref.read(folderTreeProvider.notifier).refresh(),
              ),
              data: (tree) {
                if (vault == null) return const Center(child: CircularProgressIndicator());

                if (tree.isEmpty && unassigned.isEmpty) {
                  return EmptyState(
                    icon: Icons.folder_outlined,
                    message: 'No folders yet.',
                    actionLabel: 'Create your first folder',
                    onAction: _createFolder,
                  );
                }
                final visibleTree =
                    tree.where((f) => !activeFilter || _folderSubtreeHasMatch(f, byFolder));
                if (activeFilter && visibleTree.isEmpty && unassigned.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off,
                    message: 'No credentials match your search.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    children: [
                      ..._buildFolderList(tree, 0, byFolder, vault, activeFilter),
                      if (unassigned.isNotEmpty) ...[
                        if (tree.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                            child: Text('UNASSIGNED',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(letterSpacing: 1, color: Theme.of(context).hintColor)),
                          ),
                        for (final cred in unassigned)
                          CredentialRow(
                            cred: cred,
                            decrypted: vault.decrypted[cred.id],
                            showActions: true,
                            selectionMode: _selectedIds.isNotEmpty,
                            selected: _selectedIds.contains(cred.id),
                            onToggleSelect: () => _toggleSelect(cred.id),
                            onLongPress: () => _toggleSelect(cred.id),
                            onTap: () => context.push('/credentials/${cred.id}'),
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFolderList(
    List<FolderNode> folders,
    int depth,
    Map<String, List<CredentialListItem>> byFolder,
    VaultState vault,
    bool activeFilter,
  ) {
    final widgets = <Widget>[];
    for (final folder in folders) {
      if (activeFilter && !_folderSubtreeHasMatch(folder, byFolder)) continue;
      final members = byFolder[folder.id] ?? const <CredentialListItem>[];
      final isOpen = _expanded.contains(folder.id) || activeFilter;
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
            showActions: true,
            selectionMode: _selectedIds.isNotEmpty,
            selected: _selectedIds.contains(cred.id),
            onToggleSelect: () => _toggleSelect(cred.id),
            onLongPress: () => _toggleSelect(cred.id),
            onTap: () => context.push('/credentials/${cred.id}'),
          ));
        }
      }
      if (folder.children.isNotEmpty) {
        widgets.addAll(_buildFolderList(folder.children, depth + 1, byFolder, vault, activeFilter));
      }
    }
    return widgets;
  }
}
