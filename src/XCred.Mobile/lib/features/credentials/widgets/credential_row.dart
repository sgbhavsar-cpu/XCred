import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/credential_models.dart';
import '../../../core/models/folder_tag_models.dart';
import '../../../core/providers/vault_providers.dart';
import '../../../core/vault/credential_fields.dart';
import '../../../core/vault/credential_type_meta.dart';
import 'credential_action_sheets.dart';

/// Shared row rendering for the Credentials/Folders/Tags screens — mirrors the web app's
/// `CredentialRow.tsx`, including its Edit/Duplicate/Copy Password/Delete actions (here
/// behind a "⋮" menu, since a phone-width row can't fit that many icon buttons the way a
/// desktop one can) and a "Move to Folder/Group…" pair standing in for web's
/// drag-and-drop. [showActions] opts a row into that menu; [selectionMode] swaps the
/// leading icon for a checkbox and routes taps to [onToggleSelect] instead of [onTap] —
/// both default off so a caller that wants neither (there currently isn't one) just gets
/// the original plain row.
class CredentialRow extends ConsumerWidget {
  const CredentialRow({
    required this.cred,
    required this.decrypted,
    required this.onTap,
    this.indent = false,
    this.showActions = false,
    this.selectionMode = false,
    this.selected = false,
    this.onToggleSelect,
    this.onLongPress,
    super.key,
  });

  final CredentialListItem cred;
  final DecryptedCredentialMeta? decrypted;
  final VoidCallback onTap;
  final bool indent;
  final bool showActions;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onLongPress;

  bool get _hasPasswordField =>
      (kCredentialFields[cred.type] ?? const []).any((f) => f.type == 'password');

  Future<void> _openActions(BuildContext context, WidgetRef ref) async {
    final action =
        await showCredentialActionsSheet(context, showCopyPassword: _hasPasswordField);
    if (action == null || !context.mounted) return;

    switch (action) {
      case CredentialRowAction.edit:
        final saved = await context.push<bool>('/credentials/${cred.id}/edit');
        if (saved == true) await ref.read(vaultProvider.notifier).refresh();
      case CredentialRowAction.duplicate:
        await _duplicate(context, ref);
      case CredentialRowAction.copyPassword:
        await _copyPassword(context, ref);
      case CredentialRowAction.moveToFolder:
        await _moveToFolder(context, ref);
      case CredentialRowAction.moveToGroup:
        await _moveToGroup(context, ref);
      case CredentialRowAction.delete:
        await _delete(context, ref);
    }
  }

  Future<void> _duplicate(BuildContext context, WidgetRef ref) async {
    try {
      final newId = await ref.read(vaultProvider.notifier).duplicateCredential(cred.id);
      if (!context.mounted) return;
      if (newId == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to duplicate credential.')));
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Credential duplicated.')));
      await context.push('/credentials/$newId/edit');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to duplicate credential.')));
      }
    }
  }

  Future<void> _copyPassword(BuildContext context, WidgetRef ref) async {
    try {
      final ok = await ref.read(vaultProvider.notifier).copyPassword(cred.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Password copied to clipboard.' : 'Nothing to copy for this credential.'),
      ));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to copy password.')));
      }
    }
  }

  Future<void> _moveToFolder(BuildContext context, WidgetRef ref) async {
    final tree = ref.read(folderTreeProvider).value ?? const <FolderNode>[];
    final (picked, folderId) =
        await showFolderPickerSheet(context, tree: tree, currentFolderId: cred.folderId);
    if (!picked || !context.mounted) return;
    if (folderId == cred.folderId) return;
    try {
      await ref
          .read(vaultProvider.notifier)
          .bulkAssign(credentialIds: [cred.id], updateFolder: true, folderId: folderId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(folderId != null ? 'Moved to folder.' : 'Removed from folder.'),
        ));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to move credential.')));
      }
    }
  }

  Future<void> _moveToGroup(BuildContext context, WidgetRef ref) async {
    final groups = ref.read(credentialGroupsProvider).value ?? const <CredentialGroupSummary>[];
    final (picked, groupId) = await showGroupPickerSheet(context,
        groups: groups, currentGroupId: cred.credentialGroupId);
    if (!picked || !context.mounted) return;
    if (groupId == cred.credentialGroupId) return;
    try {
      await ref.read(vaultProvider.notifier).bulkAssign(
          credentialIds: [cred.id], updateCredentialGroup: true, credentialGroupId: groupId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(groupId != null ? 'Moved to credential group.' : 'Removed from credential group.'),
        ));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to move credential.')));
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (!await confirmDeleteCredential(context)) return;
    try {
      await ref.read(vaultProvider.notifier).deleteCredential(cred.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Credential deleted.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to delete.')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitleParts = [
      credentialTypeLabel(cred.type),
      if (decrypted?.subtitle != null && decrypted!.subtitle!.isNotEmpty) decrypted!.subtitle!,
    ];

    return ListTile(
      contentPadding: EdgeInsets.only(left: indent ? 48 : 16, right: 16),
      leading: selectionMode
          ? Checkbox(value: selected, onChanged: (_) => onToggleSelect?.call())
          : Text(credentialTypeIcon(cred.type), style: const TextStyle(fontSize: 24)),
      title: Row(
        children: [
          Flexible(
            child: Text(decrypted?.name ?? '…',
                overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (cred.isExpired) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('Expired', style: TextStyle(fontSize: 10, color: Colors.red)),
            ),
          ],
        ],
      ),
      subtitle: Text(subtitleParts.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: selectionMode
          ? null
          : showActions
              ? IconButton(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Actions',
                  onPressed: () => _openActions(context, ref),
                )
              : const Icon(Icons.chevron_right, size: 20),
      onTap: selectionMode ? onToggleSelect : onTap,
      onLongPress: selectionMode ? null : onLongPress,
    );
  }
}
