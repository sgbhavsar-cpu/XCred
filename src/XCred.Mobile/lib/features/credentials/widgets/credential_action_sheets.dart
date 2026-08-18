import 'package:flutter/material.dart';

import '../../../core/models/credential_models.dart';
import '../../../core/models/folder_tag_models.dart';

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

/// Lists "No Folder" + the flattened folder tree; returns the chosen folder id (or null
/// for "No Folder"). The current assignment is check-marked.
Future<PickResult> showFolderPickerSheet(
  BuildContext context, {
  required List<FolderNode> tree,
  required String? currentFolderId,
}) async {
  final flat = flattenFolders(tree);
  final result = await showModalBottomSheet<PickResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Move to Folder', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.folder_off_outlined),
            title: const Text('No Folder'),
            trailing: currentFolderId == null ? const Icon(Icons.check) : null,
            onTap: () => Navigator.of(context).pop((true, null)),
          ),
          for (final f in flat)
            ListTile(
              leading: const Icon(Icons.folder_outlined, color: Colors.amber),
              title: Text(f.indentedName),
              trailing: currentFolderId == f.id ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop((true, f.id)),
            ),
        ],
      ),
    ),
  );
  return result ?? (false, null);
}

/// Same as [showFolderPickerSheet] but for Credential Groups (flat, not a tree).
Future<PickResult> showGroupPickerSheet(
  BuildContext context, {
  required List<CredentialGroupSummary> groups,
  required String? currentGroupId,
}) async {
  final result = await showModalBottomSheet<PickResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Move to Credential Group', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.workspaces_outline),
            title: const Text('No Credential Group'),
            trailing: currentGroupId == null ? const Icon(Icons.check) : null,
            onTap: () => Navigator.of(context).pop((true, null)),
          ),
          for (final g in groups)
            ListTile(
              leading: Text(g.icon, style: const TextStyle(fontSize: 18)),
              title: Text(g.name),
              trailing: currentGroupId == g.id ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop((true, g.id)),
            ),
        ],
      ),
    ),
  );
  return result ?? (false, null);
}
