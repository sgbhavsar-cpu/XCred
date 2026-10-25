import 'package:flutter/material.dart';

import 'option_picker.dart';

/// Form-field look-alike that opens [showOptionPicker] — the app's one dropdown. With
/// [onCreate] a "+" button sits after the field so a new record (folder, credential group…)
/// can be made without leaving the editor; the new value is selected right away.
class PickerField<T> extends StatelessWidget {
  const PickerField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.onCreate,
    this.createTooltip = 'Create new',
    this.title,
    this.enabled = true,
    this.dense = false,
    this.placeholder,
    super.key,
  });

  final String label;
  final T value;
  final List<PickOption<T>> options;
  final ValueChanged<T> onChanged;

  /// Makes a new record and returns its value (or null if cancelled).
  final Future<T?> Function()? onCreate;
  final String createTooltip;
  final String? title;
  final bool enabled;
  final bool dense;
  final String? placeholder;

  Future<void> _open(BuildContext context) async {
    final picked = await showOptionPicker<T>(
      context,
      title: title ?? label,
      options: options,
      selected: value,
      onCreate: onCreate,
      createLabel: 'New',
    );
    if (picked != null) onChanged(picked.value);
  }

  Future<void> _create() async {
    final created = await onCreate!();
    if (created != null) onChanged(created);
  }

  @override
  Widget build(BuildContext context) {
    PickOption<T>? current;
    for (final o in options) {
      if (o.value == value) {
        current = o;
        break;
      }
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: InkWell(
            onTap: enabled ? () => _open(context) : null,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                isDense: dense,
                suffixIcon: const Icon(Icons.arrow_drop_down),
                enabled: enabled,
              ),
              child: Row(
                children: [
                  if (current?.leading != null) ...[current!.leading!, const SizedBox(width: 8)],
                  Expanded(
                    child: Text(
                      current?.label ?? placeholder ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (onCreate != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: IconButton.outlined(
              key: const ValueKey('picker_field_create'),
              icon: const Icon(Icons.add),
              tooltip: createTooltip,
              onPressed: enabled ? _create : null,
            ),
          ),
      ],
    );
  }
}
