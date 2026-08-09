import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_response.dart';
import '../../core/crypto/password_strength.dart';
import '../../core/providers/core_providers.dart';

/// FR-AUTH-01 — username, email, login password (+confirm, min 8 chars), master
/// password (+confirm, min 12 chars), mandatory no-recovery acknowledgment. The key
/// pair + KDF salt are generated entirely client-side inside [AuthRepository.register]
/// before anything is sent — the server only ever sees the final public artifacts.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _loginPassword = TextEditingController();
  final _confirmLoginPassword = TextEditingController();
  final _masterPassword = TextEditingController();
  final _confirmMasterPassword = TextEditingController();
  bool _acknowledged = false;
  bool _submitting = false;
  String? _error;
  String? _successMessage;
  String _masterStrengthText = '';

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _loginPassword.dispose();
    _confirmLoginPassword.dispose();
    _masterPassword.dispose();
    _confirmMasterPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acknowledged) {
      setState(() => _error = 'You must acknowledge that master password recovery is not possible.');
      return;
    }
    if (_loginPassword.text != _confirmLoginPassword.text) {
      setState(() => _error = 'Login passwords do not match.');
      return;
    }
    if (_masterPassword.text != _confirmMasterPassword.text) {
      setState(() => _error = 'Master passwords do not match.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final message = await ref.read(authRepositoryProvider).register(
            fullName: _username.text.trim(),
            username: _username.text.trim(),
            email: _email.text.trim(),
            loginPassword: _loginPassword.text,
            masterPassword: _masterPassword.text,
          );
      setState(() => _successMessage = message);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_successMessage != null) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.check_circle_outline, size: 56, color: Colors.green),
                const SizedBox(height: 16),
                Text(_successMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Go to Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _username,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 20),
                Text('Login Password', style: Theme.of(context).textTheme.labelLarge),
                const Text('Used to sign in. Does not protect your data.',
                    style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _loginPassword,
                  decoration: const InputDecoration(labelText: 'Login password'),
                  obscureText: true,
                  validator: (v) =>
                      (v == null || v.length < 8) ? 'Minimum 8 characters' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmLoginPassword,
                  decoration: const InputDecoration(labelText: 'Confirm login password'),
                  obscureText: true,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                Text('Master Password', style: Theme.of(context).textTheme.labelLarge),
                const Text('Encrypts your vault. Never sent to the server. Cannot be recovered.',
                    style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _masterPassword,
                  decoration: InputDecoration(
                    labelText: 'Master password',
                    helperText: _masterStrengthText.isEmpty ? null : _masterStrengthText,
                  ),
                  obscureText: true,
                  autocorrect: false,
                  onChanged: (v) => setState(
                      () => _masterStrengthText = 'Strength: ${passwordStrength(v).label}'),
                  validator: (v) =>
                      (v == null || v.length < 12) ? 'Minimum 12 characters' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmMasterPassword,
                  decoration: const InputDecoration(labelText: 'Confirm master password'),
                  obscureText: true,
                  autocorrect: false,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _acknowledged,
                  onChanged: (v) => setState(() => _acknowledged = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'I understand that if I forget my master password, my vault data '
                    'cannot be recovered.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Create Account'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _submitting ? null : () => context.go('/login'),
                  child: const Text('Already have an account? Log In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
