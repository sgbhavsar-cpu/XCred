import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/error_messages.dart';
import '../../core/models/credential_models.dart';
import '../../core/providers/core_providers.dart';
import '../../core/providers/sync_providers.dart';
import '../../core/providers/vault_providers.dart';
import '../../core/models/folder_tag_models.dart';
import '../../core/vault/credential_csv.dart';
import '../../core/vault/credential_search.dart';
import '../../core/vault/credential_fields.dart';
import '../../core/vault/credential_type_meta.dart';
import '../../core/widgets/clearable_search_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/option_picker.dart';
import '../../core/widgets/selection_app_bar.dart';
import '../../core/widgets/toolbar_icon_button.dart';
import 'widgets/bulk_actions.dart';
import 'widgets/bulk_assign_sheet.dart';
import 'widgets/credential_row.dart';
import 'widgets/quick_create.dart';

/// MOB-CRED-01 — expandable tree of Credential Groups + an ungrouped section, search,
/// type filter. Mirrors the web app's already-redesigned `CredentialsPage.tsx`.
/// Folder/Tag context filtering (the web page's `?folder=`/`?tag=` query params) is
/// Sprint 1.5 scope — folders/tags don't have their own screens yet.
class CredentialsTreeScreen extends ConsumerStatefulWidget {
  const CredentialsTreeScreen({super.key});

  @override
  ConsumerState<CredentialsTreeScreen> createState() => _CredentialsTreeScreenState();
}

