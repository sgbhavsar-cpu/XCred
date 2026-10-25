import 'package:flutter/material.dart';

/// One row in the shared option picker.
class PickOption<T> {
  const PickOption({required this.value, required this.label, this.hint, this.leading});
  final T value;
  final String label;

  /// Muted second line (e.g. an email address) — also searched.
  final String? hint;
  final Widget? leading;
}

/// Wraps the chosen value so a *null* choice ("No folder") can be told apart from the
/// sheet being dismissed (which returns a plain `null`).
class PickedValue<T> {
  const PickedValue(this.value);
  final T value;
}

/// The search box shows once there are more options than this.
const kPickerSearchThreshold = 5;

/// The list shows this many rows before it scrolls.
const kPickerVisibleRows = 6;

/// Case- and punctuation-insensitive, so "wifi" finds "Wi-Fi" — same rule as the web app.
String normalizeForPicker(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '');

/// Filters [options] by whitespace-separated words (all must match label or hint).
List<PickOption<T>> filterPickOptions<T>(List<PickOption<T>> options, String query) {
  final tokens = normalizeForPicker(query).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (tokens.isEmpty) return options;
  return options.where((o) {
    final hay = normalizeForPicker('${o.label} ${o.hint ?? ''}');
    return tokens.every(hay.contains);
  }).toList();
}

/// The one picker used across the app (replaces `DropdownButtonFormField`):
///  * a search box (with a clear "X") when there are more than [kPickerSearchThreshold] options,
///  * at most [kPickerVisibleRows] rows tall, then the list scrolls,
///  * an optional "+ New" action in the header ([onCreate]) to make a record without leaving the
///    current screen — it returns the new option's value, which is then picked immediately.
/// Returns null when dismissed, else the chosen value wrapped in [PickedValue].
Future<PickedValue<T>?> showOptionPicker<T>(
  BuildContext context, {
  required String title,
  required List<PickOption<T>> options,
  required T selected,
  Future<T?> Function()? onCreate,
  String createLabel = 'New',
  bool? searchable,
}) {
  return showModalBottomSheet<PickedValue<T>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _OptionPickerSheet<T>(
      title: title,
      options: options,
      selected: selected,
      onCreate: onCreate,
      createLabel: createLabel,
      searchable: searchable ?? options.length > kPickerSearchThreshold,
    ),
  );
}

class _OptionPickerSheet<T> extends StatefulWidget {
  const _OptionPickerSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.onCreate,
    required this.createLabel,
    required this.searchable,
  });
  final String title;
  final List<PickOption<T>> options;
  final T selected;
  final Future<T?> Function()? onCreate;
  final String createLabel;
  final bool searchable;

  @override
  State<_OptionPickerSheet<T>> createState() => _OptionPickerSheetState<T>();
}

class _OptionPickerSheetState<T> extends State<_OptionPickerSheet<T>> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final value = await widget.onCreate!();
    if (value != null && mounted) Navigator.of(context).pop(PickedValue<T>(value));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filterPickOptions(widget.options, _controller.text);
    final hasHints = widget.options.any((o) => o.hint != null);
    final rowHeight = hasHints ? 64.0 : 52.0;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
                if (widget.onCreate != null)
                  TextButton.icon(
                    key: const ValueKey('picker_create'),
                    onPressed: _create,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(widget.createLabel),
                  ),
                IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          if (widget.searchable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                key: const ValueKey('picker_search'),
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: 'Search…',
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          key: const ValueKey('picker_search_clear'),
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'Clear search',
                          onPressed: () => setState(_controller.clear),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: rowHeight * kPickerVisibleRows),
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No matches')),
                  )
                : ListView.builder(
                    key: const ValueKey('picker_list'),
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final o = filtered[i];
                      final isSelected = o.value == widget.selected;
                      return ListTile(
                        leading: o.leading,
                        title: Text(o.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: o.hint == null
                            ? null
                            : Text(o.hint!, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: isSelected ? const Icon(Icons.check) : null,
                        selected: isSelected,
                        onTap: () => Navigator.of(context).pop(PickedValue<T>(o.value)),
                      );
                    },
                  ),
          ),
          if (widget.options.length > kPickerVisibleRows)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                filtered.length == widget.options.length
                    ? '${widget.options.length} items'
                    : '${filtered.length} of ${widget.options.length}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
