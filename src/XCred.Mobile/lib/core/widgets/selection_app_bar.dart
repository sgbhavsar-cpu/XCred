import 'package:flutter/material.dart';

/// Swaps to a "N selected" bar with Select-All/Bulk-Edit actions (plus Share / Export CSV / Delete in an overflow menu) once anything is
/// selected — used by the Folders/Tags/Credentials screens' multi-select mode. There's
/// no prior "selection mode" precedent in this app (unlike the always-visible checkboxes
/// the web app uses on its wide desktop rows); long-press-to-select then use this bar is
/// the standard mobile pattern instead.
AppBar buildSelectionAwareAppBar({
  required int selectedCount,
  required VoidCallback onClearSelection,
  required VoidCallback onSelectAll,
  required VoidCallback onBulkEdit,
  VoidCallback? onShare,
  VoidCallback? onExportCsv,
  VoidCallback? onDelete,
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
      if (onShare != null || onExportCsv != null || onDelete != null)
        PopupMenuButton<String>(
          tooltip: 'More actions',
          onSelected: (v) {
            if (v == 'share') onShare?.call();
            if (v == 'export') onExportCsv?.call();
            if (v == 'delete') onDelete?.call();
          },
          itemBuilder: (context) => [
            if (onShare != null)
              const PopupMenuItem(value: 'share', child: ListTile(leading: Icon(Icons.share_outlined), title: Text('Share'))),
            if (onExportCsv != null)
              const PopupMenuItem(value: 'export', child: ListTile(leading: Icon(Icons.table_view_outlined), title: Text('Export CSV'))),
            if (onDelete != null)
              const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete'))),
          ],
        ),
    ],
  );
}
