import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_response.dart';
import '../../core/models/folder_tag_models.dart';
import '../../core/providers/core_providers.dart';
import '../../core/providers/vault_providers.dart';
import '../../core/vault/credential_fields.dart';
import '../../core/vault/credential_repository.dart';
import '../../core/vault/credential_type_meta.dart';
import '../../core/vault/smart_links.dart';
import 'widgets/password_generator_sheet.dart';

/// MOB-CRED-03/04/05 — create/edit form shell, all 19 types (data-driven from
/// [kCredentialFields], the same table the detail screen reads), list-type fields,
/// custom fields, tags/folder/group pickers, expiry. Mirrors the web app's
/// `CredentialFormPage.tsx` field-for-field.
class CredentialFormScreen extends ConsumerStatefulWidget {
  const CredentialFormScreen({
    this.credentialId,
    this.initialGroupId,
    this.initialFolderId,
    this.initialTagId,
    super.key,
  });
  final String? credentialId;

  /// Pre-selection when arriving via "Add credential" from a group/folder/tag's own
  /// screen (e.g. `/credentials/new?groupId=...`) — matches web's `CredentialFormPage`
  /// query-param handling. Ignored when editing.
  final String? initialGroupId;
  final String? initialFolderId;
  final String? initialTagId;

  bool get isEdit => credentialId != null;

  @override
  ConsumerState<CredentialFormScreen> createState() => _CredentialFormScreenState();
}

class _CustomFieldInput {
  final TextEditingController labelController;
  final TextEditingController valueController;
  String fieldType; // text | password | url
  bool hidden;
  _CustomFieldInput({String label = '', String value = '', this.fieldType = 'text'})
      : labelController = TextEditingController(text: label),
        valueController = TextEditingController(text: value),
        hidden = fieldType == 'password';

  void dispose() {
    labelController.dispose();
    valueController.dispose();
  }
}

