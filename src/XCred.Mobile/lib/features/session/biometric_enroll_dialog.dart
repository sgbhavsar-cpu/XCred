import 'package:flutter/material.dart';

/// MOB-SESS-01 — shown once per device after a full login, never nagged again
/// regardless of the answer (the "asked" flag is set either way by the caller).
/// Returns true if the user wants to enable it.
Future<bool> showBiometricEnrollDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Enable Quick Unlock?'),
      content: const Text(
        'Use your fingerprint, face, or device PIN to unlock XCred next time, instead '
        'of retyping your master password. Your master password is never stored — '
        'only your already-unlocked vault key, protected behind this device check.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not Now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Enable'),
        ),
      ],
    ),
  );
  return result ?? false;
}
