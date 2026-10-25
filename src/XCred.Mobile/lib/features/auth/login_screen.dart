import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_response.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/auth_session.dart';
import '../../core/crypto/crypto_service.dart';
import '../../core/providers/core_providers.dart';
import '../../core/providers/saved_login_providers.dart';
import '../../core/providers/server_providers.dart';
import '../../core/session/saved_login.dart';
import '../setup/servers_sheet.dart';
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
  // "Remember login on this device": until the user touches the switch it simply mirrors
  // whether this server already has a saved login.
  bool _remember = false;
  bool _rememberTouched = false;

  @override
  void dispose() {
    _username.dispose();
    _loginPassword.dispose();
    _masterPassword.dispose();
    super.dispose();
  }

  bool get _effectiveRemember {
    if (_rememberTouched) return _remember;
    final server = ref.read(activeServerProvider);
    final saved = ref.read(savedLoginUsernamesProvider).value;
    return server != null && saved != null && saved.containsKey(server.id);
  }

  /// Saves (or forgets) this server's login after a successful sign-in. A storage hiccup must
  /// never turn a good login into a failed one, so errors are swallowed.
  Future<void> _persistRememberChoice(bool remember, String username, String loginPassword, String masterPassword) async {
    final server = ref.read(activeServerProvider);
    if (server == null) return;
    try {
      final store = ref.read(savedLoginStoreProvider);
      if (remember && (ref.read(biometricAvailableProvider).value ?? false)) {
        await store.save(server.id,
            SavedLogin(username: username, loginPassword: loginPassword, masterPassword: masterPassword));
      } else if (!remember) {
        await store.forget(server.id);
      }
      await ref.read(savedLoginUsernamesProvider.notifier).refresh();
    } catch (_) {}
  }

  /// One-tap login: a fresh biometric / device-unlock check releases the saved credentials, which
  /// then go through the normal login (so a changed password fails here, visibly, like any other).
  Future<void> _loginWithSaved() async {
    final server = ref.read(activeServerProvider);
    if (server == null) return;
    setState(() => _error = null);
    final ok = await ref.read(biometricGateProvider).authenticate('Log in to ${server.name}');
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = 'Authentication failed or was cancelled.');
      return;
    }
    final saved = await ref.read(savedLoginStoreProvider).read(server.id);
    if (!mounted) return;
    if (saved == null) {
      setState(() => _error = 'No saved login found for this server.');
      await ref.read(savedLoginUsernamesProvider.notifier).refresh();
      return;
    }
    _username.text = saved.username;
    _loginPassword.text = saved.loginPassword;
    _masterPassword.text = saved.masterPassword;
    await _submit();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final remember = _effectiveRemember;
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
      await _persistRememberChoice(
          remember, _username.text.trim(), _loginPassword.text, _masterPassword.text);
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
    final activeServer = ref.watch(activeServerProvider);
    final savedUsers = ref.watch(savedLoginUsernamesProvider).value;
    final savedUser = activeServer == null ? null : savedUsers?[activeServer.id];
    final canRemember = ref.watch(biometricAvailableProvider).value ?? false;
    final remember = _rememberTouched ? _remember : savedUser != null;
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
                  // Server switcher: shows the friendly name + address, opens the saved list.
                  InkWell(
                    key: const ValueKey('server_switcher'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: _submitting ? null : () => showServersSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.dns_outlined, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(activeServer?.name ?? serverUrl,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                if (activeServer != null)
                                  Text(serverUrl,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                if (savedUser != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    key: const ValueKey('login_with_saved'),
                    onPressed: _submitting ? null : _loginWithSaved,
                    icon: const Icon(Icons.fingerprint),
                    label: Text('Log in as $savedUser'),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text('or enter your details below',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
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
                if (canRemember)
                  SwitchListTile(
                    key: const ValueKey('remember_login'),
                    contentPadding: EdgeInsets.zero,
                    value: remember,
                    onChanged: _submitting
                        ? null
                        : (v) => setState(() {
                              _rememberTouched = true;
                              _remember = v;
                            }),
                    title: const Text('Remember login on this device'),
                    subtitle: const Text(
                        'Your username and both passwords are stored encrypted on this phone for this '
                        'server, and released only after fingerprint / device unlock.'),
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
