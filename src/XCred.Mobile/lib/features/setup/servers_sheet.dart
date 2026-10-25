import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/providers/saved_login_providers.dart';
import '../../core/providers/server_providers.dart';
import '../../core/session/server_switch.dart';

/// Add / edit one saved server: a friendly name plus its URL. Saving tests the address first
/// (it must answer like an XCred API) so a typo is caught here, not at login. Returns the saved
/// entry, or null when cancelled.
Future<SavedServer?> showServerEditDialog(
  BuildContext context,
  WidgetRef ref, {
  SavedServer? existing,
}) {
  return showDialog<SavedServer>(
    context: context,
    builder: (context) => _ServerEditDialog(existing: existing),
  );
}

class _ServerEditDialog extends ConsumerStatefulWidget {
  const _ServerEditDialog({this.existing});
  final SavedServer? existing;

  @override
  ConsumerState<_ServerEditDialog> createState() => _ServerEditDialogState();
}

class _ServerEditDialogState extends ConsumerState<_ServerEditDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _url = TextEditingController(text: widget.existing?.url ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final problem = validateServerUrl(_url.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final url = normalizeServerUrl(_url.text);
    setState(() {
      _busy = true;
      _error = null;
    });
    final reachable = await ref.read(serverCheckProvider)(url);
    if (!mounted) return;
    if (!reachable) {
      setState(() {
        _busy = false;
        _error = 'Could not reach an XCred server at that URL.';
      });
      return;
    }
    final saved = await ref
        .read(savedServersProvider.notifier)
        .upsert(id: widget.existing?.id, name: _name.text, url: url);
    if (mounted) Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add server' : 'Edit server'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('server_name'),
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Office'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('server_url'),
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                  labelText: 'Server URL', hintText: 'https://vault.example.com'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          key: const ValueKey('server_save'),
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Test & Save'),
        ),
      ],
    );
  }
}

/// The list of saved servers — shared by the login screen's switcher sheet and the first-run
/// setup screen. Tapping a row calls [onPicked] after making it the active server; the ⋮ menu
/// edits or removes it (the active server can't be removed).
class SavedServersList extends ConsumerWidget {
  const SavedServersList({this.onPicked, super.key});
  final VoidCallback? onPicked;

  Future<void> _edit(BuildContext context, WidgetRef ref, SavedServer server, bool isActive) async {
    final saved = await showServerEditDialog(context, ref, existing: server);
    if (saved == null) return;
    if (isActive && saved.url != server.url) {
      await switchServer(ref, saved.url); // edited the address of the server in use
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, SavedServer server) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove "${server.name}"?'),
        content: const Text('It is only removed from this list — nothing changes on the server.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(savedLoginStoreProvider).forget(server.id); // its remembered login goes with it
    await ref.read(savedServersProvider.notifier).remove(server.id);
  }

  Future<void> _forgetLogin(BuildContext context, WidgetRef ref, SavedServer server) async {
    await ref.read(savedLoginStoreProvider).forget(server.id);
    await ref.read(savedLoginUsernamesProvider.notifier).refresh();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Saved login for "${server.name}" removed.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(savedServersProvider).value ?? const <SavedServer>[];
    final activeUrl = ref.watch(serverBaseUrlProvider).value;
    final savedUsers = ref.watch(savedLoginUsernamesProvider).value ?? const <String, String>{};
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final s in servers)
          ListTile(
            key: ValueKey('server_${s.id}'),
            leading: Icon(s.url == activeUrl ? Icons.radio_button_checked : Icons.radio_button_off,
                color: s.url == activeUrl ? Theme.of(context).colorScheme.primary : null),
            title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (savedUsers[s.id] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.fingerprint, size: 14),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text('Saved login: ${savedUsers[s.id]}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              key: ValueKey('server_menu_${s.id}'),
              tooltip: 'Server actions',
              onSelected: (v) {
                if (v == 'edit') _edit(context, ref, s, s.url == activeUrl);
                if (v == 'forget') _forgetLogin(context, ref, s);
                if (v == 'delete') _delete(context, ref, s);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
                if (savedUsers[s.id] != null)
                  const PopupMenuItem(
                      value: 'forget',
                      child: ListTile(leading: Icon(Icons.no_accounts_outlined), title: Text('Forget saved login'))),
                if (s.url != activeUrl)
                  const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Remove'))),
              ],
            ),
            onTap: () async {
              await switchServer(ref, s.url);
              onPicked?.call();
            },
          ),
      ],
    );
  }
}

/// Bottom sheet opened from the login screen: pick another saved server, or add one — no
/// retyping of URLs. Switching signs out of the old server first (see [switchServer]).
Future<void> showServersSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const _ServersSheet(),
  );
}

class _ServersSheet extends ConsumerWidget {
  const _ServersSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hint = Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Servers', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
                IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: SavedServersList(onPicked: () => Navigator.of(context).pop()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
                'Switching signs you out of the current server and clears this device\'s cached copy of its data.',
                style: hint),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OutlinedButton.icon(
              key: const ValueKey('add_server'),
              onPressed: () async {
                final saved = await showServerEditDialog(context, ref);
                if (saved == null || !context.mounted) return;
                await switchServer(ref, saved.url);
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add server'),
            ),
          ),
        ],
      ),
    );
  }
}
