import 'package:flutter/material.dart';

import '../../../core/models/credential_models.dart';
import '../../../core/models/folder_tag_models.dart';
import '../../../core/widgets/option_picker.dart';

/// Actions offered from a credential row's "⋮" menu — mirrors the web app's row buttons
/// (View/Edit/Duplicate/Copy Password/Delete) plus a mobile-appropriate "Move to..."
/// pair standing in for drag-and-drop (see docs/planning — bottom-sheet picker was
/// chosen over a literal drag gesture port for touch).
enum CredentialRowAction { edit, duplicate, copyPassword, moveToFolder, moveToGroup, delete }

/// The "⋮" action sheet for a single credential row. [showCopyPassword] hides that entry
/// entirely for credential types with no password-type field, same as the web row's
/// conditional button.
Future<CredentialRowAction?> showCredentialActionsSheet(
  BuildContext context, {
  required bool showCopyPassword,
}) {
  return showModalBottomSheet<CredentialRowAction>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit'),
            onTap: () => Navigator.of(context).pop(CredentialRowAction.edit),
          ),
          ListTile(
            leading: const Icon(Icons.copy_all_outlined),
            title: const Text('Duplicate'),
            onTap: () => Navigator.of(context).pop(CredentialRowAction.duplicate),
          ),
          if (showCopyPassword)
            ListTile(
              leading: const Icon(Icons.key_outlined),
              title: const Text('Copy Password'),
              onTap: () => Navigator.of(context).pop(CredentialRowAction.copyPassword),
            ),
          ListTile(
            leading: const Icon(Icons.drive_file_move_outline),
            title: const Text('Move to Folder…'),
            onTap: () => Navigator.of(context).pop(CredentialRowAction.moveToFolder),
          ),
          ListTile(
            leading: const Icon(Icons.workspaces_outline),
            title: const Text('Move to Credential Group…'),
            onTap: () => Navigator.of(context).pop(CredentialRowAction.moveToGroup),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () => Navigator.of(context).pop(CredentialRowAction.delete),
          ),
        ],
      ),
    ),
  );
}

/// Confirms a single-credential delete — same copy as the web app's confirm dialog.
Future<bool> confirmDeleteCredential(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Credential?'),
      content: const Text('This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// A picked-or-cancelled result: [picked] distinguishes "the user dismissed the sheet"
/// from "the user explicitly chose the null/'no folder' option" — both would otherwise
/// look like a bare `null` return.
typedef PickResult = (bool picked, String? id);

/// "No Folder" + the flattened folder tree, as options for [showOptionPicker] / [PickerField].
List<PickOption<String?>> folderPickOptions(List<FolderNode> tree) => [
      const PickOption<String?>(
          value: null, label: 'No Folder', leading: Icon(Icons.folder_off_outlined)),
      for (final f in flattenFolders(tree))
        PickOption<String?>(
            value: f.id,
            label: f.indentedName,
            leading: const Icon(Icons.folder_outlined, color: Colors.amber)),
    ];

/// "No Credential Group" + the user's groups, as options for [showOptionPicker] / [PickerField].
List<PickOption<String?>> groupPickOptions(List<CredentialGroupSummary> groups) => [
      const PickOption<String?>(
          value: null, label: 'No Credential Group', leading: Icon(Icons.workspaces_outline)),
      for (final g in groups)
        PickOption<String?>(
            value: g.id,
            label: g.name,
            leading: Text(g.icon, style: const TextStyle(fontSize: 18))),
    ];

/// Lists "No Folder" + the flattened folder tree (searchable past 5 entries, scrolling past 6);
/// returns the chosen folder id (or null for "No Folder"). The current assignment is check-marked.
/// [onCreate] adds a "+ New" action that makes a folder in place and picks it.
Future<PickResult> showFolderPickerSheet(
  BuildContext context, {
  required List<FolderNode> tree,
  required String? currentFolderId,
  Future<String?> Function()? onCreate,
}) async {
  final result = await showOptionPicker<String?>(
    context,
    title: 'Move to Folder',
    options: folderPickOptions(tree),
    selected: currentFolderId,
    onCreate: onCreate,
    createLabel: 'New folder',
  );
  return result == null ? (false, null) : (true, result.value);
}

/// Same as [showFolderPickerSheet] but for Credential Groups (flat, not a tree).
Future<PickResult> showGroupPickerSheet(
  BuildContext context, {
  required List<CredentialGroupSummary> groups,
  required String? currentGroupId,
  Future<String?> Function()? onCreate,
}) async {
  final result = await showOptionPicker<String?>(
    context,
    title: 'Move to Credential Group',
    options: groupPickOptions(groups),
    selected: currentGroupId,
    onCreate: onCreate,
    createLabel: 'New group',
  );
  return result == null ? (false, null) : (true, result.value);
}
