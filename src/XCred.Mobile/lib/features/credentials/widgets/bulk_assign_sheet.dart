import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/credential_models.dart';
import '../../../core/models/folder_tag_models.dart';
import '../../../core/providers/vault_providers.dart';
import 'credential_action_sheets.dart';

/// Bulk folder/group reassignment for several credentials at once — mirrors the web
/// app's `BulkEditModal`. Each field is independent and 3-way ("don't change" / "clear
/// it" / "set to X"), matching the web modal exactly: a bulk edit shouldn't force every
/// selected credential into the same folder AND group unless the user explicitly picked
/// both. Stands in for web's drag-and-drop bulk-move on a platform where dragging many
/// selected rows at once isn't a natural gesture.
Future<void> showBulkAssignSheet(
  BuildContext context, {
  required List<String> credentialIds,
  required VoidCallback onApplied,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => _BulkAssignSheet(credentialIds: credentialIds, onApplied: onApplied),
  );
}

class _BulkAssignSheet extends ConsumerStatefulWidget {
  const _BulkAssignSheet({required this.credentialIds, required this.onApplied});
  final List<String> credentialIds;
  final VoidCallback onApplied;

  @override
  ConsumerState<_BulkAssignSheet> createState() => _BulkAssignSheetState();
}

class _BulkAssignSheetState extends ConsumerState<_BulkAssignSheet> {
  bool _updateFolder = false;
  String? _folderId;
  String _folderLabel = "Don't change";

  bool _updateGroup = false;
  String? _groupId;
  String _groupLabel = "Don't change";

  bool _applying = false;

  Future<void> _pickFolder() async {
    final tree = ref.read(folderTreeProvider).value ?? const <FolderNode>[];
    final (picked, id) = await showFolderPickerSheet(context, tree: tree, currentFolderId: _folderId);
    if (!picked) return;
    var label = 'No Folder';
    if (id != null) {
      for (final f in flattenFolders(tree)) {
        if (f.id == id) { label = f.indentedName; break; }
      }
    }
    setState(() { _updateFolder = true; _folderId = id; _folderLabel = label; });
  }

  Future<void> _pickGroup() async {
    final groups = ref.read(credentialGroupsProvider).value ?? const <CredentialGroupSummary>[];
    final (picked, id) = await showGroupPickerSheet(context, groups: groups, currentGroupId: _groupId);
    if (!picked) return;
    var label = 'No Credential Group';
    if (id != null) {
      for (final g in groups) {
        if (g.id == id) { label = g.name; break; }
      }
    }
    setState(() { _updateGroup = true; _groupId = id; _groupLabel = label; });
  }

  Future<void> _apply() async {
    setState(() => _applying = true);
    try {
      final result = await ref.read(vaultProvider.notifier).bulkAssign(
            credentialIds: widget.credentialIds,
            updateFolder: _updateFolder,
            folderId: _folderId,
            updateCredentialGroup: _updateGroup,
            credentialGroupId: _groupId,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Updated ${result.updated} credential${result.updated == 1 ? '' : 's'}.'),
      ));
      widget.onApplied();
    } catch (_) {
      if (mounted) {
        setState(() => _applying = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Bulk edit failed.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasChange = _updateFolder || _updateGroup;
    final count = widget.credentialIds.length;
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Bulk edit $count credential${count == 1 ? '' : 's'}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.folder_outlined, color: Colors.amber),
            title: const Text('Folder'),
            subtitle: Text(_folderLabel),
            trailing: TextButton(onPressed: _pickFolder, child: const Text('Change')),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.workspaces_outline),
            title: const Text('Credential Group'),
            subtitle: Text(_groupLabel),
            trailing: TextButton(onPressed: _pickGroup, child: const Text('Change')),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _applying ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: (!hasChange || _applying) ? null : _apply,
                  child: Text(_applying ? 'Applying…' : 'Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
