import 'package:flutter/material.dart';

/// The search box used on every list screen: magnifier on the left and, once there is text,
/// an "X" on the right that clears it in one tap (the keyboard stays up so typing can resume).
class ClearableSearchField extends StatelessWidget {
  const ClearableSearchField({
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search name, IP, user, notes, tags…',
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search, size: 20),
          hintText: hintText,
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  key: const ValueKey('search_clear'),
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Clear search',
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
