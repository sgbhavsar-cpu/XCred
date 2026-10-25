import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/server_providers.dart';
import '../../core/session/server_switch.dart';
import '../../core/theme/app_theme.dart';
import 'servers_sheet.dart';

/// MOB-SRV-01 — choose which XCred server to connect to (design: high-level-design.md §1.1).
/// First run shows a small form (name + URL); once servers are saved this becomes a list to
/// pick from, with "Add server" for more — so a URL is only ever typed once. Every address is
/// tested before it is saved: an unauthenticated `GET /api/dashboard` must answer 401, which
/// proves it is a real XCred API and not just *something* that responded.
class ServerSetupScreen extends ConsumerStatefulWidget {
  const ServerSetupScreen({super.key});

  @override
  ConsumerState<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends ConsumerState<ServerSetupScreen> {
  final _name = TextEditingController();
  final _url = TextEditingController();
  bool _testing = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final problem = validateServerUrl(_url.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final url = normalizeServerUrl(_url.text);
    setState(() {
      _testing = true;
      _error = null;
    });
    final reachable = await ref.read(serverCheckProvider)(url);
    if (!mounted) return;
    if (!reachable) {
      setState(() {
        _testing = false;
        _error = 'Could not reach an XCred server at that URL.';
      });
      return;
    }
    final saved = await ref.read(savedServersProvider.notifier).upsert(name: _name.text, url: url);
    await switchServer(ref, saved.url);
    if (mounted) setState(() => _testing = false);
  }

  @override
  Widget build(BuildContext context) {
    final servers = ref.watch(savedServersProvider).value ?? const <SavedServer>[];
    final hasServers = servers.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.shield_outlined, size: 56, color: violet),
                const SizedBox(height: 16),
                Text('XCred', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  hasServers
                      ? 'Choose the server to connect to.'
                      : 'Connect to your organization\'s XCred server to continue.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                if (hasServers) ...[
                  const SavedServersList(),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('setup_add_server'),
                    onPressed: () async {
                      final saved = await showServerEditDialog(context, ref);
                      if (saved != null) await switchServer(ref, saved.url);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add server'),
                  ),
                ] else ...[
                  TextField(
                    key: const ValueKey('setup_name'),
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Name (optional)', hintText: 'e.g. Office'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('setup_url'),
                    controller: _url,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'https://vault.example.com',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const ValueKey('setup_continue'),
                    onPressed: _testing ? null : _connect,
                    child: _testing
                        ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Continue'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
