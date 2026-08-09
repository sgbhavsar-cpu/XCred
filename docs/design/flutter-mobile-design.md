# XCred Flutter Mobile — Technical Design (Draft, SUPERSEDED)

**Status:** SUPERSEDED 2026-08-09 — folded forward into
`docs/planning/architecture.md` (system/component architecture, crypto, security,
testing) and `docs/planning/high-level-design.md` (screens, data model, API mapping)
after the interactive mockup confirmed the approach. Kept here for history; don't design
against this file going forward.
**Companion doc:** `docs/Requirements/Requirements-Flutter-Mobile.md` (confirmed)

---

## 1. Tech Stack

| Concern | Choice | Why |
|---|---|---|
| Language/framework | Flutter (Dart), single codebase for Android + iOS | Per confirmed requirements — one codebase, platform-specific bits isolated (§6). |
| State management | **Riverpod** (code-gen, `riverpod_generator`) | Strong async support (needed throughout — crypto ops, API calls, DB queries are all async), compile-safe DI, good testability without a widget tree. |
| Navigation | **go_router** | Standard modern Flutter routing; declarative routes map cleanly onto the web app's URL structure (`/credentials/:id`, `/credentials/new?groupId=`, etc.), supports deep links for later (share notifications, autofill deferred but this keeps the door open). |
| HTTP client | **dio** | Interceptor support for JWT attach/refresh-on-401, matches the web app's axios-interceptor pattern conceptually. |
| Local database (offline cache) | **drift** (SQLite) | Relational shape matches the API's data model closely (credentials/folders/tags/groups/shares as related tables) better than a key-value store; mature, typed queries, good migration story as the schema evolves. |
| Crypto — PBKDF2/AES-GCM | **`cryptography`** + **`cryptography_flutter`** | Native-accelerated PBKDF2 (600k iterations needs it — see §4.4 performance risk), AES-GCM built in, actively maintained, Google-backed. |
| Crypto — RSA-OAEP-2048 | **PointyCastle** (spike required, see §7 risks) | `cryptography` package's RSA/asymmetric support doesn't cover OAEP-2048 as cleanly as PointyCastle's explicit RSA engine + OAEP padding. Needs an early interop spike against real web-generated ciphertext before committing. |
| Secure storage | **`flutter_secure_storage`** (Keystore/Keychain-backed) + **`local_auth`** (biometric prompt) | Standard, well-supported combination per research; `local_auth` returns only a pass/fail, never raw biometric data. |
| URL launching | **`url_launcher`** | Replaces web's `window.open`/`location.href` split for smart links (§5.10 of requirements). |

