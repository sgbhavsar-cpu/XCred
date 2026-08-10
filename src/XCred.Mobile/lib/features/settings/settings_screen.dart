import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_response.dart';
import '../../core/crypto/crypto_service.dart';
import '../../core/models/settings_models.dart';
import '../../core/providers/core_providers.dart';
import '../../core/providers/settings_providers.dart';
import '../../core/providers/vault_providers.dart';
import '../../core/session/session_actions.dart';

/// MOB-SET-01/02/03/05 — profile (read-only, matching the web app's "contact an
/// administrator to change your username/email"), change login password, notification
/// preferences, backup export/restore, server/security controls, Lock Now / Log Out.
///
/// MOB-SET-04 (master password rotation) is deliberately out of scope for mobile —
/// decided 2026-08-10, see sprint-plan.md's Sprint 2.3 entry: the account is shared
/// with the web app, which already has the full re-encryption flow, so a mobile user
/// who needs to rotate can do it there rather than mobile re-implementing the sprint's
/// highest-risk story (per-credential re-encryption with partial-failure handling).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  ProfileInfo? _profile;
  bool _biometricEnabled = false;
  bool _loading = true;
  bool _savingPrefs = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ref.read(settingsRepositoryProvider).getProfile();
      final hasKey = await ref.read(secureVaultStorageProvider).hasWrappedKey();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _biometricEnabled = hasKey;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load settings.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    String? dialogError;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change Login Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'This changes how you sign in — it does not affect your master '
                  'password or re-encrypt your vault.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: currentController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Current password'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm new password'),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 8),
                  Text(dialogError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (newController.text.length < 8) {
                  setDialogState(() => dialogError = 'New password must be at least 8 characters.');
                  return;
                }
                if (newController.text != confirmController.text) {
                  setDialogState(() => dialogError = 'New passwords do not match.');
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
    if (submitted != true) return;

    try {
      await ref.read(settingsRepositoryProvider).changePassword(
            currentPassword: currentController.text,
            newPassword: newController.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Login password changed.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiException ? e.message : 'Failed to change password.'),
        ));
      }
    }
  }

  Future<void> _toggleBiometric(bool enable) async {
    final session = ref.read(authSessionProvider);
    if (session == null) return;

    if (enable) {
      final gate = ref.read(biometricGateProvider);
      if (!await gate.isAvailable()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Biometric/PIN unlock is not available on this device.')));
        }
        return;
      }
      final confirmed = await gate.authenticate('Enable Quick Unlock');
      if (!confirmed) return;
      await ref.read(secureVaultStorageProvider).storeWrappedKey(encodePkcs8(session.privateKey));
      await ref.read(sessionPersistenceProvider).save(session);
    } else {
      await ref.read(secureVaultStorageProvider).clear();
    }
    if (mounted) setState(() => _biometricEnabled = enable);
  }

  Future<void> _updateNotificationPrefs({bool? expiryReminders, bool? shareNotifications}) async {
    final profile = _profile;
    if (profile == null) return;
    final updated = profile.notificationPreferences
        .copyWith(expiryReminders: expiryReminders, shareNotifications: shareNotifications);

    setState(() {
      _profile = profile.copyWith(notificationPreferences: updated);
      _savingPrefs = true;
    });
    try {
      await ref.read(settingsRepositoryProvider).updateNotificationPreferences(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save notification preferences.')));
      }
    } finally {
      if (mounted) setState(() => _savingPrefs = false);
    }
  }

  Future<void> _exportBackup() async {
    try {
      final bytes = await ref.read(backupRepositoryProvider).export();
      final filename =
          'xcred-backup-${DateTime.now().toIso8601String().split('T').first}.xcredbak';
      await ref.read(fileExchangeProvider).saveOrShare(filename, bytes, 'application/json');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to export backup.')));
      }
    }
  }

  Future<void> _restoreBackup() async {
    final picked = await ref.read(fileExchangeProvider).pickFile();
    if (picked == null) return;

    Map<String, dynamic> backup;
    try {
      backup = jsonDecode(utf8.decode(picked.bytes)) as Map<String, dynamic>;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('That file is not a valid backup.')));
      }
      return;
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text(
            'Credentials, folders, and tags from the file will be added to your vault. '
            "Items that already exist are skipped, not duplicated. This only works for "
            "a backup made from this same account — one from a different master "
            "password will fail to decrypt after restoring."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await ref.read(backupRepositoryProvider).restore(backup);
      ref.invalidate(vaultProvider);
      ref.invalidate(folderTreeProvider);
      ref.invalidate(tagListProvider);
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Restore Complete'),
            content: Text(
                'Credentials: ${result.credentialsRestored} restored, '
                '${result.credentialsSkipped} already existed.\n'
                'Folders: ${result.foldersRestored} restored.\n'
                'Tags: ${result.tagsRestored} restored.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to restore backup.')));
      }
    }
  }

  Future<void> _changeServer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Server?'),
        content: const Text("You'll be signed out and returned to server setup."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true), child: const Text('Continue')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(serverBaseUrlProvider.notifier).clear();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final serverUrl = ref.watch(serverBaseUrlProvider).value;
    final sessionTimeoutMinutes = ref.watch(orgSettingsProvider).sessionTimeoutMinutes;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : profile == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      onRefresh: _load,
                      // SingleChildScrollView + Column, not ListView(children:) — the
                      // latter is Sliver-backed and lazily builds only children near the
                      // viewport even with a fixed children list, so sections further
                      // down (Backup, Server, Account) wouldn't exist in the widget tree
                      // until scrolled into view (same bug class documented in
                      // credential_form_screen.dart).
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                          _sectionHeader(context, 'PROFILE'),
                          Card(
                            child: Column(
                              children: [
                                ListTile(title: const Text('Username'), subtitle: Text(profile.username)),
                                ListTile(title: const Text('Email'), subtitle: Text(profile.email)),
                                ListTile(title: const Text('Role'), subtitle: Text(profile.role)),
                                ListTile(
                                    title: const Text('Member Since'),
                                    subtitle: Text(_formatDate(profile.createdAt))),
                                if (profile.lastLoginAt != null)
                                  ListTile(
                                      title: const Text('Last Login'),
                                      subtitle: Text(_formatDate(profile.lastLoginAt!))),
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  child: Text(
                                    'To change your username or email, contact an administrator.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _changePassword,
                            child: const Text('Change Login Password'),
                          ),
                          const SizedBox(height: 24),
                          _sectionHeader(context, 'SECURITY'),
                          Card(
                            child: Column(
                              children: [
                                SwitchListTile(
                                  title: const Text('Biometric / Quick Unlock'),
                                  subtitle: const Text(
                                      'Use your fingerprint, face, or device PIN to unlock instead '
                                      'of your master password.'),
                                  value: _biometricEnabled,
                                  onChanged: _toggleBiometric,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  title: const Text('Auto-Lock'),
                                  subtitle: Text(
                                      '$sessionTimeoutMinutes minutes of inactivity — set by your '
                                      'organization administrator.'),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  title: const Text('Master Password'),
                                  subtitle: const Text(
                                      'To change your master password, use the XCred web app.'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _sectionHeader(context, 'NOTIFICATIONS'),
                          Card(
                            child: Column(
                              children: [
                                const SwitchListTile(
                                  title: Text('Security Alerts'),
                                  subtitle: Text('Cannot be disabled.'),
                                  value: true,
                                  onChanged: null,
                                ),
                                const Divider(height: 1),
                                SwitchListTile(
                                  title: const Text('Expiry Reminders'),
                                  value: profile.notificationPreferences.expiryReminders,
                                  onChanged: _savingPrefs
                                      ? null
                                      : (v) => _updateNotificationPrefs(expiryReminders: v),
                                ),
                                const Divider(height: 1),
                                SwitchListTile(
                                  title: const Text('Share Notifications'),
                                  value: profile.notificationPreferences.shareNotifications,
                                  onChanged: _savingPrefs
                                      ? null
                                      : (v) => _updateNotificationPrefs(shareNotifications: v),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _sectionHeader(context, 'BACKUP'),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Export an encrypted copy of your vault to keep somewhere '
                                    'safe, or restore from a previous export.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _exportBackup,
                                          icon: const Icon(Icons.download_outlined, size: 18),
                                          label: const Text('Export'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _restoreBackup,
                                          icon: const Icon(Icons.upload_outlined, size: 18),
                                          label: const Text('Restore'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _sectionHeader(context, 'SERVER'),
                          Card(
                            child: ListTile(
                              title: Text(serverUrl ?? ''),
                              subtitle: const Text('Connected server'),
                              trailing: TextButton(
                                onPressed: _changeServer,
                                child: const Text('Change'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _sectionHeader(context, 'ACCOUNT'),
                          Card(
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.lock_outline),
                                  title: const Text('Lock Now'),
                                  onTap: () => lockNow(ref),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading:
                                      Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
                                  title: Text('Log Out',
                                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                                  onTap: () => logOut(ref),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(letterSpacing: 0.5, color: Theme.of(context).hintColor),
      ),
    );
  }
}
