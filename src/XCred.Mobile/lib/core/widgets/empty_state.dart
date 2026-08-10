import 'package:flutter/material.dart';

/// MOB-POLISH-01 — icon + message (+ optional action), matching
/// docs/artifacts/flutter-mobile-mockup.html's `.empty` pattern. Replaces what had
/// grown into four byte-for-byte-identical local `_emptyState(String)` helpers
/// (admin/shares/teams/credentials-tree screens) plus two more inline-but-diverged
/// icon+text+button versions (folders/tags) — one shared widget for both the "genuinely
/// empty" and "failed to load" cases, so every list screen looks and behaves the same
/// way instead of accumulating small variations over time.
///
/// Wrapped in a scrollable that fills the available height (not just `Center`) so this
/// still works as the child of a `RefreshIndicator` — pull-to-refresh needs a
/// scrollable descendant even when there's nothing to scroll.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 40, color: Theme.of(context).hintColor),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 12),
                    TextButton(onPressed: onAction, child: Text(actionLabel!)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
