import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_theme.dart';

/// MOB-SRV-01 — first-run server URL entry (design: high-level-design.md §1.1).
/// "Test Connection" hits `GET /api/dashboard` unauthenticated and expects a 401 —
/// that's proof the URL points at a real XCred API (matches the same acceptance check
/// used to confirm the dev backend in Sprint 0.1), not just proof *something* answered.
class ServerSetupScreen extends ConsumerStatefulWidget {
  const ServerSetupScreen({super.key});

  @override
  ConsumerState<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends ConsumerState<ServerSetupScreen> {
  final _controller = TextEditingController(text: 'http://10.0.2.2:18080');
  bool _testing = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _normalize(String raw) {
    var url = raw.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  Future<void> _testAndContinue() async {
    final url = _normalize(_controller.text);
    if (url.isEmpty) {
      setState(() => _error = 'Enter a server URL.');
      return;
    }
    setState(() {
      _testing = true;
      _error = null;
    });
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ));
      await dio.get('$url/api/dashboard');
      // A 200 here would be unusual (unauthenticated) but still proves reachability.
      await ref.read(serverBaseUrlProvider.notifier).set(url);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Expected: server reachable, correctly rejecting the unauthenticated call.
        await ref.read(serverBaseUrlProvider.notifier).set(url);
      } else {
        setState(() => _error = 'Could not reach an XCred server at that URL.');
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
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
                'Connect to your organization\'s XCred server to continue.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _controller,
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
                onPressed: _testing ? null : _testAndContinue,
                child: _testing
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
