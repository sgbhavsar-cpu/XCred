import 'package:flutter/material.dart';

/// Small icon-only toolbar button shared by the Credentials/Folders/Tags search rows —
/// used both as a filter toggle (active tints the icon, same idiom as
/// credentials_tree_screen.dart's own `_TypeFilterButton`) and as a plain action button
/// (CSV export) when `active` is left null.
class ToolbarIconButton extends StatelessWidget {
  const ToolbarIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.active,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool? active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: active == true ? Theme.of(context).colorScheme.primary : null),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}