class _CredentialFormScreenState extends ConsumerState<CredentialFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'WebsiteLogin';
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  Map<String, TextEditingController> _fieldControllers = {};
  Map<String, List<TextEditingController>> _listFieldControllers = {};
  final Map<String, bool> _hiddenPassword = {};
  final List<_CustomFieldInput> _customFields = [];
  String? _folderId;
  String? _credentialGroupId;
  final Set<String> _selectedTagIds = {};
  DateTime? _expiryDate;
  DateTime? _baseUpdatedAt;
  bool _loading;
  bool _saving = false;
  String? _error;

  _CredentialFormScreenState() : _loading = false;

  @override
  void initState() {
    super.initState();
    _loading = widget.isEdit;
    _rebuildFieldControllers(_type);
    if (widget.isEdit) {
      _loadExisting();
    } else {
      _folderId = widget.initialFolderId;
      _credentialGroupId = widget.initialGroupId;
      if (widget.initialTagId != null) _selectedTagIds.add(widget.initialTagId!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    for (final list in _listFieldControllers.values) {
      for (final c in list) {
        c.dispose();
      }
    }
    for (final cf in _customFields) {
      cf.dispose();
    }
    super.dispose();
  }

  void _rebuildFieldControllers(String type, [Map<String, dynamic>? initialValues]) {
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    for (final list in _listFieldControllers.values) {
      for (final c in list) {
        c.dispose();
      }
    }
    final fieldControllers = <String, TextEditingController>{};
    final listFieldControllers = <String, List<TextEditingController>>{};
    for (final field in kCredentialFields[type] ?? const []) {
      if (field.type == 'list') {
        List<String> items = [];
        final raw = initialValues?[field.key] as String?;
        if (raw != null) {
          try {
            items = (jsonDecode(raw) as List<dynamic>).map((e) => e.toString()).toList();
          } catch (_) {
            items = [];
          }
        }
        listFieldControllers[field.key] =
            items.map((v) => TextEditingController(text: v)).toList();
      } else {
        fieldControllers[field.key] =
            TextEditingController(text: (initialValues?[field.key] as String?) ?? '');
        if (field.type == 'password') _hiddenPassword[field.key] = true;
      }
    }
    setState(() {
      _fieldControllers = fieldControllers;
      _listFieldControllers = listFieldControllers;
    });
  }

  Future<void> _loadExisting() async {
    final session = ref.read(authSessionProvider);
    if (session == null) return;
    try {
      final cred = await ref.read(credentialRepositoryProvider).getById(widget.credentialId!);
      if (cred == null) {
        setState(() => _error = 'Credential not found.');
        return;
      }
      final crypto = ref.read(cryptoServiceProvider);
      final decrypted = await crypto.decryptCredentialFields(
        encryptedData: cred.encryptedData,
        dataIv: cred.dataIv,
        encryptedCredentialKey: cred.encryptedCredentialKey,
        privateKey: session.privateKey,
      );

      List<_CustomFieldInput> customFields = [];
      try {
        final raw = decrypted['customFields'] as String?;
        if (raw != null) {
          customFields = (jsonDecode(raw) as List<dynamic>).map((e) {
            final m = e as Map<String, dynamic>;
            return _CustomFieldInput(
              label: m['label'] as String? ?? '',
              value: m['value'] as String? ?? '',
              fieldType: m['fieldType'] as String? ?? 'text',
            );
          }).toList();
        }
      } catch (_) {
        customFields = [];
      }

      setState(() {
        _type = cred.type;
        _nameController.text = (decrypted['name'] as String?) ?? '';
        _notesController.text = (decrypted['notes'] as String?) ?? '';
        _folderId = cred.folderId;
        _credentialGroupId = cred.credentialGroupId;
        _baseUpdatedAt = cred.updatedAt;
        _selectedTagIds
          ..clear()
          ..addAll(cred.tags.map((t) => t.id));
        _expiryDate = cred.expiryDate;
        _customFields
          ..clear()
          ..addAll(customFields);
      });
      _rebuildFieldControllers(
        cred.type,
        decrypted.map((k, v) => MapEntry(k, v?.toString() ?? '')),
      );
    } catch (e) {
      setState(() => _error = 'Failed to load credential for editing.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openGenerator(TextEditingController controller) async {
    final password = await showPasswordGeneratorSheet(context);
    if (password != null) controller.text = password;
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

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    for (final field in kCredentialFields[_type] ?? const []) {
      if (field.type == 'url') {
        final v = _fieldControllers[field.key]?.text.trim() ?? '';
        if (v.isNotEmpty && !isValidUrl(v)) {
          setState(() => _error = '"${field.label}" is not a valid URL.');
          return;
        }
      }
    }

    final session = ref.read(authSessionProvider);
    if (session == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = <String, dynamic>{
        'name': name,
        'notes': _notesController.text,
        'customFields': jsonEncode(_customFields
            .map((cf) => {
                  'label': cf.labelController.text,
                  'value': cf.valueController.text,
                  'fieldType': cf.fieldType,
                })
            .toList()),
      };
      for (final entry in _fieldControllers.entries) {
        payload[entry.key] = entry.value.text;
      }
      for (final entry in _listFieldControllers.entries) {
        payload[entry.key] =
            jsonEncode(entry.value.map((c) => c.text).where((v) => v.isNotEmpty).toList());
      }

      final crypto = ref.read(cryptoServiceProvider);
      final enc = await crypto.encryptCredentialFields(
        payload: payload,
        publicKeySpkiB64: session.publicKeySpkiB64,
      );

      final body = {
        'type': _type,
        'encryptedData': enc.encryptedData,
        'dataIv': enc.dataIv,
        'encryptedCredentialKey': enc.encryptedCredentialKey,
        'expiryDate': _expiryDate?.toIso8601String(),
        'folderId': _folderId,
        'credentialGroupId': _credentialGroupId,
        'tagIds': _selectedTagIds.toList(),
      };

      bool queuedOffline = false;
      if (widget.isEdit) {
        // MOB-SYNC-02 — routed through the repository (not a direct PUT) so a network
        // failure queues the edit for later instead of surfacing an error; create stays
        // a direct online-only call (see credential_repository.dart's `update` doc for
        // why offline create isn't supported this sprint).
        final result = await ref.read(credentialRepositoryProvider).update(
              widget.credentialId!,
              body,
              _baseUpdatedAt ?? DateTime.now(),
            );
        queuedOffline = result.outcome == CredentialWriteOutcome.queuedOffline;
      } else {
        final api = ref.read(apiClientProvider);
        await api.post<Map<String, dynamic>>(
          '/api/credentials',
          (json) => json as Map<String, dynamic>,
          data: body,
        );
      }

      ref.invalidate(vaultProvider);
      ref.invalidate(credentialGroupsProvider);
      if (mounted) {
        if (queuedOffline) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Offline — your edit will sync once you're back online."),
          ));
        }
        context.pop(true);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Failed to save credential.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeFields = kCredentialFields[_type] ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEdit ? 'Edit Credential' : 'Add Credential')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                // SingleChildScrollView + Column, not ListView(children:) — the latter
                // lazily builds only children near the viewport (it's Sliver-backed even
                // with a fixed children list), so fields further down the form wouldn't
                // exist in the widget tree until scrolled into view. Fine for a long
                // list, wrong for a bounded-size form.
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    if (!widget.isEdit) ...[
                      Text('Credential Type', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      _TypePickerGrid(
                        selected: _type,
                        onSelected: (t) {
                          setState(() => _type = t);
                          _rebuildFieldControllers(t);
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        hintText: 'e.g. Company ${credentialTypeLabel(_type)}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final field in typeFields) ...[
                      _buildField(field),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(labelText: 'Notes (optional)'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    _buildCustomFieldsSection(),
                    const SizedBox(height: 20),
                    _buildOrganisationSection(),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(widget.isEdit ? 'Update Credential' : 'Save Credential'),
                    ),
                    const SizedBox(height: 24),
                  ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildField(FieldDef field) {
    if (field.type == 'list') return _buildListField(field);
    if (field.type == 'select') {
      final controller = _fieldControllers[field.key]!;
      return DropdownButtonFormField<String>(
        initialValue: controller.text.isEmpty ? null : controller.text,
        decoration: InputDecoration(labelText: field.label),
        items: [
          for (final option in field.options ?? const [])
            DropdownMenuItem(value: option, child: Text(option)),
        ],
        onChanged: (v) => setState(() => controller.text = v ?? ''),
      );
    }

    final controller = _fieldControllers[field.key]!;
    final isPassword = field.type == 'password';
    final isHidden = _hiddenPassword[field.key] ?? false;
    final linkHref = computeFieldLink(field, controller.text, _currentFieldValues());

    return TextFormField(
      controller: controller,
      obscureText: isPassword && isHidden,
      maxLines: field.type == 'textarea' ? (field.rows ?? 4) : 1,
      style: (isPassword || field.type == 'textarea')
          ? const TextStyle(fontFamily: 'monospace', fontSize: 13)
          : null,
      decoration: InputDecoration(
        labelText: field.label + (field.optional ? ' (optional)' : ''),
        hintText: field.placeholder,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPassword) ...[
              IconButton(
                icon: Icon(isHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 18),
                tooltip: isHidden ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _hiddenPassword[field.key] = !isHidden),
              ),
              IconButton(
                icon: const Icon(Icons.auto_fix_high, size: 18),
                tooltip: 'Generate password',
                onPressed: () => _openGenerator(controller),
              ),
            ],
            if (!isPassword && (field.type == 'url' || field.linkType != null))
              IconButton(
                icon: const Icon(Icons.open_in_new, size: 18),
                tooltip: linkHref != null ? linkTooltip(field) : 'Enter a value first',
                onPressed: linkHref == null ? null : () => openSmartLink(context, linkHref),
              ),
          ],
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Map<String, String> _currentFieldValues() =>
      {for (final e in _fieldControllers.entries) e.key: e.value.text};

  Widget _buildListField(FieldDef field) {
    final controllers = _listFieldControllers[field.key] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(field.label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        for (var i = 0; i < controllers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('list_${field.key}_$i'),
                    controller: controllers[i],
                    decoration: InputDecoration(hintText: field.placeholder, isDense: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                IconButton(
                  key: ValueKey('list_${field.key}_delete_$i'),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Remove',
                  onPressed: () => setState(() {
                    controllers[i].dispose();
                    controllers.removeAt(i);
                  }),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: () => setState(() => controllers.add(TextEditingController())),
          icon: const Icon(Icons.add, size: 16),
          label: Text(controllers.isEmpty ? 'Add value' : 'Add another'),
        ),
      ],
    );
  }

  Widget _buildCustomFieldsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Custom Fields', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _customFields.add(_CustomFieldInput())),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Field'),
                ),
              ],
            ),
            if (_customFields.isEmpty)
              Text('No custom fields.', style: Theme.of(context).textTheme.bodySmall),
            for (var i = 0; i < _customFields.length; i++) _buildCustomFieldRow(i),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomFieldRow(int index) {
    final cf = _customFields[index];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: TextFormField(
              controller: cf.labelController,
              decoration: const InputDecoration(hintText: 'Label', isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: cf.valueController,
              obscureText: cf.fieldType == 'password' && cf.hidden,
              decoration: InputDecoration(
                hintText: 'Value',
                isDense: true,
                suffixIcon: cf.fieldType == 'password'
                    ? IconButton(
                        icon: Icon(
                            cf.hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 16),
                        tooltip: cf.hidden ? 'Show value' : 'Hide value',
                        onPressed: () => setState(() => cf.hidden = !cf.hidden),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 4),
          DropdownButton<String>(
            value: cf.fieldType,
            items: const [
              DropdownMenuItem(value: 'text', child: Text('Text')),
              DropdownMenuItem(value: 'password', child: Text('Hidden')),
              DropdownMenuItem(value: 'url', child: Text('URL')),
            ],
            onChanged: (v) => setState(() => cf.fieldType = v ?? 'text'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: 'Remove field',
            onPressed: () => setState(() {
              cf.dispose();
              _customFields.removeAt(index);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganisationSection() {
    final foldersAsync = ref.watch(folderTreeProvider);
    final tagsAsync = ref.watch(tagListProvider);
    final groupsAsync = ref.watch(credentialGroupsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Organisation', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Text('Tags', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            tagsAsync.when(
              data: (tags) => tags.isEmpty
                  ? const Text('No tags yet.', style: TextStyle(fontSize: 12))
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tags.map((tag) {
                        final selected = _selectedTagIds.contains(tag.id);
                        return FilterChip(
                          label: Text(tag.name, style: const TextStyle(fontSize: 12)),
                          selected: selected,
                          onSelected: (v) => setState(
                              () => v ? _selectedTagIds.add(tag.id) : _selectedTagIds.remove(tag.id)),
                        );
                      }).toList(),
                    ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('Failed to load tags.'),
            ),
            const SizedBox(height: 16),
            foldersAsync.when(
              data: (tree) => DropdownButtonFormField<String?>(
                initialValue: _folderId,
                decoration: const InputDecoration(labelText: 'Folder'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('No Folder')),
                  for (final f in flattenFolders(tree))
                    DropdownMenuItem<String?>(value: f.id, child: Text(f.indentedName)),
                ],
                onChanged: (v) => setState(() => _folderId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('Failed to load folders.'),
            ),
            const SizedBox(height: 12),
            groupsAsync.when(
              data: (groups) => DropdownButtonFormField<String?>(
                initialValue: _credentialGroupId,
                decoration: const InputDecoration(labelText: 'Credential Group (optional)'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('No Credential Group')),
                  for (final g in groups)
                    DropdownMenuItem<String?>(value: g.id, child: Text('${g.icon} ${g.name}')),
                ],
                onChanged: (v) => setState(() => _credentialGroupId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('Failed to load credential groups.'),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickExpiryDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Expiry Date (optional)'),
                child: Text(_expiryDate == null
                    ? 'None'
                    : '${_expiryDate!.year}-${_expiryDate!.month.toString().padLeft(2, '0')}-${_expiryDate!.day.toString().padLeft(2, '0')}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypePickerGrid extends StatelessWidget {
  const _TypePickerGrid({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: kCredentialTypes.length,
      itemBuilder: (context, index) {
        final type = kCredentialTypes[index];
        final isSelected = type == selected;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onSelected(type),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
                width: isSelected ? 2 : 1,
              ),
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)
                  : null,
            ),
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(credentialTypeIcon(type), style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 2),
                Text(
                  credentialTypeLabel(type),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