class _CredentialsTreeScreenState extends ConsumerState<CredentialsTreeScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  String? _typeFilter;
  bool _noPasswordFilter = false;
  bool _expiredFilter = false;
  final Set<String> _expanded = {};
  final Set<String> _selectedIds = {};

  void _toggleSelect(String id) => setState(() {
        _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id);
      });

  void _selectAllVisible(List<CredentialListItem> visible) => setState(() {
        final allSelected = visible.isNotEmpty && visible.every((c) => _selectedIds.contains(c.id));
        _selectedIds.clear();
        if (!allSelected) _selectedIds.addAll(visible.map((c) => c.id));
      });

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Search: credential fields always; a matching credential-group or folder name also pulls
  // in every credential inside it, ranked ahead of field-only matches.
  List<String> _tokens = const [];
  Set<String> _matchedGroupIds = const {};
  Set<String> _matchedFolderIds = const {};

  void _prepareSearch(List<CredentialGroupSummary> groups, List<FolderNode> folders) {
    _tokens = tokenizeQuery(_search);
    _matchedGroupIds = {
      for (final g in groups)
        if (searchNameMatches(g.name, _tokens)) g.id,
    };
    _matchedFolderIds = {
      for (final f in flattenFolders(folders))
        if (searchNameMatches(f.indentedName, _tokens)) f.id,
    };
  }

  bool _containerMatch(CredentialListItem c) =>
      (c.credentialGroupId != null && _matchedGroupIds.contains(c.credentialGroupId)) ||
      (c.folderId != null && _matchedFolderIds.contains(c.folderId));

  int _fieldScore(CredentialListItem c, Map<String, DecryptedCredentialMeta> decrypted) {
    final meta = decrypted[c.id];
    return meta == null ? 0 : scoreSearchText(meta.searchText, meta.searchName, _tokens);
  }

  int _rank(CredentialListItem c, Map<String, DecryptedCredentialMeta> decrypted) =>
      (_containerMatch(c) ? 100000 : 0) + _fieldScore(c, decrypted);

  bool _matches(CredentialListItem c, Map<String, DecryptedCredentialMeta> decrypted) {
    if (_typeFilter != null && c.type != _typeFilter) return false;
    if (_noPasswordFilter && (decrypted[c.id]?.hasPassword ?? true)) return false;
    if (_expiredFilter && !c.isExpired) return false;
    if (_tokens.isNotEmpty && _fieldScore(c, decrypted) == 0 && !_containerMatch(c)) return false;
    return true;
  }

  List<CredentialListItem> _filterAndRank(
      List<CredentialListItem> all, Map<String, DecryptedCredentialMeta> decrypted) {
    final out = all.where((c) => _matches(c, decrypted)).toList();
    if (_tokens.isNotEmpty) {
      out.sort((a, b) => _rank(b, decrypted).compareTo(_rank(a, decrypted)));
    }
    return out;
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(vaultProvider.notifier).refresh(),
      ref.read(credentialGroupsProvider.notifier).refresh(),
    ]);
  }

  Future<void> _exportCsv(List<CredentialListItem> filtered, Map<String, DecryptedCredentialMeta> decrypted) async {
    final csv = buildCredentialsCsv(filtered, decrypted);
    final filename = 'xcred-credentials-${DateTime.now().toIso8601String().split('T').first}.csv';
    await ref.read(fileExchangeProvider).saveOrShare(filename, Uint8List.fromList(utf8.encode(csv)), 'text/csv');
  }

  Future<void> _createGroup() => showCreateGroupDialog(context, ref);

  /// Shares every credential in the group (all of them, not just the ones the current search shows).
  void _shareGroup(CredentialGroupSummary group, List<CredentialListItem> visibleMembers) {
    final all = ref.read(vaultProvider).value?.credentials ?? const <CredentialListItem>[];
    final ids = [for (final c in all) if (c.credentialGroupId == group.id) c.id];
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('This group has no credentials to share yet.')));
      return;
    }
    showBulkShareSheet(context, credentialIds: ids, title: group.name, onApplied: () {});
  }

  Future<void> _deleteGroup(CredentialGroupSummary group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${group.name}"?'),
        content: const Text('Its credentials will not be deleted, just unlinked.'),
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
      await ref.read(credentialGroupRepositoryProvider).delete(group.id);
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
    final vaultAsync = ref.watch(vaultProvider);
    final groupsAsync = ref.watch(credentialGroupsProvider);
    final syncState = ref.watch(syncProvider);
    final activeFilter = _search.isNotEmpty || _typeFilter != null || _noPasswordFilter || _expiredFilter;
    _prepareSearch(groupsAsync.value ?? const [], ref.watch(folderTreeProvider).value ?? const []);
    final filtered = vaultAsync.value == null
        ? const <CredentialListItem>[]
        : _filterAndRank(vaultAsync.value!.credentials, vaultAsync.value!.decrypted);

    return Scaffold(
      appBar: buildSelectionAwareAppBar(
        normalTitle: 'Credentials',
        normalActions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'New Credential Group',
            onPressed: _createGroup,
          ),
        ],
        selectedCount: _selectedIds.length,
        onClearSelection: () => setState(_selectedIds.clear),
        onSelectAll: () => _selectAllVisible(filtered),
        onShare: () => showBulkShareSheet(
          context,
          credentialIds: _selectedIds.toList(),
          onApplied: () => setState(_selectedIds.clear),
        ),
        onExportCsv: () => bulkExportSelected(context, ref, _selectedIds.toList()),
        onDelete: () => bulkDeleteSelected(
            context, ref, _selectedIds.toList(), () => setState(_selectedIds.clear)),
        onBulkEdit: () => showBulkAssignSheet(
          context,
          credentialIds: _selectedIds.toList(),
          onApplied: () => setState(_selectedIds.clear),
        ),
      ),
      floatingActionButton: _selectedIds.isNotEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final saved = await context.push<bool>('/credentials/new');
                if (saved == true) _refresh();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Credential'),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ClearableSearchField(
              controller: _searchController,
              hintText: 'Search name, IP, user, notes, tags…',
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Row(
              children: [
                _TypeFilterButton(
                  value: _typeFilter,
                  onChanged: (v) => setState(() => _typeFilter = v),
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
                  onPressed: filtered.isEmpty ? null : () => _exportCsv(filtered, vaultAsync.value!.decrypted),
                ),
                if (_typeFilter != null)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(credentialTypeLabel(_typeFilter!),
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ),
              ],
            ),
          ),
          if (vaultAsync.value?.offline == true) const _OfflineBanner(),
          if (syncState.conflicts.isNotEmpty) _SyncConflictBanner(conflicts: syncState.conflicts),
          Expanded(
            child: (vaultAsync.isLoading && !vaultAsync.hasValue) || groupsAsync.isLoading
                ? const Center(child: CircularProgressIndicator())
                : vaultAsync.hasError
                    ? EmptyState(
                        icon: Icons.error_outline,
                        message: friendlyErrorMessage(vaultAsync.error!),
                        actionLabel: 'Retry',
                        onAction: _refresh,
                      )
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: _buildList(
                          vaultAsync.value!,
                          groupsAsync.value ?? const [],
                          activeFilter,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    VaultState vault,
    List<CredentialGroupSummary> groups,
    bool activeFilter,
  ) {
    final filtered = _filterAndRank(vault.credentials, vault.decrypted);

    final byGroup = <String, List<CredentialListItem>>{};
    final ungrouped = <CredentialListItem>[];
    for (final c in filtered) {
      final gid = c.credentialGroupId;
      if (gid != null) {
        (byGroup[gid] ??= []).add(c);
      } else {
        ungrouped.add(c);
      }
    }

    int groupRank(CredentialGroupSummary g) =>
        (_matchedGroupIds.contains(g.id) ? 100000 : 0) +
        (byGroup[g.id] ?? const <CredentialListItem>[])
            .fold<int>(0, (m, c) => _rank(c, vault.decrypted) > m ? _rank(c, vault.decrypted) : m);
    final visibleGroups = groups
        .where((g) =>
            !activeFilter || (byGroup[g.id]?.isNotEmpty ?? false) || _matchedGroupIds.contains(g.id))
        .toList()
      ..sort((a, b) {
        if (_tokens.isNotEmpty) {
          final byRank = groupRank(b).compareTo(groupRank(a));
          if (byRank != 0) return byRank;
        }
        return a.name.compareTo(b.name);
      });

    if (vault.credentials.isEmpty && groups.isEmpty) {
      return const EmptyState(icon: Icons.key_outlined, message: 'No credentials yet.');
    }
    if (visibleGroups.isEmpty && ungrouped.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        message:
            activeFilter ? 'No credentials match your search.' : 'No credentials yet.',
      );
    }

    return ListView(
      children: [
        for (final group in visibleGroups) ..._buildGroupSection(group, byGroup, vault, activeFilter),
        if (ungrouped.isNotEmpty) ...[
          if (visibleGroups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('UNGROUPED',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(letterSpacing: 1, color: Theme.of(context).hintColor)),
            ),
          for (final cred in ungrouped)
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
    );
  }

  List<Widget> _buildGroupSection(
    CredentialGroupSummary group,
    Map<String, List<CredentialListItem>> byGroup,
    VaultState vault,
    bool activeFilter,
  ) {
    final members = byGroup[group.id] ?? const <CredentialListItem>[];
    final isOpen = _expanded.contains(group.id) || activeFilter;
    return [
      ListTile(
        leading: Text(group.icon, style: const TextStyle(fontSize: 22)),
        title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${members.length} credential${members.length == 1 ? '' : 's'}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              key: ValueKey('group_menu_${group.id}'),
              tooltip: 'Group actions',
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (v) async {
                switch (v) {
                  case 'add':
                    final saved = await context.push<bool>('/credentials/new?groupId=${group.id}');
                    if (saved == true) _refresh();
                  case 'share':
                    _shareGroup(group, members);
                  case 'manage':
                    await context.push('/credential-groups/${group.id}');
                    _refresh();
                  case 'delete':
                    _deleteGroup(group);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'add', child: ListTile(leading: Icon(Icons.add), title: Text('Add credential'))),
                PopupMenuItem(
                    value: 'share',
                    child: ListTile(leading: Icon(Icons.share_outlined), title: Text('Share all in this group'))),
                PopupMenuItem(
                    value: 'manage',
                    child: ListTile(leading: Icon(Icons.settings_outlined), title: Text('Manage group'))),
                PopupMenuItem(
                    value: 'delete',
                    child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete group'))),
              ],
            ),
            Icon(isOpen ? Icons.expand_less : Icons.expand_more),
          ],
        ),
        onTap: () => setState(() {
          _expanded.contains(group.id) ? _expanded.remove(group.id) : _expanded.add(group.id);
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

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        'Offline — showing last synced data',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}

/// MOB-SYNC-02 — surfaces flush failures caused by the server's copy changing while a
/// mutation was queued offline (requirements §6.3's "visible warning"). Each conflict
/// stays queued (not auto-applied, not silently dropped) until the user explicitly
/// discards their local edit here.
class _SyncConflictBanner extends ConsumerWidget {
  const _SyncConflictBanner({required this.conflicts});
  final List<PendingMutationConflict> conflicts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.errorContainer,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 18, color: Theme.of(context).colorScheme.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sync conflict: changed elsewhere while you were offline. '
                  'Your local edit was not applied.',
                  style:
                      TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onErrorContainer),
                ),
              ),
            ],
          ),
          for (final c in conflicts)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 26),
              child: Row(
                children: [
                  Expanded(
                    child: Text(c.entityLabel,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onErrorContainer)),
                  ),
                  TextButton(
                    onPressed: () => ref.read(syncProvider.notifier).discardConflict(c.mutationId),
                    child: const Text('Discard my change'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TypeFilterButton extends StatelessWidget {
  const _TypeFilterButton({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('type_filter'),
      tooltip: 'Filter by type',
      icon: Icon(Icons.filter_list,
          color: value != null ? Theme.of(context).colorScheme.primary : null),
      onPressed: () async {
        final picked = await showOptionPicker<String?>(
          context,
          title: 'Filter by type',
          selected: value,
          options: [
            const PickOption<String?>(value: null, label: 'All Types'),
            for (final type in kCredentialTypes)
              PickOption<String?>(
                  value: type,
                  label: credentialTypeLabel(type),
                  leading: Text(credentialTypeIcon(type), style: const TextStyle(fontSize: 18))),
          ],
        );
        if (picked != null) onChanged(picked.value);
      },
    );
  }
}
