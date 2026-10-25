import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/folder_tag_models.dart';
import '../../../core/providers/vault_providers.dart';
import '../../../core/widgets/option_picker.dart';
import '../../../core/widgets/picker_field.dart';

/// Small "make it right here" dialogs behind the "+" next to the Folder / Credential Group
/// pickers, so a record can be created without leaving (and losing) the editor that needs it.
/// Each returns the new record's id (or null when cancelled / failed) after refreshing the
/// shared list provider, so the caller can select it immediately.
Future<String?> showCreateFolderDialog(
  BuildContext context,
  WidgetRef ref, {
  String? defaultParentId,
}) async {
  final flat = flattenFolders(ref.read(folderTreeProvider).value ?? const <FolderNode>[]);
  final nameController = TextEditingController();
  String? parentId = defaultParentId;

  final created = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('New Folder'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('quick_folder_name'),
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Folder name'),
              ),
              const SizedBox(height: 12),
              PickerField<String?>(
                label: 'Parent folder (optional)',
                value: parentId,
                options: [
                  const PickOption<String?>(value: null, label: 'None (top-level)'),
                  for (final f in flat) PickOption<String?>(value: f.id, label: f.indentedName),
                ],
                onChanged: (v) => setDialogState(() => parentId = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Create')),
        ],
      ),
    ),
  );
  final name = nameController.text.trim();
  if (created != true || name.isEmpty) return null;
  try {
    final id = await ref.read(folderRepositoryProvider).create(name: name, parentFolderId: parentId);
    await ref.read(folderTreeProvider.notifier).refresh();
    return id;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to create folder.')));
    }
    return null;
  }
}

const kGroupIconOptions = ['🏦', '📧', '🌐', '📱', '🏢', '🚗', '🏥', '📦'];

Future<String?> showCreateGroupDialog(BuildContext context, WidgetRef ref) async {
  final nameController = TextEditingController();
  var selectedIcon = kGroupIconOptions[0];

  final created = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('New Credential Group'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 6,
                children: [
                  for (final icon in kGroupIconOptions)
                    ChoiceChip(
                      label: Text(icon, style: const TextStyle(fontSize: 18)),
                      selected: selectedIcon == icon,
                      onSelected: (_) => setDialogState(() => selectedIcon = icon),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('quick_group_name'),
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'e.g. "HDFC Bank"'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Create')),
        ],
      ),
    ),
  );
  final name = nameController.text.trim();
  if (created != true || name.isEmpty) return null;
  try {
    final id = await ref.read(credentialGroupRepositoryProvider).create(name: name, icon: selectedIcon);
    await ref.read(credentialGroupsProvider.notifier).refresh();
    return id;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to create credential group.')));
    }
    return null;
  }
}
