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
import '../credentials/widgets/bulk_tags_sheet.dart';
import '../credentials/widgets/credential_row.dart';

const _kPresetColors = [
  '#6366f1', '#3b82f6', '#10b981', '#f59e0b', '#ef4444',
  '#8b5cf6', '#ec4899', '#14b8a6', '#f97316', '#64748b',
];

Color _hexToColor(String hex) =>
    Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));

/// MOB-TAG-01 — flat tag list, create/rename/recolor/delete, member credentials shown
/// via the same [CredentialRow] pattern as the Credentials screen. Mirrors the web app's
/// `TagsPage.tsx`, including its search box, "Untagged" section, and multi-select bulk
/// tag editing (added to web after this screen's first pass).
class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
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
    return (meta?.name ?? '').toLowerCase().contains(q) ||
        (meta?.subtitle ?? '').toLowerCase().contains(q);
  }

  Future<void> _exportCsv(List<CredentialListItem> items, Map<String, DecryptedCredentialMeta> decrypted) async {
    final csv = buildCredentialsCsv(items, decrypted);
    final filename = 'xcred-tags-${DateTime.now().toIso8601String().split('T').first}.csv';
    await ref.read(fileExchangeProvider).saveOrShare(filename, Uint8List.fromList(utf8.encode(csv)), 'text/csv');
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(tagListProvider.notifier).refresh(),
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
    final activeFilter = _search.isNotEmpty || _noPasswordFilter || _expiredFilter;

    final vault = vaultAsync.value;
    final byTag = <String, List<CredentialListItem>>{};
    final untagged = <CredentialListItem>[];
    if (vault != null) {
      for (final c in vault.credentials) {
        if (!_matchesSearch(c, vault.decrypted)) continue;
        if (c.tags.isEmpty) {
          untagged.add(c);
          continue;
        }
        for (final t in c.tags) {
          (byTag[t.id] ??= []).add(c);
        }
      }
    }
    final tagsValue = tagsAsync.value ?? const <TagSummary>[];
    final visibleTags =
        tagsValue.where((t) => !activeFilter || (byTag[t.id]?.isNotEmpty ?? false)).toList();
    final visibleCredentials = [...byTag.values.expand((v) => v), ...untagged];

    return Scaffold(
      appBar: buildSelectionAwareAppBar(
        normalTitle: 'Tags',
        selectedCount: _selectedIds.length,
        onClearSelection: () => setState(_selectedIds.clear),
        onSelectAll: () => _selectAllVisible(visibleCredentials),
        onBulkEdit: () => showBulkTagsSheet(
          context,
          credentialIds: _selectedIds.toList(),
          tags: tagsValue,
          onApplied: () => setState(_selectedIds.clear),
        ),
      ),
      floatingActionButton: _selectedIds.isEmpty
          ? FloatingActionButton.extended(
              onPressed: _createTag,
              icon: const Icon(Icons.add),
              label: const Text('New Tag'),
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
                      hintText: 'Search by name or username…',
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
            child: tagsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState(
                icon: Icons.error_outline,
                message: friendlyErrorMessage(e),
                actionLabel: 'Retry',
                onAction: () => ref.read(tagListProvider.notifier).refresh(),
              ),
              data: (tags) {
                if (vault == null) return const Center(child: CircularProgressIndicator());

                // A tagless account can still have credentials to show under Untagged, so
                // this must require there being nothing at all to show — not just zero tags
                // — or those credentials (and the toolbar's filter buttons) would be
                // unreachable until the user creates a tag first. Same bug, same fix, as the
                // web app's TagsPage.tsx (tags.length === 0 → tags.length === 0 && untagged
                // .length === 0).
                if (tags.isEmpty && untagged.isEmpty) {
                  return EmptyState(
                    icon: Icons.label_outline,
                    message: 'No tags yet.',
                    actionLabel: 'Create your first tag',
                    onAction: _createTag,
                  );
                }
                if (activeFilter && visibleTags.isEmpty && untagged.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off,
                    message: 'No credentials match your search.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    children: [
                      for (final tag in visibleTags) ..._buildTagSection(tag, byTag, vault, activeFilter),
                      if (untagged.isNotEmpty) ...[
                        if (tagsValue.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                            child: Text('UNTAGGED',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(letterSpacing: 1, color: Theme.of(context).hintColor)),
                          ),
                        for (final cred in untagged)
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

  List<Widget> _buildTagSection(
    TagSummary tag,
    Map<String, List<CredentialListItem>> byTag,
    VaultState vault,
    bool activeFilter,
  ) {
    final members = byTag[tag.id] ?? const <CredentialListItem>[];
    final isOpen = _expanded.contains(tag.id) || activeFilter;
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
            showActions: true,
            selectionMode: _selectedIds.isNotEmpty,
            selected: _selectedIds.contains(cred.id),
            onToggleSelect: () => _toggleSelect(cred.id),
            onLongPress: () => _toggleSelect(cred.id),
            onTap: () => context.push('/credentials/${cred.id}'),
          ),
    ];
  }
}
