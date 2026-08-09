# XCred Flutter Mobile App — Requirements

**Status:** Confirmed 2026-08-09 — proceeding to design + mockup
**Date:** 2026-08-09
**Scope:** A Flutter mobile client (Android first, iOS second phase) for the existing
XCred zero-knowledge credential vault, reusing the current ASP.NET Core API unchanged
except where explicitly noted.

---

## 0. Post-Confirmation Additions

Two items were added after initial confirmation, in the same conversation:

### 0.1 Web-app bug fixes — done, not just noted
The three web-app gaps identified in §5.13 (hardcoded session timeout/attachment
size/clipboard-clear instead of reading org settings; Teams add-member picker calling the
admin-gated `/admin/users` instead of `/users`) have been **fixed in the web app**
already, not left as "mobile should do it correctly" — per direct instruction, these are
real bugs worth fixing everywhere, not just avoiding on the new client. Verified via the
existing Playwright e2e suite plus a fresh `npm run build`. Mobile still independently
implements these correctly from scratch (§5.13 stands as written for mobile's own
implementation), but there's no longer a "copy vs. fix" decision pending for web — it's
fixed.

### 0.2 Windows Hello / WebAuthn PRF passkey unlock (web app, new)
Researched and confirmed technically feasible: as of a **February 2026 Windows update
(KB5077181)**, Windows Hello supports the **WebAuthn PRF extension**, which lets a
passkey derive a stable, secret key (not just prove device presence) — usable to encrypt
a locally-wrapped copy of the vault's decrypted private key, unwrapped again by a
Windows Hello check on return visits. This is the same conceptual pattern as mobile's
biometric/PIN unlock (§6.1), implemented via WebAuthn instead of native OS secure storage.
Real precedent: Dashlane uses PRF to replace master-password re-entry; Bitwarden has
adopted it too.

