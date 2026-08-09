import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/credential_models.dart';
import '../../core/providers/vault_providers.dart';
import '../../core/vault/credential_fields.dart';
import '../../core/vault/credential_type_meta.dart';
import 'widgets/credential_row.dart';

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
  final Set<String> _expanded = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(CredentialListItem c, Map<String, DecryptedCredentialMeta> decrypted) {
    if (_typeFilter != null && c.type != _typeFilter) return false;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      final meta = decrypted[c.id];
      final nameMatch = (meta?.name ?? '').toLowerCase().contains(q);
      final subtitleMatch = (meta?.subtitle ?? '').toLowerCase().contains(q);
      final tagMatch = c.tags.any((t) => t.name.toLowerCase().contains(q));
      if (!nameMatch && !subtitleMatch && !tagMatch) return false;
    }
    return true;
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(vaultProvider.notifier).refresh(),
      ref.read(credentialGroupsProvider.notifier).refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final vaultAsync = ref.watch(vaultProvider);
    final groupsAsync = ref.watch(credentialGroupsProvider);
    final activeFilter = _search.isNotEmpty || _typeFilter != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Credentials')),
      floatingActionButton: FloatingActionButton.extended(
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
                const SizedBox(width: 8),
                _TypeFilterButton(
                  value: _typeFilter,
                  onChanged: (v) => setState(() => _typeFilter = v),
                ),
              ],
            ),
          ),
          if (vaultAsync.value?.offline == true) const _OfflineBanner(),
          Expanded(
            child: (vaultAsync.isLoading && !vaultAsync.hasValue) || groupsAsync.isLoading
                ? const Center(child: CircularProgressIndicator())
                : vaultAsync.hasError
                    ? Center(child: Text('Failed to load credentials: ${vaultAsync.error}'))
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
    final filtered = vault.credentials.where((c) => _matches(c, vault.decrypted)).toList();

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

    final visibleGroups = groups
        .where((g) => !activeFilter || (byGroup[g.id]?.isNotEmpty ?? false))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (vault.credentials.isEmpty && groups.isEmpty) {
      return _emptyState('No credentials yet.');
    }
    if (visibleGroups.isEmpty && ungrouped.isEmpty) {
      return _emptyState(
          activeFilter ? 'No credentials match your search.' : 'No credentials yet.');
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
        trailing: Icon(isOpen ? Icons.expand_less : Icons.expand_more),
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
            onTap: () => context.push('/credentials/${cred.id}'),
          ),
    ];
  }

  Widget _emptyState(String message) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(message, textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
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

class _TypeFilterButton extends StatelessWidget {
  const _TypeFilterButton({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      tooltip: 'Filter by type',
      icon: Icon(Icons.filter_list,
          color: value != null ? Theme.of(context).colorScheme.primary : null),
      onSelected: onChanged,
      itemBuilder: (context) => [
        const PopupMenuItem<String?>(value: null, child: Text('All Types')),
        for (final type in kCredentialTypes)
          PopupMenuItem<String?>(value: type, child: Text(credentialTypeLabel(type))),
      ],
    );
  }
}
