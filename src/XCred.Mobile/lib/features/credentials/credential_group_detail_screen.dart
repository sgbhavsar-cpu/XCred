import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/providers/vault_providers.dart';
import '../../core/vault/credential_type_meta.dart';

/// MOB-CGRP-01 — member list + add-existing/add-new/remove, rename, delete. Mirrors the
/// web app's `CredentialGroupDetailPage.tsx`.
class CredentialGroupDetailScreen extends ConsumerStatefulWidget {
  const CredentialGroupDetailScreen({required this.groupId, super.key});
  final String groupId;

  @override
  ConsumerState<CredentialGroupDetailScreen> createState() =>
      _CredentialGroupDetailScreenState();
}

class _CredentialGroupDetailScreenState extends ConsumerState<CredentialGroupDetailScreen> {
  Map<String, dynamic>? _group;
  final Map<String, String> _names = {};
  bool _loading = true;
  String? _error;
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
    final session = ref.read(authSessionProvider);
    try {
      final group =
          await ref.read(credentialGroupRepositoryProvider).getById(widget.groupId);
      final members = (group['credentials'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      if (session != null) {
        final crypto = ref.read(cryptoServiceProvider);
        for (final c in members) {
          try {
            final fields = await crypto.decryptCredentialFields(
              encryptedData: c['encryptedData'] as String,
              dataIv: c['dataIv'] as String,
              encryptedCredentialKey: c['encryptedCredentialKey'] as String,
              privateKey: session.privateKey,
            );
            final name = fields['name'] as String?;
            _names[c['id'] as String] =
                (name != null && name.isNotEmpty) ? name : credentialTypeLabel(c['type'] as String);
          } catch (_) {
            _names[c['id'] as String] = credentialTypeLabel(c['type'] as String);
          }
        }
      }
      setState(() => _group = group);
    } catch (e) {
      setState(() => _error = 'Failed to load credential group.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rename() async {
    final group = _group!;
    final nameController = TextEditingController(text: group['name'] as String);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Credential Group'),
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
      await ref.read(credentialGroupRepositoryProvider).rename(
            widget.groupId,
            name: newName,
            icon: group['icon'] as String,
          );
      ref.invalidate(credentialGroupsProvider);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to rename.')));
      }
    }
  }

  Future<void> _deleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Credential Group?'),
        content: const Text(
            'Its credentials will not be deleted, just unlinked from this group.'),
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
      await ref.read(credentialGroupRepositoryProvider).delete(widget.groupId);
      ref.invalidate(credentialGroupsProvider);
      ref.invalidate(vaultProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to delete.')));
      }
    }
  }

  Future<void> _removeMember(String credentialId) async {
    setState(() => _busy = true);
    try {
      await ref.read(credentialRepositoryProvider).setCredentialGroup(credentialId, null);
      ref.invalidate(vaultProvider);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to remove.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addExisting() async {
    final vault = await ref.read(vaultProvider.future);
    final candidates =
        vault.credentials.where((c) => c.credentialGroupId != widget.groupId).toList();

    if (!mounted) return;
    final selectedId = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add Existing Credential'),
        children: candidates.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text('All your credentials are already in this group, or you '
                      "don't have any yet."),
                ),
              ]
            : [
                for (final c in candidates)
                  SimpleDialogOption(
                    onPressed: () => Navigator.of(context).pop(c.id),
                    child: Text(
                        '${credentialTypeIcon(c.type)} ${vault.decrypted[c.id]?.name ?? credentialTypeLabel(c.type)}'),
                  ),
              ],
      ),
    );
    if (selectedId == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(credentialRepositoryProvider).setCredentialGroup(selectedId, widget.groupId);
      ref.invalidate(vaultProvider);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to add.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    return Scaffold(
      appBar: AppBar(
        title: Text(_loading ? '' : (group != null ? group['name'] as String : 'Group')),
        actions: [
          if (group != null) ...[
            IconButton(
                icon: const Icon(Icons.edit_outlined), tooltip: 'Rename', onPressed: _rename),
            IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                onPressed: _deleteGroup),
          ],
        ],
      ),
      floatingActionButton: group == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final saved = await context
                    .push<bool>('/credentials/new?groupId=${widget.groupId}');
                if (saved == true) _load();
              },
              icon: const Icon(Icons.add),
              label: const Text('New Credential'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : group == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        children: [
                          ListTile(
                            leading: Text(group['icon'] as String,
                                style: const TextStyle(fontSize: 28)),
                            title: Text('${group['credentialCount']} credential'
                                '${group['credentialCount'] == 1 ? '' : 's'}'),
                            trailing: OutlinedButton.icon(
                              onPressed: _busy ? null : _addExisting,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Existing'),
                            ),
                          ),
                          const Divider(height: 1),
                          for (final c in (group['credentials'] as List<dynamic>? ?? [])
                              .cast<Map<String, dynamic>>())
                            ListTile(
                              leading: Text(credentialTypeIcon(c['type'] as String),
                                  style: const TextStyle(fontSize: 22)),
                              title: Text(_names[c['id']] ?? '…'),
                              subtitle: Text(credentialTypeLabel(c['type'] as String)),
                              onTap: () => context.push('/credentials/${c['id']}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                tooltip: 'Remove from group',
                                onPressed:
                                    _busy ? null : () => _removeMember(c['id'] as String),
                              ),
                            ),
                        ],
                      ),
                    ),
    );
  }
}
