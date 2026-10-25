import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/share_models.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/providers/share_providers.dart';
import '../../../core/providers/vault_providers.dart';
import '../../../core/vault/credential_csv.dart';
import '../../../core/widgets/option_picker.dart';
import '../../../core/widgets/picker_field.dart';

String _plural(int n) => '$n credential${n == 1 ? '' : 's'}';

/// Exports just the selected credentials as CSV (same metadata-only summary as the screens'
/// whole-list export — password values are never included).
Future<void> bulkExportSelected(BuildContext context, WidgetRef ref, List<String> ids) async {
  final vault = ref.read(vaultProvider).value;
  if (vault == null) return;
  final picked = vault.credentials.where((c) => ids.contains(c.id)).toList();
  final csv = buildCredentialsCsv(picked, vault.decrypted);
  final filename = 'xcred-selected-${DateTime.now().toIso8601String().split('T').first}.csv';
  await ref
      .read(fileExchangeProvider)
      .saveOrShare(filename, Uint8List.fromList(utf8.encode(csv)), 'text/csv');
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Exported ${_plural(picked.length)} to CSV.')));
  }
}

/// Confirms, then soft-deletes every selected credential in one request.
Future<void> bulkDeleteSelected(
  BuildContext context,
  WidgetRef ref,
  List<String> ids,
  VoidCallback onDone,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete ${_plural(ids.length)}?'),
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
  if (ok != true) return;
  try {
    final result = await ref.read(vaultProvider.notifier).bulkDelete(ids);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Deleted ${_plural(result.updated)}.')));
    }
    onDone();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Bulk delete failed.')));
    }
  }
}

/// Share every selected credential with one user (optional expiry / revoke-if-changed) —
/// mirrors the web app's `BulkShareModal`; the per-credential key re-wrapping happens in
/// [VaultNotifier.bulkShare].
Future<void> showBulkShareSheet(
  BuildContext context, {
  required List<String> credentialIds,
  required VoidCallback onApplied,
  /// Names the folder / credential group being shared ("Share 4 credentials from <title>").
  String? title,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        _BulkShareSheet(credentialIds: credentialIds, onApplied: onApplied, title: title),
  );
}

class _BulkShareSheet extends ConsumerStatefulWidget {
  const _BulkShareSheet({required this.credentialIds, required this.onApplied, this.title});
  final List<String> credentialIds;
  final VoidCallback onApplied;
  final String? title;

  @override
  ConsumerState<_BulkShareSheet> createState() => _BulkShareSheetState();
}

class _BulkShareSheetState extends ConsumerState<_BulkShareSheet> {
  String? _userId;
  DateTime? _expiry;
  bool _untilChanged = false;
  bool _sharing = false;

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  Future<void> _share(List<UserSummary> users) async {
    final recipient = users.firstWhere((u) => u.id == _userId);
    setState(() => _sharing = true);
    try {
      final r = await ref.read(vaultProvider.notifier).bulkShare(
            credentialIds: widget.credentialIds,
            recipient: recipient,
            expiresAt: _expiry,
            untilChanged: _untilChanged,
          );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (r.shared > 0) {
        // The "shared" badges on rows and the Shared screen's "by me" tab both read this.
        ref.read(sharesByCredentialProvider.notifier).refresh();
        ref.invalidate(sharedByMeProvider);
        messenger.showSnackBar(SnackBar(
            content: Text('Shared ${_plural(r.shared)} with ${recipient.username}.')));
      }
      if (r.failed > 0) {
        messenger.showSnackBar(SnackBar(content: Text('${_plural(r.failed)} could not be shared.')));
        setState(() => _sharing = false);
        return;
      }
      Navigator.of(context).pop();
      widget.onApplied();
    } catch (_) {
      if (mounted) {
        setState(() => _sharing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Bulk share failed.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);
    final users = usersAsync.value ?? const <UserSummary>[];
    final count = widget.credentialIds.length;
    return Padding(
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Share ${_plural(count)}${widget.title == null ? '' : ' from ${widget.title}'}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 8),
          if (usersAsync.isLoading && users.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
          else if (users.isEmpty)
            const Text('No other users in the organisation.')
          else
            PickerField<String?>(
              key: const ValueKey('bulk_share_user'),
              label: 'Share with',
              placeholder: 'Select a user…',
              value: _userId,
              options: [
                for (final u in users)
                  PickOption<String?>(value: u.id, label: u.username, hint: u.email),
              ],
              onChanged: (v) => setState(() => _userId = v),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: _pickExpiry,
                icon: const Icon(Icons.event, size: 18),
                label: Text(_expiry == null
                    ? 'Access expires (optional)'
                    : 'Expires ${_expiry!.toIso8601String().substring(0, 10)}'),
              ),
              if (_expiry != null)
                IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: 'No expiry',
                    onPressed: () => setState(() => _expiry = null)),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Revoke access automatically if a credential is updated'),
            value: _untilChanged,
            onChanged: (v) => setState(() => _untilChanged = v),
          ),
          Text(
            "Each credential's key is re-encrypted with the recipient's public key on this device — the server never sees the plaintext.",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _sharing ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: (_userId == null || _sharing) ? null : () => _share(users),
                  child: Text(_sharing ? 'Sharing…' : 'Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
