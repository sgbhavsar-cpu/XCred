# XCred Mobile — MOB-SEC-01 Security Review

Date: 2026-08-10. Scope per `docs/planning/sprint-plan.md`'s Sprint 3.2: confirm no
sensitive material in logs/crash reports, and confirm `SecureVaultStorage` retrieval
genuinely re-prompts biometric authentication on every call rather than caching an
authenticated state for the process lifetime.

## 1. Logging / crash reports

**Finding: nothing to remediate — no logging or crash-reporting infrastructure exists
in the app at all.**

- Swept all of `lib/` for `print(`, `debugPrint(`, `log(`, `dart:developer`, and any
  logging-package usage: zero matches.
- Swept `pubspec.yaml` for crash-reporting/analytics SDKs (`firebase_crashlytics`,
  `sentry`/`sentry_flutter`, `firebase_analytics`, etc.): none present.
- The only `.catchError` usages in the codebase (`credential_detail_screen.dart`, three
  call sites — filename-guess fallback, MIME-type fallback, an empty-string fallback)
  discard the error and substitute a UI display value; none of them touch passwords,
  the master password, decrypted credential fields, tokens, or keys, and none log
  anything.

This satisfies the requirement (`docs/Requirements/Requirements-Flutter-Mobile.md`
§6.1: "This material must never be transmitted, logged, or included in crash reports")
by absence rather than by an explicit redaction layer. **Decision, recorded here
explicitly so it isn't silently reversed later:** if crash reporting or analytics is
added in a future sprint (e.g. for release monitoring), it needs an explicit
redaction/scrubbing policy *before* it ships — there is currently no scrubbing
infrastructure to lean on, because there was never anything to scrub.

## 2. Biometric re-prompt verification

**Finding: confirmed, both by code review and a real on-device test — retrieval
requires a fresh OS-level check every single call, not a cached "already unlocked this
process" state.**

### Code-level review

- `SecureVaultStorage.retrieveWrappedKey()` (`lib/core/platform/secure_vault_storage.dart`)
  is a thin wrapper over `flutter_secure_storage` — it does not itself gate anything;
  its own doc comment is explicit that callers are responsible for gating it behind
  `BiometricGate.authenticate()`.
- `BiometricGate.authenticate()` (`lib/core/platform/biometric_gate.dart`) calls
  `local_auth`'s `LocalAuthentication.authenticate()` directly with no caching layer —
  every call triggers a fresh native prompt; the plugin itself has no "already
  authenticated this session" concept.
- The only call site of `retrieveWrappedKey()` outside its own class
  (`unlock_screen.dart`'s `_unlock()`) is always immediately preceded by a fresh
  `authenticate()` call in the same method — there is no code path that reaches
  `retrieveWrappedKey()` without going through `authenticate()` first.
- `UnlockScreen` is reachable more than once per process lifetime: `IdleLockGate`
  (auto-lock after the configured idle timeout) and the explicit "Lock Now" action both
  clear only the in-memory `authSessionProvider`, leaving the wrapped key and persisted
  tokens intact — which is exactly what routes the app router back to `/unlock`,
  re-mounting `UnlockScreen`, which re-triggers `_unlock()` in `initState`.

### On-device verification (Pixel_10_Pro emulator, Sprint 3.2)

Static review proves the *code* always calls `authenticate()` before
`retrieveWrappedKey()`; it doesn't prove the *OS* actually re-prompts rather than
silently succeeding within some grace window. Tested directly:

1. Set a device PIN via `adb shell locksettings set-pin` (this AVD has no fingerprint
   enrolled, and `BiometricGate.authenticate()` uses `biometricOnly: false`, so PIN is
   a valid device-credential fallback — same `local_auth.authenticate()` call path a
   real fingerprint/face check would take).
2. Logged into the app, chose "Enable" on the "Enable Quick Unlock?" prompt (previous
   sprints' tests always chose "Not Now", so this was the first time this flow was
   exercised for real) — confirmed via `adb shell dumpsys window` that a genuine
   system `BiometricPrompt` window appeared (owner package `com.android.systemui`),
   and via `uiautomator dump` that its title/description matched the app's own
   `authenticate('Enable Quick Unlock')` call. Entered the PIN, confirmed the vault
   unlocked (dashboard loaded with real data — 105 credentials, 5 teams).
3. Tapped **Lock Now**. Confirmed via `dumpsys window` that the app routed to
   `/unlock` and a **new** `BiometricPrompt` system window appeared — critically, a
   **different window ID** than step 2's prompt (`2d3186e` vs. `685de2e`), which is
   concrete evidence this is a freshly-issued OS authentication challenge, not the
   same session being silently reused.
4. Entered the PIN again on this second prompt — the vault unlocked successfully a
   second time, confirming the full cycle (enable → lock → re-prompt → unlock) works
   end-to-end, not just that a prompt window happens to appear.

Cleaned up afterward: cleared the test PIN (`adb shell locksettings clear`) to restore
the emulator to its prior no-lock-configured state, since other integration tests
(`session_lifecycle_test.dart` et al.) assume that baseline and use a
`FakeBiometricGate` override rather than relying on real device credentials.

**Conclusion:** the FR-SESS-01 security property this story exists to verify — that
retrieval requires a fresh biometric/PIN check on every call, not just "encrypted at
rest, freely readable once the process has been unlocked once" — holds up under an
actual device test, not just a plausible-looking code path.

## Not covered by this review

- No penetration test / static-analysis security tool run — this was a targeted review
  of the two specific concerns the sprint story names, not a general audit.
- `AndroidManifest.xml`'s `usesCleartextTraffic="true"` was noted (needed for the local
  HTTP dev backend this project tests against) but deliberately left as-is — see
  `docs/release/release-checklist.md`'s item 6; whether it needs tightening depends on
  the production server's own TLS setup, which is a deployment decision outside this
  app's code.
