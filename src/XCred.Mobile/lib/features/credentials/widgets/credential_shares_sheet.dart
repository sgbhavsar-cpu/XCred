import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/error_messages.dart';
import '../../../core/models/share_models.dart';
import '../../../core/providers/share_providers.dart';

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// "Who can see this credential?" — one card per recipient with the access end date and the
/// revoke-if-the-credential-changes switch (both editable, saved per card) plus an immediate
/// "Stop sharing". Opened from the shared badge on a credential row.
Future<void> showCredentialSharesSheet(
  BuildContext context, {
  required String credentialId,
  required String credentialName,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _SharesSheet(credentialId: credentialId, credentialName: credentialName),
  );
}

class _Edit {
  _Edit(this.expiresAt, this.untilChanged);
  DateTime? expiresAt;
  bool untilChanged;
}

class _SharesSheet extends ConsumerStatefulWidget {
  const _SharesSheet({required this.credentialId, required this.credentialName});
  final String credentialId;
  final String credentialName;

  @override
  ConsumerState<_SharesSheet> createState() => _SharesSheetState();
}

class _SharesSheetState extends ConsumerState<_SharesSheet> {
  final Map<String, _Edit> _edits = {};
  bool _busy = false;

  _Edit _view(SharedCredentialSummary s) =>
      _edits[s.id] ?? _Edit(s.expiresAt, s.untilChanged);

  bool _dirty(SharedCredentialSummary s) {
    final e = _edits[s.id];
    if (e == null) return false;
    final before = s.expiresAt == null ? '' : _fmt(s.expiresAt!);
    final after = e.expiresAt == null ? '' : _fmt(e.expiresAt!);
    return before != after || e.untilChanged != s.untilChanged;
  }

  void _patch(SharedCredentialSummary s, {DateTime? expiresAt, bool clearDate = false, bool? untilChanged}) {
    final cur = _view(s);
    setState(() => _edits[s.id] = _Edit(
          clearDate ? null : (expiresAt ?? cur.expiresAt),
          untilChanged ?? cur.untilChanged,
        ));
  }

  Future<void> _pickDate(SharedCredentialSummary s) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _view(s).expiresAt ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(2100),
    );
    if (picked != null) _patch(s, expiresAt: picked);
  }

  Future<void> _refresh() async {
    await ref.read(sharesByCredentialProvider.notifier).refresh();
    ref.invalidate(sharedByMeProvider); // the Shared screen's "by me" tab
  }

  Future<void> _save(SharedCredentialSummary s) async {
    final e = _view(s);
    setState(() => _busy = true);
    try {
      await ref.read(sharesRepositoryProvider).update(s.id, expiresAt: e.expiresAt, untilChanged: e.untilChanged);
      _edits.remove(s.id);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share updated.')));
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(err))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String text) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop sharing?'),
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Stop sharing'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _stop(List<SharedCredentialSummary> list, String confirmText) async {
    if (!await _confirm(confirmText)) return;
    setState(() => _busy = true);
    try {
      for (final s in list) {
        await ref.read(sharesRepositoryProvider).revoke(s.id);
      }
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(list.length == 1 ? 'Sharing stopped.' : 'Sharing stopped for everyone.')));
      }
    } catch (err) {
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(err))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shares = ref.watch(sharesByCredentialProvider).value?[widget.credentialId] ??
        const <SharedCredentialSummary>[];
    final hint = Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor);

    return Padding(
      padding: EdgeInsets.only(
          left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.share_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Shared with', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    Text(widget.credentialName, style: hint, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          if (shares.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('This credential is not shared with anyone.')),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final s in shares) _card(s, hint),
                if (shares.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: OutlinedButton.icon(
                      key: const ValueKey('stop_all'),
                      style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                      onPressed: _busy
                          ? null
                          : () => _stop(shares,
                              'Stop sharing "${widget.credentialName}" with all ${shares.length} people? They lose access immediately.'),
                      icon: const Icon(Icons.block, size: 18),
                      label: const Text('Stop sharing with everyone'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(SharedCredentialSummary s, TextStyle? hint) {
    final e = _view(s);
    final who = s.sharedWithUsername ?? s.sharedWithGroupName ?? 'Unknown';
    return Card(
      key: ValueKey('share_${s.id}'),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(who, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                ),
                if (s.isExpired)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('Expired', style: TextStyle(fontSize: 10, color: Colors.red)),
                  ),
                Text('since ${_fmt(s.createdAt)}', style: hint),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: ValueKey('share_date_${s.id}'),
                    onPressed: _busy ? null : () => _pickDate(s),
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(e.expiresAt == null ? 'No end date' : 'Ends ${_fmt(e.expiresAt!)}'),
                  ),
                ),
                if (e.expiresAt != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: 'No end date',
                    onPressed: _busy ? null : () => _patch(s, clearDate: true),
                  ),
              ],
            ),
            SwitchListTile(
              key: ValueKey('share_switch_${s.id}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Revoke if the credential changes'),
              value: e.untilChanged,
              onChanged: _busy ? null : (v) => _patch(s, untilChanged: v),
            ),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: ValueKey('share_save_${s.id}'),
                    onPressed: (_busy || !_dirty(s)) ? null : () => _save(s),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: ValueKey('share_stop_${s.id}'),
                    style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                    onPressed: _busy
                        ? null
                        : () => _stop([s], 'Stop sharing with $who? They lose access immediately.'),
                    icon: const Icon(Icons.block, size: 18),
                    label: const Text('Stop sharing'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