## 2. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                            Presentation                             │
│   Screens (per §3) — Riverpod-consumed, go_router-routed            │
├─────────────────────────────────────────────────────────────────────┤
│                          Application / State                        │
│   Riverpod providers: auth session, vault (credentials/folders/     │
│   tags/groups/shares), org settings, sync status                    │
├───────────────────────────┬───────────────────────────────────────┤
│      Crypto Service        │           Data Layer                  │
│  - deriveKey (PBKDF2)       │  - ApiClient (dio, JWT interceptor)   │
│  - encrypt/decrypt (AES-GCM)│  - LocalDb (drift) — ciphertext cache │
│  - RSA-OAEP wrap/unwrap     │  - Repositories (merge local+remote,  │
│  - key pair gen             │    the only thing screens talk to)    │
├───────────────────────────┴───────────────────────────────────────┤
│                    Platform Abstraction Layer                       │
│   SecureStorage (Keystore/Keychain), Biometric (local_auth),        │
│   FileSaveShare (native share sheet) — thin interfaces, one impl    │
│   per platform where they differ                                    │
└─────────────────────────────────────────────────────────────────────┘
```

**Key architectural rule**: screens never call `ApiClient` or `LocalDb` directly — always
through a **Repository**, which owns the "read from cache, refresh from network, merge"
logic and is the single place offline/online branching happens. This keeps the offline
requirement (§6.3 of requirements) from leaking into every screen.

## 3. Screen Inventory (maps 1:1 to requirements §5)

| Screen | Route | Requirement refs |
|---|---|---|
| Server Setup | `/setup` (first-run only) | FR-SRV-01/02 |
| Login | `/login` | FR-AUTH-02 |
| Register | `/register` | FR-AUTH-01 |
| Unlock (biometric/PIN) | `/unlock` (shown instead of `/login` when a device unlock is configured and a session exists) | FR-SESS-01/02 |
| Dashboard | `/dashboard` | FR-DASH-01..04 |
| Credentials (tree list) | `/credentials` | FR-CRED-01 |
| Credential Detail | `/credentials/:id` | FR-CRED-03, FR-LINK-01/02, FR-ATT-02 |
| Credential Form (create/edit) | `/credentials/new`, `/credentials/:id/edit` | FR-CRED-02/04, FR-ATT-01 |
| Password Generator | modal/bottom-sheet, not a route | FR-GEN-01 |
| Credential Group Detail | `/groups-cred/:id` | FR-CGRP-01..03 |
| Folders | `/folders` | FR-FOLD-01/02 |
| Tags | `/tags` | FR-TAG-01 |
| Shares | `/shares` | FR-SHARE-01..03 |
| Teams | `/teams` | FR-TEAM-01 |
| Settings (tabbed) | `/settings` | FR-SET-01..06 |
| Admin (tabbed, core subset) | `/admin` | FR-ADMIN-01..03 |

## 4. Crypto Model — Ported 1:1

Every parameter matches the web app exactly (verified in the research doc, §6.2 of
requirements is the hard interop requirement):

1. **Key derivation**: PBKDF2-HMAC-SHA256, 600,000 iterations, 256-bit output, salt as
   received from the server (base64-decoded), via `cryptography_flutter`'s native path.
2. **RSA key pair**: 2048-bit modulus, OAEP padding, SHA-256 hash, generated on-device at
   registration exactly like web (never server-generated).
3. **Private key at rest (server-side, same as web)**: AES-GCM-encrypted with the
   PBKDF2-derived key, stored as `encryptedPrivateKey`/`privateKeyIv` — mobile decrypts
   this the same way web does on login.
4. **Private key at rest (device-local, mobile-only — §6.1 of requirements)**: after a
   successful login, the *decrypted* private key bytes are wrapped via
   `flutter_secure_storage` (itself backed by Keystore/Keychain) — retrieval requires a
   fresh biometric/PIN check (`local_auth`) each time, not just app-process-level access.
   This is the one place mobile's crypto model does something web's doesn't — everything
   else is identical.
5. **Per-credential envelope encryption**: identical model — random AES-256 key per
   credential, RSA-OAEP-wrapped with the owner's public key; sharing re-wraps the same
   underlying AES key for a recipient's public key.
6. **IVs**: fresh random 96-bit IV per AES-GCM operation, never reused — same as web.

### 4.4 Performance Risk
600k PBKDF2 iterations is deliberately slow (by KDF design) and needs to run natively,
not in pure Dart, on lower-end Android hardware to stay within an acceptable unlock-time
budget. This must be measured on a real low/mid-range test device early (see risks, §7)
— if it's too slow even natively, the UX around "unlock" (e.g. showing a spinner/progress
state, or only re-running PBKDF2 for the very first login and relying on biometric-gated
storage for every return visit thereafter, which is already the plan per §6.1) needs to
absorb that, not silently degrade the experience.

## 5. Offline & Sync Design

- **What's cached locally (drift tables)**: credentials (ciphertext + IVs + wrapped key +
  metadata: type, folder/tag/group IDs, expiry, timestamps), folders, tags, credential
  groups, teams, shares — i.e. everything the corresponding `GET` list endpoints return,
  stored close to as-is. **Never** plaintext, never the decrypted-in-memory field values.
- **Sync trigger**: on app foreground/resume (if online), pull-to-refresh, and after any
  successful mutation (create/update/delete) — same "fetch fresh" pattern the web app
  already uses via its `refetch()` calls, not a background/real-time sync service.
- **Offline mutations**: queued locally (a small `PendingMutation` table: type + payload +
  timestamp), flushed in order on reconnect. Per requirements §6.3, conflict handling for
  this pass is "last write wins with a visible warning" — if a flush fails because the
  server's copy changed since the mutation was queued, surface it to the user rather than
  silently overwriting or silently dropping the change.
- **Search/filter while offline**: decrypt-on-demand into memory for the currently visible
  list (mirrors how the web app already works within a session — nothing new here, just
  running against the local cache instead of a live fetch when offline).

## 6. Platform Abstraction Layer

Three interfaces isolate everything Android/iOS actually differ on, so the iOS phase
(requirements decision #5) is "implement three classes," not "re-architect":

```dart
abstract class SecureVaultStorage {
  Future<void> storeWrappedKey(Uint8List wrapped);
  Future<Uint8List?> retrieveWrappedKey(); // triggers biometric/PIN prompt internally
  Future<void> clear();
}

abstract class BiometricGate {
  Future<bool> isAvailable();
  Future<bool> authenticate(String reason);
}

abstract class FileExchange {
  Future<void> saveOrShare(String filename, Uint8List bytes, String mimeType); // downloads
  Future<PickedFile?> pickFile(); // attachment upload
}
```

Android implementations back onto Keystore/BiometricPrompt/Storage Access Framework; iOS
onto Keychain/LocalAuthentication/UIActivityViewController — swapped via Riverpod
provider overrides per platform, never via `Platform.isAndroid` checks scattered through
screen code.

## 7. Key Risks / Open Technical Questions (to resolve before/during Sprint 1)

1. **RSA-OAEP-2048 interop spike** — before building any real screens, prove a Dart-side
   RSA-OAEP implementation (PointyCastle, likely) can decrypt a real
   `encryptedCredentialKey` produced by the web app's WebCrypto `RSA-OAEP` call, and vice
   versa. This is the single highest-risk unknown — if padding/encoding mismatches exist,
   it's much cheaper to find out in a throwaway spike than mid-feature-build.
2. **PBKDF2 performance on real low/mid-range Android hardware** — measure before
   finalizing the unlock UX (§4.4).
3. **`flutter_secure_storage` biometric-gating specifics per platform** — confirm the
   exact API/config needed so retrieval *requires* a fresh biometric check each call
   (not just "the OS encrypts it at rest, but any app-process read succeeds without a
   prompt") — this distinction matters for the FR-SESS-01 security property, not just
   convenience.
4. **WebAuthn PRF web feature (§0.2 of requirements)** shares no code with mobile but
   shares the exact same "wrap the key, gate unwrapping behind a device check" pattern —
   worth having the same engineer/reviewer look at both for consistency, even though
   they're separately scheduled.

---

*Next: interactive mockup of the core screens (login → unlock → credentials tree →
credential detail → create flow), then revise this doc based on what the mockup surfaces,
per the design process.*
