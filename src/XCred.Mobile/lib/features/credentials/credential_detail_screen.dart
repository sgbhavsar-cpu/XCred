import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/models/credential_models.dart';
import '../../core/providers/core_providers.dart';
import '../../core/providers/vault_providers.dart';
import '../../core/vault/credential_fields.dart';
import '../../core/vault/credential_type_meta.dart';
import '../../core/vault/smart_links.dart';

/// MOB-CRED-02/03/MOB-ATT-01/02 — credential detail: every populated field per its
/// [FieldDef] type, reveal/hide for passwords, copy with the real clipboard-clear
/// countdown, smart links, Edit action, and (as of Sprint 1.6) attachment
/// upload/download/delete. Delete/Share are later sprints (2.x).
class CredentialDetailScreen extends ConsumerStatefulWidget {
  const CredentialDetailScreen({required this.credentialId, super.key});
  final String credentialId;

  @override
  ConsumerState<CredentialDetailScreen> createState() => _CredentialDetailScreenState();
}

class _CredentialDetailScreenState extends ConsumerState<CredentialDetailScreen> {
  CredentialListItem? _cred;
  Map<String, String> _fields = {};
  String _name = '';
  String _notes = '';
  List<_CustomField> _customFields = [];
  final Map<String, bool> _hidden = {};
  final Map<String, String> _attachmentNames = {};
  bool _loading = true;
  bool _uploading = false;
  String? _error;

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
    if (session == null) return;
    try {
      final cred = await ref.read(credentialRepositoryProvider).getById(widget.credentialId);
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

      final typeFields = kCredentialFields[cred.type] ?? const [];
      final fd = <String, String>{};
      final hidden = <String, bool>{};
      for (final f in typeFields) {
        fd[f.key] = (decrypted[f.key] as String?) ?? '';
        if (f.type == 'password') hidden[f.key] = true;
      }

      List<_CustomField> customFields = [];
      try {
        final raw = decrypted['customFields'] as String?;
        if (raw != null) {
          customFields = (jsonDecode(raw) as List<dynamic>)
              .map((e) => _CustomField.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {
        customFields = [];
      }

      final attachmentNames = <String, String>{};
      if (cred.attachments.isNotEmpty) {
        final credentialKey =
            crypto.decryptKeyWithPrivateKey(session.privateKey, cred.encryptedCredentialKey);
        for (final att in cred.attachments) {
          if (att.fileNameIv == null) continue;
          try {
            attachmentNames[att.id] =
                await crypto.decrypt(credentialKey, att.encryptedFileName, att.fileNameIv!);
          } catch (_) {
            attachmentNames[att.id] = 'Encrypted file';
          }
        }
      }

      setState(() {
        _cred = cred;
        _fields = fd;
        _name = (decrypted['name'] as String?) ?? '';
        _notes = (decrypted['notes'] as String?) ?? '';
        _customFields = customFields;
        _hidden
          ..clear()
          ..addAll(hidden);
        _attachmentNames
          ..clear()
          ..addAll(attachmentNames);
      });
    } catch (e) {
      setState(() => _error = 'Failed to decrypt credential.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadAttachment() async {
    final cred = _cred;
    final session = ref.read(authSessionProvider);
    if (cred == null || session == null) return;

    final picked = await ref.read(fileExchangeProvider).pickFile();
    if (picked == null) return;

    final maxMb = ref.read(orgSettingsProvider).maxAttachmentSizeMb;
    if (picked.bytes.lengthInBytes > maxMb * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"${picked.name}" is too large. Maximum size is $maxMb MB.'),
        ));
      }
      return;
    }

    setState(() => _uploading = true);
    try {
      final crypto = ref.read(cryptoServiceProvider);
      final credentialKey =
          crypto.decryptKeyWithPrivateKey(session.privateKey, cred.encryptedCredentialKey);

      final fileBase64 = base64Encode(picked.bytes);
      final encData = await crypto.encrypt(credentialKey, fileBase64);
      final encName = await crypto.encrypt(credentialKey, picked.name);
      final encMime = await crypto.encrypt(credentialKey, picked.mimeType);

      await ref.read(attachmentRepositoryProvider).upload(
            cred.id,
            encryptedFileName: encName.ciphertextB64,
            fileNameIv: encName.ivB64,
            encryptedMimeType: encMime.ciphertextB64,
            mimeTypeIv: encMime.ivB64,
            encryptedData: encData.ciphertextB64,
            dataIv: encData.ivB64,
            fileSizeBytes: picked.bytes.lengthInBytes,
          );

      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to upload attachment.')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _downloadAttachment(AttachmentMeta att) async {
    final cred = _cred;
    final session = ref.read(authSessionProvider);
    if (cred == null || session == null) return;
    try {
      final data = await ref.read(attachmentRepositoryProvider).download(cred.id, att.id);
      final crypto = ref.read(cryptoServiceProvider);
      final credentialKey =
          crypto.decryptKeyWithPrivateKey(session.privateKey, cred.encryptedCredentialKey);

      final fileBase64 =
          await crypto.decrypt(credentialKey, data['encryptedData'] as String, data['dataIv'] as String);
      final fileName = data['fileNameIv'] != null
          ? await crypto
              .decrypt(credentialKey, data['encryptedFileName'] as String, data['fileNameIv'] as String)
              .catchError((_) => 'attachment')
          : 'attachment';
      final mimeType = data['mimeTypeIv'] != null
          ? await crypto
              .decrypt(
                  credentialKey, data['encryptedMimeType'] as String, data['mimeTypeIv'] as String)
              .catchError((_) => 'application/octet-stream')
          : 'application/octet-stream';

      await ref
          .read(fileExchangeProvider)
          .saveOrShare(fileName, base64Decode(fileBase64), mimeType);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to download attachment.')));
      }
    }
  }

  Future<void> _deleteAttachment(AttachmentMeta att) async {
    final cred = _cred;
    if (cred == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Attachment?'),
        content: Text(_attachmentNames[att.id] ?? 'This attachment'),
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
      await ref.read(attachmentRepositoryProvider).delete(cred.id, att.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to delete attachment.')));
      }
    }
  }

  Future<void> _copy(String value, String key) async {
    await Clipboard.setData(ClipboardData(text: value));
    unawaited(ref
        .read(apiClientProvider)
        .post<String>('/api/credentials/${widget.credentialId}/copy',
            identityFromData<String>, data: null)
        .catchError((_) => ''));

    final seconds = ref.read(orgSettingsProvider).clipboardClearSeconds;
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: _CountdownNotice(seconds: seconds),
        duration: Duration(seconds: seconds),
      ));
    }
    Future.delayed(Duration(seconds: seconds), () async {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      if (current?.text == value) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cred = _cred;
    return Scaffold(
      appBar: AppBar(
        title: Text(_loading ? '' : (cred != null ? _name : 'Credential')),
        actions: [
          if (cred != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () async {
                final saved =
                    await context.push<bool>('/credentials/${widget.credentialId}/edit');
                if (saved == true) _load();
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : cred == null
                  ? const SizedBox.shrink()
                  : _buildBody(cred),
    );
  }

  Widget _buildBody(CredentialListItem cred) {
    final typeFields = kCredentialFields[cred.type] ?? const [];
    final isExpired = cred.isExpired;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(credentialTypeIcon(cred.type), style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                          child: Text(_name,
                              style: Theme.of(context).textTheme.titleLarge,
                              overflow: TextOverflow.ellipsis)),
                      if (isExpired) ...[
                        const SizedBox(width: 6),
                        const Chip(
                          label: Text('Expired', style: TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ],
                  ),
                  Text(credentialTypeLabel(cred.type),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              for (final field in typeFields) _buildFieldRow(field),
              if (_notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('NOTES', style: _labelStyle(context)),
                      const SizedBox(height: 4),
                      Text(_notes),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (_customFields.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('CUSTOM FIELDS', style: _labelStyle(context)),
                  ),
                ),
                for (var i = 0; i < _customFields.length; i++) _buildCustomFieldRow(i),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (cred.folderName != null) _metaRow(Icons.folder_outlined, 'Folder', cred.folderName!),
                if (cred.credentialGroupName != null)
                  _metaRow(Icons.inbox_outlined, 'Credential Group', cred.credentialGroupName!),
                if (cred.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: cred.tags
                          .map((t) => Chip(
                                label: Text(t.name, style: const TextStyle(fontSize: 11, color: Colors.white)),
                                backgroundColor: Color(int.parse(
                                        t.color.replaceFirst('#', 'FF'), radix: 16))
                                    .withValues(alpha: 1),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ))
                          .toList(),
                    ),
                  ),
                if (cred.expiryDate != null)
                  _metaRow(Icons.schedule, 'Expires', _formatDate(cred.expiryDate!),
                      valueColor: isExpired ? Colors.red : null),
                const Divider(height: 20),
                Text('Created ${_formatDateTime(cred.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall),
                Text('Updated ${_formatDateTime(cred.updatedAt)}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildAttachmentsSection(cred),
      ],
    );
  }

  Widget _buildAttachmentsSection(CredentialListItem cred) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: Text('Attachments${cred.attachments.isNotEmpty ? ' (${cred.attachments.length})' : ''}'),
            trailing: TextButton.icon(
              onPressed: _uploading ? null : _uploadAttachment,
              icon: _uploading
                  ? const SizedBox(
                      height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_outlined, size: 18),
              label: Text(_uploading ? 'Encrypting…' : 'Add File'),
            ),
          ),
          if (cred.attachments.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('No attachments yet. Files are encrypted before upload.',
                  style: TextStyle(fontSize: 12)),
            )
          else
            for (final att in cred.attachments)
              ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(_attachmentNames[att.id] ?? '…'),
                subtitle: Text('${(att.fileSizeBytes / 1024).toStringAsFixed(1)} KB · '
                    '${_formatDate(att.uploadedAt)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download_outlined, size: 20),
                      tooltip: 'Download',
                      onPressed: () => _downloadAttachment(att),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: 'Delete',
                      onPressed: () => _deleteAttachment(att),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildFieldRow(FieldDef field) {
    final value = _fields[field.key] ?? '';
    if (value.isEmpty || (field.type == 'list' && value == '[]')) return const SizedBox.shrink();

    final isList = field.type == 'list';
    List<String>? listItems;
    if (isList) {
      try {
        listItems = (jsonDecode(value) as List<dynamic>).map((e) => e.toString()).toList();
      } catch (_) {
        listItems = [];
      }
    }
    final displayValue = listItems != null ? listItems.join(', ') : value;
    final isHidden = _hidden[field.key] ?? false;
    final linkHref = listItems == null ? computeFieldLink(field, value, _fields) : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(field.label.toUpperCase(), style: _labelStyle(context)),
                const SizedBox(height: 2),
                if (listItems != null)
                  ...listItems.map((item) {
                    final itemHref = field.linkType == 'network-device-ip'
                        ? networkDeviceLink(_fields['protocol'], item, _fields['port'])
                        : null;
                    return Row(
                      children: [
                        Expanded(child: Text(item)),
                        if (itemHref != null)
                          IconButton(
                            icon: const Icon(Icons.open_in_new, size: 16),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => openSmartLink(itemHref),
                          ),
                      ],
                    );
                  })
                else
                  Text(
                    isHidden ? '•' * 12 : value,
                    style: field.type == 'textarea'
                        ? const TextStyle(fontFamily: 'monospace', fontSize: 12)
                        : null,
                  ),
              ],
            ),
          ),
          if (field.type == 'password')
            IconButton(
              icon: Icon(isHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20),
              onPressed: () => setState(() => _hidden[field.key] = !isHidden),
            ),
          if (linkHref != null)
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 20),
              tooltip: linkTooltip(field),
              onPressed: () => openSmartLink(linkHref),
            ),
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 20),
            onPressed: () => _copy(displayValue, field.key),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomFieldRow(int index) {
    final cf = _customFields[index];
    final key = 'cf_$index';
    final isHidden = cf.fieldType == 'password' ? (_hidden[key] ?? true) : false;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cf.label.toUpperCase(), style: _labelStyle(context)),
                const SizedBox(height: 2),
                Text(isHidden ? '•' * 12 : cf.value),
              ],
            ),
          ),
          if (cf.fieldType == 'password')
            IconButton(
              icon: Icon(isHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20),
              onPressed: () => setState(() => _hidden[key] = !isHidden),
            ),
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 20),
            onPressed: () => _copy(cf.value, key),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).hintColor),
          const SizedBox(width: 8),
          Text('$label: ', style: Theme.of(context).textTheme.bodySmall),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.w600, color: valueColor)),
        ],
      ),
    );
  }

  TextStyle? _labelStyle(BuildContext context) => Theme.of(context)
      .textTheme
      .labelSmall
      ?.copyWith(letterSpacing: 0.5, color: Theme.of(context).hintColor);

  String _formatDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDateTime(DateTime d) =>
      '${_formatDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _CustomField {
  final String label;
  final String value;
  final String fieldType;
  const _CustomField({required this.label, required this.value, required this.fieldType});

  factory _CustomField.fromJson(Map<String, dynamic> json) => _CustomField(
        label: json['label'] as String? ?? '',
        value: json['value'] as String? ?? '',
        fieldType: json['fieldType'] as String? ?? 'text',
      );
}

class _CountdownNotice extends StatefulWidget {
  const _CountdownNotice({required this.seconds});
  final int seconds;

  @override
  State<_CountdownNotice> createState() => _CountdownNoticeState();
}

class _CountdownNoticeState extends State<_CountdownNotice> {
  late int _remaining = widget.seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) {
        t.cancel();
      }
      if (mounted) setState(() => _remaining = (_remaining - 1).clamp(0, widget.seconds));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text('Copied — clipboard clears in ${_remaining}s');
  }
}
