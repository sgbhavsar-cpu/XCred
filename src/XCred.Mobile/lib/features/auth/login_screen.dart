import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_response.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/auth_session.dart';
import '../../core/crypto/crypto_service.dart';
import '../../core/providers/core_providers.dart';
import '../session/biometric_enroll_dialog.dart';

/// FR-AUTH-02 — three fields, deliberately not collapsed (see
/// docs/planning/high-level-design.md §1.2): the login password authenticates to the
/// server; the master password never leaves this device and only ever feeds
/// [AuthRepository.login]'s client-side key derivation.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _loginPassword = TextEditingController();
  final _masterPassword = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _loginPassword.dispose();
    _masterPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final session = await ref.read(authRepositoryProvider).login(
            username: _username.text.trim(),
            loginPassword: _loginPassword.text,
            masterPassword: _masterPassword.text,
          );
      await _handlePostLoginEnrollment(session);
      ref.invalidate(resumableSessionProvider);
      ref.read(authSessionProvider.notifier).setSession(session);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on MasterPasswordException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// MOB-SESS-01 — runs before [authSessionProvider] is set so the enrollment dialog
  /// (if shown) appears on top of this screen rather than racing the router's redirect
  /// to /dashboard. If a wrapped key already exists (re-login via the /unlock screen's
  /// "enter master password instead" escape hatch), just refresh the persisted tokens —
  /// don't re-ask.
  Future<void> _handlePostLoginEnrollment(AuthSession session) async {
    final vault = ref.read(secureVaultStorageProvider);
    final persistence = ref.read(sessionPersistenceProvider);

    if (await vault.hasWrappedKey()) {
      await persistence.save(session);
      return;
    }
    if (await persistence.hasAskedBiometricEnrollment()) return;

    // Bounded: a slow/stuck platform-channel query (seen on some emulator images with
    // no enrolled biometrics/PIN configured) must never be able to block login itself —
    // this check is a silent background probe, not something the user is waiting on.
    final available = await ref
        .read(biometricGateProvider)
        .isAvailable()
        .timeout(const Duration(seconds: 3), onTimeout: () => false);
    if (!available || !mounted) return;

    final wantsEnroll = await showBiometricEnrollDialog(context);
    await persistence.markBiometricEnrollmentAsked();
    if (!wantsEnroll) return;

    final confirmed =
        await ref.read(biometricGateProvider).authenticate('Enable Quick Unlock');
    if (confirmed) {
      await vault.storeWrappedKey(encodePkcs8(session.privateKey));
      await persistence.save(session);
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverUrl = ref.watch(serverBaseUrlProvider).value;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text('Welcome back', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                if (serverUrl != null)
                  GestureDetector(
                    onTap: () async {
                      await ref.read(serverBaseUrlProvider.notifier).clear();
                    },
                    child: Text(
                      '$serverUrl  ·  Change',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _username,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _loginPassword,
                  decoration: const InputDecoration(labelText: 'Login password'),
                  obscureText: true,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _masterPassword,
                  decoration: const InputDecoration(labelText: 'Master password'),
                  obscureText: true,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Your master password never leaves this device.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Log In'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _submitting ? null : () => context.go('/register'),
                  child: const Text("Don't have an account? Register"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
