import 'package:flutter/material.dart';

/// Swaps to a "N selected" bar with Select-All/Bulk-Edit actions once anything is
/// selected — used by the Folders/Tags/Credentials screens' multi-select mode. There's
/// no prior "selection mode" precedent in this app (unlike the always-visible checkboxes
/// the web app uses on its wide desktop rows); long-press-to-select then use this bar is
/// the standard mobile pattern instead.
AppBar buildSelectionAwareAppBar({
  required int selectedCount,
  required VoidCallback onClearSelection,
  required VoidCallback onSelectAll,
  required VoidCallback onBulkEdit,
  required String normalTitle,
  List<Widget>? normalActions,
}) {
  if (selectedCount == 0) {
    return AppBar(title: Text(normalTitle), actions: normalActions);
  }
  return AppBar(
    leading: IconButton(
      icon: const Icon(Icons.close),
      tooltip: 'Clear selection',
      onPressed: onClearSelection,
    ),
    title: Text('$selectedCount selected'),
    actions: [
      IconButton(icon: const Icon(Icons.select_all), tooltip: 'Select all', onPressed: onSelectAll),
      IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Bulk edit', onPressed: onBulkEdit),
    ],
  );
}
