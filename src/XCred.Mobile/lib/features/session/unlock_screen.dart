import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_session.dart';
import '../../core/crypto/crypto_service.dart';
import '../../core/providers/core_providers.dart';
import '../../core/theme/app_theme.dart';

/// MOB-SESS-02 — architecture.md §3.2's App Resume path: biometric/PIN check unwraps
/// the already-decrypted private key from [SecureVaultStorage], no network call and no
/// master password needed. Falls back to full login on repeated failure, an explicit
/// "enter master password instead" tap, or if the wrapped key/tokens are missing
/// (rotated elsewhere, or a fresh install landed here transiently).
class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  bool _authenticating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Prompt immediately on arrival — matches the mockup's "biometric primary" flow
    // (high-level-design.md §1.3) rather than waiting for an explicit tap.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _error = null;
    });
    try {
      final gate = ref.read(biometricGateProvider);
      final ok = await gate.authenticate('Unlock XCred');
      if (!ok) {
        setState(() => _error = 'Authentication failed or was cancelled.');
        return;
      }

      final vault = ref.read(secureVaultStorageProvider);
      final wrapped = await vault.retrieveWrappedKey();
      final persisted = await ref.read(sessionPersistenceProvider).load();
      if (wrapped == null || persisted == null) {
        // Wrapped key or tokens are gone (master-password rotation, logout elsewhere) —
        // architecture.md §3.2 point 4: fall back to full login, not a dead end.
        await ref.read(sessionPersistenceProvider).clear();
        await vault.clear();
        ref.invalidate(resumableSessionProvider);
        if (mounted) context.go('/login');
        return;
      }

      final privateKey = decodePkcs8(wrapped);
      ref.read(authSessionProvider.notifier).setSession(AuthSession(
            userId: persisted.userId,
            username: persisted.username,
            email: persisted.email,
            role: persisted.role,
            accessToken: persisted.accessToken,
            refreshToken: persisted.refreshToken,
            expiresAt: persisted.expiresAt,
            publicKeySpkiB64: persisted.publicKeySpkiB64,
            masterKey: null,
            privateKey: privateKey,
          ));
    } finally {
      if (mounted) setState(() => _authenticating = false);
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
              Icon(Icons.fingerprint, size: 72, color: violet),
              const SizedBox(height: 16),
              Text('Unlock XCred',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              if (_authenticating)
                const Center(child: CircularProgressIndicator())
              else ...[
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: _unlock,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Try Again'),
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: _authenticating ? null : () => context.go('/login'),
                child: const Text('Enter master password instead'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
