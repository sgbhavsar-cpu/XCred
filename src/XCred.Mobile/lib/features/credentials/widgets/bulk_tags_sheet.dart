import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/folder_tag_models.dart';
import '../../../core/providers/vault_providers.dart';

enum _TagState { none, add, remove }

Color _hexToColor(String hex) => Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));

/// Bulk tag add/remove across several credentials — mirrors the web app's
/// `BulkTagEditModal`. Unlike folder/group (a single "set to" value), a credential can
/// carry many tags at once, so this is an add/remove delta: tap a tag chip once to add it
/// to every selected credential, again to remove it instead, a third tap to leave it
/// alone.
Future<void> showBulkTagsSheet(
  BuildContext context, {
  required List<String> credentialIds,
  required List<TagSummary> tags,
  required VoidCallback onApplied,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _BulkTagsSheet(credentialIds: credentialIds, tags: tags, onApplied: onApplied),
  );
}

class _BulkTagsSheet extends ConsumerStatefulWidget {
  const _BulkTagsSheet({required this.credentialIds, required this.tags, required this.onApplied});
  final List<String> credentialIds;
  final List<TagSummary> tags;
  final VoidCallback onApplied;

  @override
  ConsumerState<_BulkTagsSheet> createState() => _BulkTagsSheetState();
}

class _BulkTagsSheetState extends ConsumerState<_BulkTagsSheet> {
  final Map<String, _TagState> _states = {};
  bool _applying = false;

  void _cycle(String tagId) {
    setState(() {
      final cur = _states[tagId] ?? _TagState.none;
      _states[tagId] = switch (cur) {
        _TagState.none => _TagState.add,
        _TagState.add => _TagState.remove,
        _TagState.remove => _TagState.none,
      };
    });
  }

  Future<void> _apply() async {
    final addIds = [for (final t in widget.tags) if (_states[t.id] == _TagState.add) t.id];
    final removeIds = [for (final t in widget.tags) if (_states[t.id] == _TagState.remove) t.id];
    setState(() => _applying = true);
    try {
      final result = await ref.read(vaultProvider.notifier).bulkTags(
            credentialIds: widget.credentialIds,
            addTagIds: addIds,
            removeTagIds: removeIds,
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
    final count = widget.credentialIds.length;
    final hasChange = _states.values.any((s) => s != _TagState.none);
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
                child: Text('Bulk edit tags on $count credential${count == 1 ? '' : 's'}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a tag to add it to every selected credential; tap again to remove it instead; a third tap leaves it alone.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 12),
          if (widget.tags.isEmpty)
            const Text('No tags yet — create one from the Tags screen first.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in widget.tags)
                  _TagChip(
                    tag: tag,
                    state: _states[tag.id] ?? _TagState.none,
                    onTap: () => _cycle(tag.id),
                  ),
              ],
            ),
          const SizedBox(height: 16),
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
