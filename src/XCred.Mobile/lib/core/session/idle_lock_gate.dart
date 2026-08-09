import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';

/// MOB-SESS-03 — auto-lock after `orgSettings.sessionTimeoutMinutes` of inactivity
/// (never a hardcoded value — see [org_settings.dart] for why). Resets on any pointer
/// activity anywhere in the app; only runs while a session exists (nothing to lock
/// before login/unlock). Firing clears the in-memory session only, matching "Lock Now"
/// exactly — the wrapped key and persisted tokens are untouched, so the next screen the
/// router shows is `/unlock`, not `/login`.
class IdleLockGate extends ConsumerStatefulWidget {
  const IdleLockGate({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<IdleLockGate> createState() => _IdleLockGateState();
}

class _IdleLockGateState extends ConsumerState<IdleLockGate> {
  Timer? _timer;

  void _resetTimer() {
    _timer?.cancel();
    final session = ref.read(authSessionProvider);
    if (session == null) return;
    final minutes = ref.read(orgSettingsProvider).sessionTimeoutMinutes;
    _timer = Timer(Duration(minutes: minutes), () {
      ref.read(authSessionProvider.notifier).clear();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilding the timer whenever the session appears/disappears (login, unlock,
    // lock, logout) — not just on pointer activity — keeps it correctly armed/disarmed
    // without a stray timer surviving past logout.
    ref.listen(authSessionProvider, (_, _) => _resetTimer());
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
