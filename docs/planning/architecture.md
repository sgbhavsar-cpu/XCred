# XCred Flutter Mobile — System Architecture

**Status:** Final (post-mockup confirmation, 2026-08-09)
**Supersedes:** `docs/design/flutter-mobile-design.md` (draft — see that file's header)
**Companion docs:** `docs/Requirements/Requirements-Flutter-Mobile.md` (confirmed requirements),
`docs/planning/high-level-design.md` (screen-by-screen design), `docs/planning/sprint-plan.md`

---

## 1. System Context

```
┌──────────────┐        HTTPS/JSON (unchanged API)        ┌──────────────────────┐
│ XCred Mobile │ ───────────────────────────────────────► │  XCred.Api (ASP.NET) │
│  (Flutter)   │ ◄─────────────────────────────────────── │  same backend as web │
└──────┬───────┘                                           └───────────┬──────────┘
       │ local, ciphertext-only                                        │
       ▼                                                                ▼
┌──────────────┐                                           ┌──────────────────────┐
│  drift (SQLite)│  offline cache — same shape as API list  │   SQL Server / IIS   │
│  local cache  │  responses, never decrypted at rest       │   (self-hosted)      │
└──────────────┘                                           └──────────────────────┘
       │
       ▼
┌──────────────────────┐
│ OS Secure Storage      │  Keystore (Android) / Keychain (iOS) — wrapped private
│ (biometric/PIN gated)  │  key material only, gated per-retrieval by local_auth
└──────────────────────┘
```

No backend changes are required for mobile to function (confirmed against every endpoint
in the verified API inventory). The one *optional* backend-adjacent item — Windows Hello
passkey unlock — is a **web app** feature (§0.2 of the requirements doc), architecturally
independent of mobile and not part of this system.

## 2. Component Architecture

```
┌───────────────────────────────────────────────────────────────────────┐
│                              Presentation                               │
│  Screens (go_router-routed) — consume Riverpod providers, never touch   │
│  ApiClient/LocalDb/CryptoService directly                               │
├───────────────────────────────────────────────────────────────────────┤
│                          Application State (Riverpod)                    │
│  SessionProvider · VaultProvider · OrgSettingsProvider · SyncProvider    │
│  — each exposes AsyncValue<T>, so screens render loading/error/data      │
│  uniformly without ad-hoc try/catch per screen                          │
├───────────────────────┬───────────────────────────────────────────────┤
│    CryptoService        │              Repositories                     │
│  deriveKey · encrypt/    │  CredentialRepository, FolderRepository,      │
│  decrypt · wrapKey/      │  TagRepository, CredentialGroupRepository,    │
│  unwrapKey · genKeyPair  │  ShareRepository, TeamRepository, AdminRepo   │
│  · genPassword           │  — own the "cache-first, refresh-from-        │
│                          │  network, merge" logic; the ONLY thing        │
│                          │  screens' providers call                     │
├───────────────────────┴───────────────────────────────────────────────┤
│         ApiClient (dio)          │         LocalDb (drift)               │
│  JWT attach + refresh-on-401     │  Tables mirror API list-endpoint       │
│  interceptor, typed endpoint     │  shapes (ciphertext + metadata only)   │
│  methods 1:1 with the verified   │  + a PendingMutation queue for         │
│  controller inventory            │  offline-created/edited writes         │
├───────────────────────────────────────────────────────────────────────┤
│                      Platform Abstraction Layer                          │
│  SecureVaultStorage · BiometricGate · FileExchange — one interface,      │
│  one Android impl, one iOS impl (Phase 4), swapped via provider override │
└───────────────────────────────────────────────────────────────────────┘
```

**Why Repositories, specifically**: every screen's data need decomposes into "read
(cache-first when offline-capable, else network), write (network, queue if offline),
decrypt (always local, always in-memory)." Putting that logic in one place per resource
means offline behavior (requirements §6.3) is implemented **once**, not re-derived per
screen — this directly addresses the biggest architectural risk of the offline-capable
decision (locked decision #2).

## 3. Data Flow — Representative Sequences

### 3.1 Login → Unlock-Ready State
1. `LoginScreen` submits username/login-password/master-password to `SessionProvider`.
2. `SessionProvider` calls `ApiClient.login()` → gets tokens + `keyDerivationSalt` +
   `encryptedPrivateKey`/`privateKeyIv`.
3. `CryptoService.deriveKey(masterPassword, salt)` (native-accelerated PBKDF2) →
   `CryptoService.decryptPrivateKey(derivedKey, encryptedPrivateKey, privateKeyIv)`.
4. Decrypted private key held in `SessionProvider`'s in-memory state (never in a drift
   table, never in plain `SharedPreferences`).
5. If the user has biometric/PIN unlock enabled (or is enabling it now, first-run):
   `SecureVaultStorage.storeWrappedKey()` wraps the private key bytes, backed by
   Keystore/Keychain.
6. `VaultProvider` triggers an initial full sync via the Repositories.

### 3.2 App Resume (Biometric Unlock Path)
1. App resumes with a valid refresh token (still persisted) but no in-memory private key
   (process was killed, or explicit lock).
2. `UnlockScreen` shown instead of `LoginScreen`.
3. `BiometricGate.authenticate()` → on success, `SecureVaultStorage.retrieveWrappedKey()`
   (itself gated — the OS re-prompts if the app tries to bypass the just-completed check)
   → unwrap → private key back in `SessionProvider` memory.
4. Falls back to `LoginScreen` (full master-password re-entry) on repeated biometric
   failure, explicit "enter master password" tap, or if no wrapped key exists (fresh
   install, logged out, or a master-password rotation invalidated it).

### 3.3 Offline Read
1. `CredentialsScreen` asks `VaultProvider` for the credential tree.
2. `CredentialRepository.getAll()`: if online, fetch + upsert into drift + return; if
   offline, return the drift cache directly with a "last synced" indicator.
3. Decryption happens in the provider layer, in memory, per credential, on demand for
   display — the cache itself never holds plaintext.

### 3.4 Offline Write
1. User edits a credential while offline. `CredentialRepository.update()` detects no
   connectivity, writes the change to the local drift cache **and** appends a
   `PendingMutation` row, returns success to the UI immediately (optimistic).
2. On reconnect, `SyncProvider` flushes `PendingMutation` rows in order. A flush that
   fails because the server's copy changed underneath (409-equivalent) surfaces a
   visible conflict banner — no silent overwrite, no silent drop (requirements §6.3).

## 4. Security Architecture (detail on requirements §6.1)

| Asset | At rest (server) | At rest (device) | In memory |
|---|---|---|---|
| Master password | never stored/transmitted | never stored | never stored, used once per derivation |
| Derived symmetric key (PBKDF2 output) | n/a | never stored | session-only, `SessionProvider` |
| RSA private key | AES-GCM-encrypted, server DB | **wrapped**, Keystore/Keychain, biometric/PIN-gated per retrieval | session-only after unlock |
| Per-credential AES keys | RSA-OAEP-wrapped, server DB (opaque to server) | same ciphertext, drift cache | decrypted on demand, not retained |
| Access/refresh tokens | hashed (refresh) / signed JWT (access) | `flutter_secure_storage`, no biometric gate needed (short-lived, server-revocable) | — |
| Credential plaintext | never | **never** | decrypted on demand only, not retained beyond the rendering need |

The one deliberate divergence from the web app's "nothing persisted" model is the wrapped
private key — justified by locked decision #1, bounded by requiring a fresh OS-level
biometric/PIN check on every retrieval (not just "encrypted at rest, freely readable by
the app process"), and fully invalidated on logout or master-password rotation
(FR-AUTH-05, FR-WEB-PASSKEY-04's mobile equivalent).

## 5. Platform Abstraction (detail on requirements §6.5)

```dart
abstract class SecureVaultStorage { /* see docs/design/flutter-mobile-design.md §6 */ }
abstract class BiometricGate { ... }
abstract class FileExchange { ... }
```
Android implementations (Phase 1-3) back onto Android Keystore, `BiometricPrompt`, and
Storage Access Framework. iOS implementations (Phase 4) back onto Keychain,
`LocalAuthentication`, and `UIActivityViewController` — provided via Riverpod overrides
selected at app bootstrap by platform, never via scattered `Platform.isAndroid` checks in
screen or provider code.

## 6. Navigation Structure (refined post-mockup)

The mockup surfaced that the web app's 6 top-level nav items (Dashboard, Credentials,
Shared, Folders, Teams, Tags) don't fit mobile bottom-nav conventions (~5 items max
before it feels cramped/scrolls). Resolved as:

- **Bottom nav (5 items)**: Dashboard, Credentials, Shared, Teams, Settings.
- **Folders and Tags are not separate bottom-nav destinations.** Both already work as
  *filters into the credential tree* on web (a folder/tag click deep-links into
  Credentials with a context filter) — on mobile they're reachable the same way: from
  a filter/sort control on the Credentials screen itself, not the bottom nav. This
  isn't a scope cut, it's matching how these two features actually behave already (they
  organize credentials, they aren't independent destinations with their own content).
- **Admin** (core subset) is reachable from Settings, not the bottom nav, matching its
  role-gated/occasional-use nature — consistent with web, where it's a top-of-sidebar
  item shown only to admins, not a primary nav destination.

## 7. Testing Strategy

- **Unit**: `CryptoService` — the highest-value unit tests in the whole app, since a
  subtle encoding mismatch here breaks cross-platform vault compatibility silently. Every
  primitive (PBKDF2, AES-GCM, RSA-OAEP wrap/unwrap) tested against **fixed vectors
  captured from the actual web app** (encrypt something on web, assert mobile decrypts it
  to the same plaintext; and the reverse) — not just "encrypt then decrypt with itself,"
  which would pass even with a mismatched-but-self-consistent implementation.
- **Widget**: Riverpod providers tested with mocked repositories; screens tested for
  correct state rendering (loading/error/data/offline-stale).
- **Integration**: `patrol` or `integration_test` driving real screens against a real
  Docker-composed backend (reusing this project's existing `docker-compose.yml`) —
  mirrors the web app's Playwright e2e approach conceptually.
- **Interop spike** (Phase 0, before any screen work): a throwaway script that logs into
  the real dev backend, creates a credential via the *web app*, then decrypts it from a
  bare Dart script using the chosen crypto libraries — and the reverse (create via the
  Dart script, decrypt via the web app in a browser console). This is the single most
  important test in the whole project to run early (§7 risk #1 of the design doc).
