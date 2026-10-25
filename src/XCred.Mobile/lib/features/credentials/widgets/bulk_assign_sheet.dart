import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/credential_models.dart';
import '../../../core/models/folder_tag_models.dart';
import '../../../core/providers/vault_providers.dart';
import '../../../core/vault/bulk_edit.dart';
import '../../../core/widgets/option_picker.dart';
import '../../../core/widgets/picker_field.dart';
import 'credential_action_sheets.dart';
import 'quick_create.dart';

enum _TagState { none, add, remove }

enum _ExpiryChoice { none, set, extend, clear }

enum _NotesChoice { none, replace, append, prepend, clear }

class _FieldRow {
  bool remove = false;
  String fieldType = 'text';
  final TextEditingController label = TextEditingController();
  final TextEditingController value = TextEditingController();
  void dispose() {
    label.dispose();
    value.dispose();
  }
}

Color _hexToColor(String hex) => Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));

/// Bulk edit for several credentials at once — mirrors the web app's `BulkEditModal`: folder,
/// credential group, tags (add/remove), expiry date, notes and custom fields. Every section
/// starts on "don't change", so only what the user explicitly touches is applied to the
/// selection. (The function keeps its old name because Credentials/Folders/Tags all call it.)
Future<void> showBulkAssignSheet(
  BuildContext context, {
  required List<String> credentialIds,
  required VoidCallback onApplied,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _BulkEditSheet(credentialIds: credentialIds, onApplied: onApplied),
  );
}

class _BulkEditSheet extends ConsumerStatefulWidget {
  const _BulkEditSheet({required this.credentialIds, required this.onApplied});
  final List<String> credentialIds;
  final VoidCallback onApplied;

  @override
  ConsumerState<_BulkEditSheet> createState() => _BulkEditSheetState();
}

class _BulkEditSheetState extends ConsumerState<_BulkEditSheet> {
  bool _updateFolder = false;
  String? _folderId;
  String _folderLabel = "Don't change";

  bool _updateGroup = false;
  String? _groupId;
  String _groupLabel = "Don't change";

  final Map<String, _TagState> _tagStates = {};

  _ExpiryChoice _expiryChoice = _ExpiryChoice.none;
  DateTime? _expiryDate;
  final _daysController = TextEditingController(text: '365');

  _NotesChoice _notesChoice = _NotesChoice.none;
  final _notesController = TextEditingController();

  final List<_FieldRow> _rows = [];
  bool _applying = false;