**Added as an in-scope web feature, optional and gracefully degrading:**
- **FR-WEB-PASSKEY-01**: "Unlock with Windows Hello" toggle in Settings (parallel to
  mobile's FR-SESS-01), available only when the browser reports PRF support
  (feature-detected at runtime — `navigator.credentials` + a capability probe — not a
  hardcoded browser/OS version check, since support will keep expanding). On unsupported
  browsers/OS the toggle simply doesn't appear; master-password login remains the only
  path, unchanged from today.
- **FR-WEB-PASSKEY-02**: Enabling it registers a platform authenticator credential
  (`navigator.credentials.create()` with the `prf` extension requested), then uses a PRF
  assertion output as an AES key to encrypt the already-decrypted private key, stored in
  IndexedDB (not localStorage, to keep it out of any plain string-based tooling/exports).
- **FR-WEB-PASSKEY-03**: Return-visit unlock does a PRF assertion (prompts Windows Hello)
  → derives the same secret → decrypts the stored private key → same in-memory session
  state as a normal login, without the master password ever being retyped.
- **FR-WEB-PASSKEY-04**: Master-password rotation (existing `/auth/change-master-key`
  flow) invalidates the stored wrapped key — user must either retype the master password
  once or re-enable Windows Hello unlock afterward. A stale wrapped key must never
  decrypt post-rotation data (same invariant as mobile's FR-AUTH-05 note).
- **FR-WEB-PASSKEY-05**: "Forget this device" / disable action in Settings clears the
  IndexedDB entry and the registered credential association client-side.

This is scoped as a **web app enhancement**, tracked here because it shares its whole
design rationale with mobile's unlock model, but is separate implementation work — it
does not block or get blocked by the Flutter mobile effort. Sequencing (build now vs.
after mobile) is an open scheduling question, not a design question — flag when ready to
prioritize it.

---

## 1. Vision / Problem Statement

XCred today is a web app only. Users who want to check or add a credential away from a
browser — on the go, offline, or simply because a phone is faster to reach for — have no
way to do so. This project builds a native mobile client with full functional parity to
the web app's credential-management features, adapted to mobile conventions where the
web app's own patterns don't translate (e.g. biometric unlock instead of retyping a
master password every session), while deliberately not chasing mobile-native features
that go beyond parity (autofill, push notifications) in this pass.

The mobile app talks to the **same backend API**, honors the **same zero-knowledge
encryption model** (the server must never be able to derive plaintext on this client any
more than it can on the web client), and must be able to open the **same vault** a user
already has — same master password, same derived key, same ciphertext.

## 2. Goals

- Full feature parity with the web app's credential-management surface: all 19 credential
  types (including the new `Rdp` type), Credential Groups, Folders, Tags, Sharing, Teams,
  Attachments, Password Generator, Dashboard, Settings, core Admin functions.
- Same crypto model, verified interoperable: a credential created on web must decrypt
  correctly on mobile and vice versa.
- Mobile-appropriate session model: biometric/PIN unlock after one initial full login,
  instead of the web's retype-every-session behavior.
- Usable offline: view and search a previously-synced vault without connectivity.
- Works against any self-hosted XCred deployment via a configurable server URL — including
  the local Docker Compose stack for development/testing.

## 3. Non-Goals (this pass)

- **Autofill** (Android Autofill Framework / iOS Credential Provider extension) — real
  value, but a substantial platform-specific integration in its own right. Deferred to a
  future phase once the core app is shipped and stable.
- **Push notifications** (FCM/APNs) — the backend has no push infrastructure today (email
  only). Building device-token registration + a push service is backend scope beyond
  "port the web app." Mobile relies on the same email notifications the web app already
  sends.
- **Full Admin parity** — Org Settings (SMTP config, session timeout, lockout policy,
  clipboard-clear seconds, expiry-warning days) stays web-only. Users/Pending
  Approval/Audit Log are in scope (see §4.13).
- **iOS at launch** — designed architecturally for both platforms from day one (thin
  platform-abstraction layers, not Android-specific assumptions baked into shared code),
  but the sprint plan ships Android first; iOS is an explicit later phase.
- Any backend API changes beyond what's strictly required for mobile to function
  correctly (see §5.4 for the one confirmed necessary addition: reading real org settings
  instead of copying the web app's hardcoded-value bugs).

## 4. Locked Decisions (from clarifying questions)

| # | Decision | Why |
|---|---|---|
| 1 | **Biometric/PIN unlock** after one full master-password login, instead of requiring the master password every app open | Retyping a 12+ character master password every session is a real usability tax on mobile in a way it isn't on a desktop browser session. Matches the established UX of Bitwarden/1Password. Requires the wrapped decryption material to live in OS-level secure storage (Keystore/Keychain), never derivable without on-device biometric/PIN verification — see §6.1 for the security design. |
| 2 | **Offline-capable**: cache encrypted vault data locally, decrypt in memory after unlock, sync on reconnect | Pairs naturally with biometric unlock — a user shouldn't be locked out of a password they need right when they have no signal. Matches Bitwarden's model. Real added scope (local DB, sync, conflict handling) accepted deliberately, not incidentally. |
| 3 | **Autofill deferred** to a future phase | No web equivalent to have parity with; a large platform-specific integration on its own. Keeps this pass focused on actual parity instead of open-ended mobile-native scope creep. |
| 4 | **Core Admin only** on mobile (Users, Pending Approval, Audit Log); Org Settings stays web-only | Approving a user or checking the audit log from a phone is plausible; SMTP host/port/password forms are not good mobile UX and don't need to be available away from a desk. |
| 5 | **Android first, iOS second phase** (architected for both from the start) | Avoids the Apple Developer Program / Mac build machine / TestFlight overhead blocking the start of work; Flutter's cross-platform code sharing means this doesn't compromise the eventual iOS build if platform-specific bits (Keystore vs Keychain, etc.) are isolated correctly from day one. |
| 6 | **Configurable server URL**, set on first run and changeable in Settings | XCred is self-hosted with no fixed SaaS backend — one app build needs to work against any organization's deployment (or a local Docker stack for testing), not just one baked-in URL. |
| 7 | **Email notifications only** — no push infrastructure this pass | The backend has zero push infrastructure today; building FCM/APNs device-token registration and a push-sending service is backend scope beyond "port the web app to mobile." |

## 5. Functional Requirements

Grouped by area, each derived directly from the verified web-app inventory
(`docs/market-research/flutter-mobile-vault-research.md` §1 and the underlying codebase
read). "FR" numbers are stable IDs for later sprint-story references.

### 5.1 Onboarding & Server Configuration
- **FR-SRV-01**: First-run screen to enter the organization's XCred server base URL
  (validated reachable before proceeding), stored locally, editable later from Settings.
- **FR-SRV-02**: If no account exists on that server yet, registration follows the same
  first-user-is-auto-admin bootstrap behavior as web (no special mobile-side logic needed
  — server already handles this).

### 5.2 Authentication
- **FR-AUTH-01**: Registration screen — username, email, login password (+confirm),
  master password (+confirm), mandatory "I understand there is no recovery" acknowledgment,
  live password-strength meter for both passwords (min 8 chars login / min 12 chars
  master, matching the web app's Zod validation). Key pair (RSA-OAEP-2048) and KDF salt
  generated entirely on-device before the register API call, exactly mirroring web's
  client-side-first flow — the server never sees anything but the final public
  artifacts.
- **FR-AUTH-02**: Login screen — username, login password, master password. On success:
  fetch `keyDerivationSalt`/`encryptedPrivateKey`/`privateKeyIv` from the login response,
  derive the symmetric key (PBKDF2-SHA256/600k) on-device, decrypt the private key
  on-device. Master password is never transmitted.
- **FR-AUTH-03**: Pending-approval / locked-account / inactive-account states surface the
  same server error codes as web with equivalent messaging.
- **FR-AUTH-04**: Change login password (Settings) — current/new/confirm, same
  `/auth/change-password` call.
- **FR-AUTH-05**: Change master password (Settings, high-risk flow) — full client-side
  re-encryption of every credential's wrapped key with a newly generated key pair,
  submitted in one `/auth/change-master-key` call, with the same per-credential
  fallback-to-old-key safety net the web app has if an individual re-wrap fails (§8.6 of
  the research doc). Must also re-wrap the biometric-unlock secure-storage entry (§6.1) —
  a web-app gap that doesn't exist for mobile since web has no persisted unlock material
  to invalidate.

### 5.3 Vault Unlock & Session (mobile-specific — no direct web equivalent)
- **FR-SESS-01**: After first full login, offer to enable biometric/PIN unlock. If
  accepted, store the wrapped decryption material per §6.1.
- **FR-SESS-02**: On subsequent app opens/resumes (while a device-level unlock is
  enabled), prompt biometric (or PIN fallback after repeated biometric failure) instead
  of the master password form.
- **FR-SESS-03**: Explicit "Lock Now" action in Settings; auto-lock after a configurable
  idle period (mirrors the web app's session-timeout concept, but should read the real
  `orgSettings.sessionTimeoutMinutes` value from `/dashboard` rather than copying web's
  hardcoded-15-minutes bug — see §5.13 gap list).
- **FR-SESS-04**: "Log out" (distinct from "Lock") clears the secure-storage unlock
  material entirely and returns to the login screen, requiring master password on next
  access.

### 5.4 Dashboard
- **FR-DASH-01**: Stat cards — total credentials, shared-with-me count, teams count.
- **FR-DASH-02**: Expired / expiring-soon credential alert sections (decrypted
  client-side for display name), "all good" empty state.
- **FR-DASH-03**: Recent activity feed (last 10 audit events), human-readable action
  labels.
- **FR-DASH-04**: Fetch and cache `orgSettings` from this endpoint for use throughout the
  app (session timeout, max attachment size — see §5.13 gap list).

### 5.5 Credentials — Core CRUD
- **FR-CRED-01**: List view mirroring web's expandable-tree Credentials page: Credential
  Groups as collapsible rows with member counts, "Ungrouped" section below, search
  (name/username/tag match), type filter, folder/tag deep-link context filters.
- **FR-CRED-02**: Create/Edit form — type picker grid (create only; type immutable after
  creation) covering all 19 types from the verified field table (research doc §"Credential
  Types & Fields"), dynamic field rendering per type (`text`/`password`/`textarea`/
  `select`/`url`/`list`), Notes, dynamic Custom Fields editor, Tags multi-select, Folder
  picker, Credential Group picker, Expiry Date.
- **FR-CRED-03**: Detail/view screen — decrypt and display every populated field
  (skip empty/empty-list fields), password mask toggle, copy-to-clipboard with
  clipboard-auto-clear (configurable seconds, matching web's clipboard-clear org
  setting) and audit-log ping (`POST /credentials/:id/copy`), smart-link "open" actions
  where applicable (§5.10), metadata (folder, credential-group link, tags, expiry with
  overdue styling, timestamps), delete with confirmation.
- **FR-CRED-04**: All 19 credential types with their exact field sets, ported field-for-field
  from the verified table — including the new `Rdp` type (host/port/domain/username/password,
  `rdp://` smart link).

### 5.6 Credential Groups
- **FR-CGRP-01**: List/expand/collapse groups inline (part of FR-CRED-01's tree).
- **FR-CGRP-02**: Create group (name + emoji icon picker from the same 8-icon set),
  rename, delete (unlinks members, doesn't delete them).
- **FR-CGRP-03**: Group detail screen — member list, "Add New Credential" (pre-scoped via
  the same query-param-equivalent navigation pattern), "Add Existing Credential" (reassign
  from elsewhere), remove-from-group.

### 5.7 Folders
- **FR-FOLD-01**: Nested folder tree (recursive, indented), inline create (with parent
  picker), rename, delete (credentials move to "No Folder", not deleted).
- **FR-FOLD-02**: Each folder's member credentials rendered via the same shared
  credential-row component used elsewhere (parity with web's `CredentialRow` reuse
  pattern).

### 5.8 Tags
- **FR-TAG-01**: Flat color-coded tag list (same 10-color preset), inline create/rename/
  recolor/delete, expand to show tagged credentials.

### 5.9 Sharing
- **FR-SHARE-01**: "Shared With Me" list — read-only, decrypted display, status
  (expired/until-date/until-changed/no-expiry).
- **FR-SHARE-02**: "Shared By Me" — active vs. revoked/expired sections, revoke action
  with confirmation.
- **FR-SHARE-03**: Share-from-detail-screen flow — pick a user or team, optional
  expiry/until-changed, client-side re-wrap of the credential's AES key with the
  recipient's RSA public key (fetched via `GET /users`, not the admin-gated `/admin/users`
  — deliberately avoiding the bug noted in the web app's Teams add-member picker).

### 5.10 Smart Links
- **FR-LINK-01**: Port `computeFieldLink`/`networkDeviceLink` logic exactly (same
  dispatch table: `url` type → validated http(s), `linkType: email/tel/ssh/rdp` →
  `mailto:`/`tel:`/`ssh://`/`rdp://`, `network-device-ip` list items → per-protocol
  dispatch). Use `url_launcher` for the actual OS hand-off (replacing web's
  `window.open`/`location.href` split — no "new tab" concept on mobile, all schemes go
  through the same OS intent/URL-scheme mechanism).
- **FR-LINK-02**: Same "otherwise nothing will happen" expectation-setting copy for
  `ssh`/`rdp`/network-device links, adapted to mention the relevant mobile apps (e.g.
  Termius, Microsoft Remote Desktop) a user would need installed.

### 5.11 Teams (Groups)
- **FR-TEAM-01**: List teams, expand to show members + roles, create team, add/remove
  member (using `GET /users` for the picker — see FR-SHARE-03 note), delete (team-admin
  or global-admin, server-enforced either way).

### 5.12 Attachments
- **FR-ATT-01**: Upload — pick file, encrypt filename/mime/data independently (fresh IV
  each) under the parent credential's AES key, enforce the **real** server-configured
  `maxAttachmentSizeMb` (from `orgSettings`, not a hardcoded 10 MB — see §5.13).
- **FR-ATT-02**: List — decrypt filenames/mime once on load, download (native file-save/
  share-sheet flow, not a blob-URL click), delete.

### 5.13 Known Web-App Gaps — Decide Whether Mobile Fixes or Copies Them

These were found during codebase research (`flutter-mobile-vault-research.md` §8) and
need an explicit call, not a silent copy-or-fix:

| Gap | Recommendation |
|---|---|
| Web hardcodes 15-min session timeout and 10 MB attachment cap instead of reading `orgSettings` | **Fix on mobile** — read the real values from `/dashboard`. Low cost, more correct, doesn't block parity (it's strictly more correct behavior, not a different feature). |
| Web's Teams "add member" picker calls admin-gated `/admin/users`, silently empty for non-global-admin team admins | **Fix on mobile** — use `GET /users` as designed (FR-SHARE-03/FR-TEAM-01 above already specify this). |
| Master-password rotation isn't transactional server-side | **Copy the web app's mitigation** (per-credential fallback-to-old-key on individual re-wrap failure) — this is a real safety net worth keeping, not a bug to silently drop. |

### 5.14 Settings (mobile-relevant subset)
- **FR-SET-01**: Profile (read-only, same fields as web).
- **FR-SET-02**: Change login password (FR-AUTH-04).
- **FR-SET-03**: Notification preferences (3 toggles, same as web — note these gate
  *email* sends server-side, not any mobile push, per the non-goals in §3).
- **FR-SET-04**: Backup export (`GET /backup`, save via native share/file flow) and
  restore (file picker → `POST /backup/restore`), same result-summary display as web.
- **FR-SET-05**: Change master password (FR-AUTH-05).
- **FR-SET-06**: Server URL (FR-SRV-01), biometric/PIN unlock toggle + idle-lock timeout
  (FR-SESS-01/03), "Lock Now", "Log Out".

### 5.15 Admin (core subset — see Non-Goals §3 for what's excluded)
- **FR-ADMIN-01**: All Users list — role change, activate/deactivate.
- **FR-ADMIN-02**: Pending Approval — one-tap approve.
- **FR-ADMIN-03**: Audit Log — list with the filters the controller already supports
  (`page`/`pageSize`/`userId`/`action`/`from`/`to`) — **fix**, not copy, the web app's gap
  of never actually wiring these query params (§ research doc §3 AdminPage note).

### 5.16 Password Generator
- **FR-GEN-01**: Same options as web (length 8–128 default 20, uppercase/lowercase/
  numbers/symbols/exclude-ambiguous toggles, live regenerate, strength meter, copy,
  "use this password" applies back to the calling field). Same cryptographically-random
  generation approach (platform secure random, not a weak PRNG).

## 6. Non-Functional Requirements

### 6.1 Security — Vault Unlock Material
Given locked decision #1, the design must specify exactly what's stored and how, since
this is the one point where mobile deliberately diverges from the web app's pure
in-memory-only model:
- The decrypted RSA private key (or the material needed to re-derive it quickly) is
  stored via OS-level secure storage (Android Keystore / iOS Keychain), gated so
  retrieval requires a fresh biometric or device-PIN check each time — not merely
  "stored encrypted with a key that's always available to the app process."
  (`flutter_secure_storage` + `biometric_storage`, per research doc §3.)
- This material must never be transmitted, logged, or included in crash reports.
- Master-password rotation (FR-AUTH-05) must re-wrap or invalidate this stored material
  — a stale wrapped key must never decrypt post-rotation ciphertext.
- Full master-password re-entry remains available (and required after logout, biometric
  failure exhaustion, or fresh install) — biometric/PIN is a convenience layer on top of,
  not a replacement for, the master password.

### 6.2 Crypto Interoperability
- PBKDF2-SHA256, 600,000 iterations (exact match to web — **not** Argon2id, despite
  naming in some DTO comments; see research doc §1).
- AES-256-GCM, fresh random 96-bit IV per encryption operation, never reused.
- RSA-OAEP-2048/SHA-256 for key wrapping.
- A credential encrypted on web must decrypt correctly on mobile and vice versa — this is
  a hard interoperability requirement, verified by test cases in the sprint plan (§7),
  not assumed from "using the same algorithm names."

### 6.3 Offline & Sync
- Local cache stores ciphertext + non-sensitive metadata (type, folder/tag/group IDs,
  timestamps) synced from the API; decryption happens in memory after unlock, never
  written to the local cache in plaintext.
- Sync strategy: pull-based refresh (matching the web app's own model of "fetch fresh on
  navigate/refresh"), not a bidirectional real-time sync — mutations while offline should
  be queued and flushed on reconnect, with conflict handling deferred to "last write wins
  with a visible warning" for this pass (a full CRDT/merge strategy is out of scope).

### 6.4 Performance
- PBKDF2 at 600k iterations must complete in a reasonable time on mid-range hardware —
  use `cryptography_flutter`'s native-accelerated path, not pure-Dart, and measure on a
  real low-end device before committing to the UX flow around it (a multi-second unlock
  delay changes how "unlock" should be presented).

### 6.5 Platform Parity Boundary
- Shared Dart business logic (crypto, API client, state management, most UI) works
  identically on both platforms; platform-specific code (secure storage backing,
  biometric prompt, file save/share) isolated behind small abstraction interfaces so the
  iOS phase (locked decision #5) doesn't require re-deriving the whole app.

---

## Next step

Please review this requirements doc. Once you confirm it (as-is, or with changes), I'll
move on to the technical design doc and an interactive mockup of the key screens before
finalizing architecture + a phased sprint plan.