  @override
  void dispose() {
    _daysController.dispose();
    _notesController.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final tree = ref.read(folderTreeProvider).value ?? const <FolderNode>[];
    final (picked, id) = await showFolderPickerSheet(context,
        tree: tree,
        currentFolderId: _folderId,
        onCreate: () => showCreateFolderDialog(context, ref));
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
    final (picked, id) = await showGroupPickerSheet(context,
        groups: groups,
        currentGroupId: _groupId,
        onCreate: () => showCreateGroupDialog(context, ref));
    if (!picked) return;
    var label = 'No Credential Group';
    if (id != null) {
      for (final g in groups) {
        if (g.id == id) { label = g.name; break; }
      }
    }
    setState(() { _updateGroup = true; _groupId = id; _groupLabel = label; });
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  void _cycleTag(String id) => setState(() {
        _tagStates[id] = switch (_tagStates[id] ?? _TagState.none) {
          _TagState.none => _TagState.add,
          _TagState.add => _TagState.remove,
          _TagState.remove => _TagState.none,
        };
      });

  int? get _days => int.tryParse(_daysController.text.trim());

  ExpiryChange? _buildExpiry() => switch (_expiryChoice) {
        _ExpiryChoice.none => null,
        _ExpiryChoice.set => _expiryDate == null
            ? null
            : ExpiryChange.set(
                '${_expiryDate!.year.toString().padLeft(4, '0')}-${_expiryDate!.month.toString().padLeft(2, '0')}-${_expiryDate!.day.toString().padLeft(2, '0')}'),
        _ExpiryChoice.extend => (_days == null || _days == 0) ? null : ExpiryChange.extend(_days!),
        _ExpiryChoice.clear => const ExpiryChange.clear(),
      };

  bool get _expiryValid => _expiryChoice == _ExpiryChoice.none || _buildExpiry() != null;

  NotesChange? _buildNotes() => switch (_notesChoice) {
        _NotesChoice.none => null,
        _NotesChoice.clear => const NotesChange(NotesMode.clear),
        _NotesChoice.replace => NotesChange(NotesMode.replace, _notesController.text),
        _NotesChoice.append => NotesChange(NotesMode.append, _notesController.text),
        _NotesChoice.prepend => NotesChange(NotesMode.prepend, _notesController.text),
      };

  bool get _notesValid =>
      _notesChoice == _NotesChoice.none ||
      _notesChoice == _NotesChoice.clear ||
      _notesController.text.trim().isNotEmpty;

  BulkEditChanges _build(List<TagSummary> tags) => BulkEditChanges(
        updateFolder: _updateFolder,
        folderId: _folderId,
        updateGroup: _updateGroup,
        groupId: _groupId,
        expiry: _buildExpiry(),
        addTagIds: [for (final t in tags) if (_tagStates[t.id] == _TagState.add) t.id],
        removeTagIds: [for (final t in tags) if (_tagStates[t.id] == _TagState.remove) t.id],
        notes: _buildNotes(),
        customFields: [
          for (final r in _rows)
            if (r.label.text.trim().isNotEmpty)
              r.remove
                  ? CustomFieldOp.remove(r.label.text)
                  : CustomFieldOp.set(r.label.text, r.value.text, r.fieldType),
        ],
      );

  Future<void> _apply(List<TagSummary> tags) async {
    setState(() => _applying = true);
    try {
      final updated = await ref
          .read(vaultProvider.notifier)
          .bulkEdit(credentialIds: widget.credentialIds, changes: _build(tags));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Updated $updated credential${updated == 1 ? '' : 's'}.'),
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

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            child,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(tagListProvider).value ?? const <TagSummary>[];
    final count = widget.credentialIds.length;
    final changes = _build(tags);
    final canApply = changes.hasAnyChange && _expiryValid && _notesValid && !_applying;
    final hint = Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor);

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
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
          Text('Anything left on "Don\'t change" is not touched.', style: hint),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  _section(
                    'Tags',
                    tags.isEmpty
                        ? const Text('No tags yet — create one from the Tags screen first.')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tap a tag to add it to every selected credential; tap again to remove it instead; a third tap leaves it alone.',
                                style: hint,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final tag in tags)
                                    _TagChip(
                                      tag: tag,
                                      state: _tagStates[tag.id] ?? _TagState.none,
                                      onTap: () => _cycleTag(tag.id),
                                    ),
                                ],
                              ),
                            ],
                          ),
                  ),
                  _section(
                    'Expiry date',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PickerField<_ExpiryChoice>(
                          key: const ValueKey('bulk_expiry_choice'),
                          label: 'Expiry change',
                          value: _expiryChoice,
                          options: const [
                            PickOption(value: _ExpiryChoice.none, label: "Don't change"),
                            PickOption(value: _ExpiryChoice.set, label: 'Set to a date'),
                            PickOption(value: _ExpiryChoice.extend, label: 'Extend by N days'),
                            PickOption(value: _ExpiryChoice.clear, label: 'Remove expiry'),
                          ],
                          onChanged: (v) => setState(() => _expiryChoice = v),
                        ),
                        if (_expiryChoice == _ExpiryChoice.set)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _pickExpiryDate,
                              icon: const Icon(Icons.event, size: 18),
                              label: Text(_expiryDate == null
                                  ? 'Pick a date'
                                  : _expiryDate!.toIso8601String().substring(0, 10)),
                            ),
                          ),
                        if (_expiryChoice == _ExpiryChoice.extend) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: _daysController,
                            keyboardType: const TextInputType.numberWithOptions(signed: true),
                            decoration: const InputDecoration(labelText: 'Days', isDense: true),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Counted from each credential's own expiry (or from today when it has none). Use a negative number to shorten.",
                            style: hint,
                          ),
                        ],
                      ],
                    ),
                  ),
                  _section(
                    'Notes',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PickerField<_NotesChoice>(
                          key: const ValueKey('bulk_notes_choice'),
                          label: 'Notes change',
                          value: _notesChoice,
                          options: const [
                            PickOption(value: _NotesChoice.none, label: "Don't change"),
                            PickOption(value: _NotesChoice.replace, label: 'Replace notes'),
                            PickOption(value: _NotesChoice.append, label: 'Add to the end'),
                            PickOption(value: _NotesChoice.prepend, label: 'Add to the start'),
                            PickOption(value: _NotesChoice.clear, label: 'Clear notes'),
                          ],
                          onChanged: (v) => setState(() => _notesChoice = v),
                        ),
                        if (_notesChoice == _NotesChoice.replace ||
                            _notesChoice == _NotesChoice.append ||
                            _notesChoice == _NotesChoice.prepend) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: _notesController,
                            maxLines: 3,
                            decoration: const InputDecoration(hintText: 'Note text…'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _section(
                    'Custom fields',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_rows.isEmpty)
                          Text(
                            'Add or update a field on every selected credential, or remove one by its label.',
                            style: hint,
                          ),
                        for (var i = 0; i < _rows.length; i++) _buildFieldRow(i),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            key: const ValueKey('bulk_add_field'),
                            onPressed: () => setState(() => _rows.add(_FieldRow())),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add change'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
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
                  onPressed: canApply ? () => _apply(tags) : null,
                  child: Text(_applying ? 'Applying…' : 'Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldRow(int i) {
    final r = _rows[i];
    return Card(
      key: ValueKey('bulk_field_$i'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: PickerField<bool>(
                    label: 'Action',
                    dense: true,
                    value: r.remove,
                    options: const [
                      PickOption(value: false, label: 'Add / update'),
                      PickOption(value: true, label: 'Remove'),
                    ],
                    onChanged: (v) => setState(() => r.remove = v),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Remove this change',
                  onPressed: () => setState(() {
                    r.dispose();
                    _rows.removeAt(i);
                  }),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 8),
              child: TextField(
                controller: r.label,
                decoration: const InputDecoration(labelText: 'Label', isDense: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (!r.remove) ...[
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 8),
                child: TextField(
                  controller: r.value,
                  obscureText: r.fieldType == 'password',
                  decoration: const InputDecoration(labelText: 'Value', isDense: true),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 8),
                child: PickerField<String>(
                  label: 'Field type',
                  dense: true,
                  value: r.fieldType,
                  options: const [
                    PickOption(value: 'text', label: 'Text'),
                    PickOption(value: 'password', label: 'Hidden'),
                    PickOption(value: 'url', label: 'URL'),
                  ],
                  onChanged: (v) => setState(() => r.fieldType = v),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag, required this.state, required this.onTap});
  final TagSummary tag;
  final _TagState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(tag.color);
    final IconData? icon = switch (state) {
      _TagState.add => Icons.add,
      _TagState.remove => Icons.remove,
      _TagState.none => null,
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: state == _TagState.none ? color.withValues(alpha: 0.55) : color,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: switch (state) {
              _TagState.add => Colors.green.shade700,
              _TagState.remove => Colors.red.shade700,
              _TagState.none => Colors.transparent,
            },
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(tag.name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration: state == _TagState.remove ? TextDecoration.lineThrough : null,
                )),
          ],
        ),
      ),
    );
  }
}
