# XCred Flutter Mobile — Phased Sprint Plan

**Status:** Final (2026-08-09)
**Story ID convention:** `MOB-<AREA>-NN` (new for this project — no prior mobile
convention existed). Each story references the FR-ID(s) it implements from
`docs/Requirements/Requirements-Flutter-Mobile.md`.
**Sprint length assumption:** 2 weeks — adjust to your team's actual cadence; the
grouping/dependency order matters more than the exact calendar.

---

## Phase 0 — Foundations & Risk Spikes

*Goal: retire the two things that could silently invalidate the whole plan if wrong,
before any screen is built on top of them.*

### Sprint 0.1 — Scaffold & Interop Spike

**MOB-SETUP-01: Project scaffold**
- As a developer, I need the Flutter project wired with the chosen stack so feature work
  has a consistent foundation.
- Acceptance criteria:
  - Riverpod (code-gen) + go_router + dio + drift installed and each proven with one
    trivial working example (a provider, a route, an API call, a table read/write).
  - Lint rules enforced in CI matching the strictness the web app's ESLint config
    implies (no unused vars silently allowed, etc.).
  - `docker-compose.yml` (existing, from the web app work) usable as the dev backend
    target — confirmed by pointing the scaffold's `ApiClient` at `http://localhost:18080`
    and successfully hitting `GET /api/dashboard` (expect 401 unauthenticated — proves
    connectivity + JSON parsing, not auth yet).
- Test cases: CI pipeline green on a clean checkout; `flutter analyze` zero warnings.

**MOB-SETUP-02: RSA-OAEP-2048 interop spike** *(architecture.md §7 risk #1 — highest
priority item in the entire plan)*
- As a developer, I need proof that mobile's RSA-OAEP implementation is byte-for-byte
  interoperable with the web app's Web Crypto implementation, before building any
  feature that depends on it.
- Acceptance criteria:
  - A throwaway Dart script (not shipped in the app) that: (a) takes a
    `encryptedCredentialKey` + the corresponding private key produced by a **real** web
    app registration/credential-creation against the Docker dev backend, decrypts it with
    PointyCastle, and recovers the correct AES key (verified by then decrypting the
    credential's `EncryptedData` and getting back the exact plaintext JSON the web app
    shows); (b) the reverse — Dart generates a keypair + wraps a key, and a browser
    console script using the web app's own `crypto.ts` functions unwraps it correctly.
  - Both directions documented with a pass/fail note in this file's "Spike Results"
    section (added once run) — a fail here changes the crypto library choice in
    `architecture.md` §2 before any real code depends on it.
- Test cases: (a) and (b) above, run manually, results recorded, not automated (this is a
  one-time proof, not regression-tested — the *unit tests* in MOB-CRYPTO-01 below are
  the ongoing regression coverage).

**MOB-SETUP-03: PBKDF2 performance measurement**
- As a developer, I need to know real unlock-time latency on representative hardware
  before finalizing the unlock UX.
- Acceptance criteria: PBKDF2-SHA256/600k iterations measured via
  `cryptography_flutter`'s native path on (a) a mid-range Android device (2-3 year old,
  not a flagship) and (b) an emulator baseline for comparison. Result recorded here.
  If >1.5s on the mid-range device, flag for a UX decision (progress indicator wording,
  whether to reduce iterations with a documented security tradeoff — **do not silently
  reduce iterations**, that's a security-relevant call requiring explicit sign-off).
- Test cases: timed measurement, 10 runs, median reported.

### Sprint 0.2 — Crypto Service Core

**MOB-CRYPTO-01: Port CryptoService with fixed-vector tests**
- As a developer, I need the core crypto primitives implemented and regression-tested
  against fixed vectors captured from the web app, so future changes can't silently break
  cross-platform compatibility.
- Acceptance criteria: `deriveKey`, `encrypt`/`decrypt` (AES-GCM), `generateKeyPair`,
  `wrapKey`/`unwrapKey` (RSA-OAEP), `encryptPrivateKey`/`decryptPrivateKey`,
  `generatePassword`, `passwordStrength` all implemented per architecture.md §2/§4.
- Test cases:
  1. Given a real salt+master-password+ciphertext triple captured from the web app,
     `deriveKey` + `decrypt` recovers the exact known plaintext.
  2. Given a real RSA key pair from the web app, `unwrapKey` on a web-produced
     `encryptedCredentialKey` recovers the exact known AES key bytes.
  3. `encrypt` then `decrypt` round-trips arbitrary UTF-8 (including emoji, the exact
     shape of a real credential JSON payload).
  4. Two consecutive `encrypt` calls on identical plaintext with the same key produce
     **different** ciphertext (IV uniqueness, not reused).
  5. `generatePassword({length:20, symbols:true, excludeAmbiguous:true})` never contains
     `I`, `l`, `1`, `O`, `0`; 100-run distribution sanity check (not literally uniform-
     random-verified, just "doesn't degenerate to a narrow character subset").

---

## Phase 1 — Core Vault (Android)

*Goal: a user can register/log in, unlock with biometrics on return visits, and fully
manage credentials (all types, groups, folders, tags, attachments) both online and
offline.*

### Sprint 1.1 — Auth & Server Setup

**MOB-SRV-01: Server URL setup screen** (FR-SRV-01/02)
- As a user, I enter my organization's XCred server address on first launch so the app
  knows where to send requests.
- Acceptance criteria: URL field, "Continue" disabled until a reachability check
  succeeds (a lightweight unauthenticated ping, e.g. the SPA's `index.html` or a
  dedicated health check if one exists — confirm during implementation), stored via
  `flutter_secure_storage`, editable later from Settings without re-onboarding.
- Test cases: valid reachable URL → proceeds; unreachable URL → inline error, doesn't
  proceed; changing the URL from Settings updates all subsequent API calls immediately
  (no stale base URL cached in a closure).

**MOB-AUTH-01: Registration** (FR-AUTH-01)
- As a new user, I register with username/email/login password/master password and
  understand there's no recovery if I lose the master password.
- Acceptance criteria: matches web's Zod-equivalent validation (login pw ≥8 chars, master
  pw ≥12), live strength meters, mandatory acknowledgment checkbox, key pair + salt
  generated on-device before the API call (never server-generated), first-user-becomes-
  admin handled transparently (server-side, no client logic needed).
- Test cases: weak passwords blocked with the correct message; mismatched confirm fields
  blocked; successful registration against the Docker dev backend as the *first* user
  results in immediate ability to log in (auto-approved); as a *second* user results in a
  "pending approval" state on login attempt.

**MOB-AUTH-02: Login** (FR-AUTH-02/03)
- As a returning user, I log in with username/login password/master password and reach
  the vault.
- Acceptance criteria: correct error messaging for each server error code (invalid
  credentials, pending approval, locked, inactive) — reuse the same error-code-to-message
  mapping the web app already has, don't re-derive independently.
- Test cases: correct credentials → dashboard; wrong login password → server-rejected
  with correct message; correct login password + wrong master password → **client-side**
  rejection (private key decrypt fails) with a distinct message from "wrong login
  password" (this distinction matters — it's proof the zero-knowledge property holds even
  against a client that has valid tokens but not the real master password).

### Sprint 1.2 — Vault Unlock & Session

**Status: Done (2026-08-09).** Verified end-to-end on the Pixel_10_Pro emulator against
the live Docker dev backend (`integration_test/session_lifecycle_test.dart`): enroll on
first login → app-restart lands on `/unlock` → biometric check unwraps the real private
key with no network call → Lock Now soft-locks and re-resumes via Unlock → Log Out clears
persisted material and lands back on `/login`. Real biometric hardware isn't available in
this environment (no fingerprint/PIN enrolled on the AVD), so `BiometricGate` was swapped
for a fake via the same Riverpod-provider-override seam architecture.md §5 describes for
this purpose — everything else (`flutter_secure_storage`, drift, the router redirect
guard, the real backend calls) is real. Two real bugs found and fixed along the way: (1)
`local_auth` needs `FlutterFragmentActivity`, not `FlutterActivity` — fixed in
`MainActivity.kt`; (2) a background `BiometricGate.isAvailable()` probe during
post-login enrollment had no bound — added a 3s timeout so a slow/stuck platform-channel
query can never block login itself.

**MOB-SESS-01: Biometric/PIN unlock enrollment** (FR-SESS-01)
- As a user, after my first full login, I'm offered to enable biometric/PIN unlock so I
  don't retype my master password every time.
- Acceptance criteria: prompt appears once per device (not nagging on every login),
  declining is remembered (don't re-ask every session), accepting wraps the private key
  via `SecureVaultStorage.storeWrappedKey()`.
- Test cases: decline → next app open still requires full login; accept → next app open
  shows the Unlock screen instead.

**MOB-SESS-02: Unlock screen** (FR-SESS-02)
- As a returning user with unlock enabled, I unlock with a fingerprint/face/PIN check
  instead of retyping my master password.
- Acceptance criteria: `BiometricGate.authenticate()` → success unwraps the stored key
  and proceeds to Dashboard; failure allows retry up to a small limit then offers PIN
  fallback; "enter master password" always available as an escape hatch.
- Test cases: successful biometric → vault accessible, decrypts correctly (proves the
  unwrapped key is the *real* private key, not a stub); simulated repeated failure →
  PIN fallback surfaces; master-password escape hatch always reachable regardless of
  biometric failure count.

**MOB-SESS-03: Auto-lock & manual lock** (FR-SESS-03/04)
- As a user, my session locks after an idle period (matching the real
  `orgSettings.sessionTimeoutMinutes`, not a hardcoded value — this is the exact class of
  bug fixed in the web app this session; mobile must not reintroduce it), or I can lock
  manually from Settings.
- Acceptance criteria: idle timer resets on user interaction; timeout clears the
  in-memory private key (not the wrapped secure-storage copy — that's what makes the next
  unlock fast); "Lock Now" does the same immediately; "Log Out" additionally clears the
  wrapped secure-storage copy entirely.
- Test cases: idle past `orgSettings.sessionTimeoutMinutes` → Unlock screen shown, wrapped
  key still present (fast re-unlock); "Log Out" → next app open requires full login, no
  wrapped key exists.

### Sprint 1.3 — Credentials List & Detail (Read Path)

**Status: Done (2026-08-09).** Verified end-to-end on the Pixel_10_Pro emulator against
the live Docker dev backend's real data — `xcred_admin` already had 56 credentials across
3 Credential Groups from earlier web Playwright runs, created with the same crypto
scheme (confirmed interoperable in the Sprint 0.2 spike): a strong end-to-end proof this
app's field rendering and `CryptoService` are correct against real cross-platform data,
not just self-consistent. Three integration tests:
`integration_test/credentials_read_path_test.dart` (tree renders, search narrows to a
guaranteed-no-match empty state and back, detail screen decrypts and renders real
fields, copy shows the live countdown toast) and
`integration_test/offline_cache_test.dart` (MOB-SYNC-01: real online load populates the
drift cache, then a simulated network failure falls back to the cache with the offline
banner, still rendering real decrypted data). Real `adb shell svc data disable`
connectivity cuts proved too fragile to interleave reliably with a running `flutter test`
process, so the offline test instead wraps the real `ApiClient` in a toggleable fake via
the same provider-override seam already used for `BiometricGate` — a deterministic,
Dart-level "network unreachable" simulation rather than real radio state, with
everything else (drift, real login, real decryption) genuine. Tags are stored as an
embedded JSON column on the cached credential row for this sprint (not a join table) —
deliberate scope-matching: this sprint only reads tags, never manages them; a real
`tags`/`credential_tags` schema arrives with Sprint 1.5's Tag CRUD.

**MOB-CRED-01: Credentials tree screen** (FR-CRED-01)
- As a user, I browse my vault as an expandable tree of Credential Groups + an ungrouped
  section, with search and type filtering.
- Acceptance criteria: matches web's already-redesigned tree UX (this session's web
  work) — group rows expand/collapse, member counts update live, search filters by
  decrypted name/username/tag match.
- Test cases: expand/collapse persists during the screen's lifetime; search narrows
  results and an empty-search state shows "no matches" (not a blank screen); offline
  (airplane mode) shows the cached tree with a "last synced" indicator instead of an
  error.

**MOB-CRED-02: Credential detail (read-only)** (FR-CRED-03)
- As a user, I view a credential's decrypted fields, reveal/hide passwords, copy values
  (with real clipboard-clear timing from org settings), and use smart links.
- Acceptance criteria: every populated field renders per its `FieldDef` type; empty/
  empty-list fields are skipped (not shown as blank rows); copy triggers the audit-log
  ping (`POST /credentials/:id/copy`) same as web.
- Test cases: password field starts masked, reveal toggles it, re-navigating away and
  back re-masks it (no stale reveal state leak); copy shows the countdown toast and
  clipboard actually clears after the configured seconds (not hardcoded 30 — verify
  against a non-default org setting value in the test backend).

**MOB-SYNC-01: Offline cache read path** (requirements §6.3)
- As a user, I can view my previously-synced vault without connectivity.
- Acceptance criteria: `CredentialRepository`/`FolderRepository`/etc. all implement
  cache-first-when-offline per architecture.md §3.3; a visible "offline — showing last
  synced data" banner when no connectivity.
- Test cases: sync while online, force airplane mode, confirm the full tree + detail
  views still work and decrypt correctly from the local drift cache alone.

### Sprint 1.4 — Credential Create/Edit, All Types, Password Generator

**Status: Done (2026-08-09).** Verified end-to-end on the Pixel_10_Pro emulator against
the live Docker dev backend. Scoping note on MOB-CRED-03's per-type matrix: rather than
literally driving all 19 types through the UI, two focused tests cover every distinct
*field type* (text/password/textarea/select/url/list) and every cross-cutting concern
(generator, custom fields, tags/folder/group pickers, expiry) — the 19 types share one
uniform, data-driven rendering/serialization code path (`kCredentialFields` drives
`_buildField`; no per-type branches exist anywhere in `credential_form_screen.dart`), so
exhaustive UI repetition would re-test the same code path 19 times, not add real
coverage. `integration_test/credential_form_test.dart`:
1. Create a WebsiteLogin using the password generator end-to-end (open sheet, regenerate,
   "Use This Password" writes back), save, verify the username field round-tripped, then
   edit the URL and confirm the type picker is hidden and the update persisted.
2. Create a NetworkDevice with a 3-item list field (remove the middle one → verify
   `[10.0.0.1, 10.0.0.3]` survives reload in order), 2 custom fields, a tag, a real
   folder, a real credential group, and an expiry date — all five survive save + reload.

Real bugs found and fixed along the way (all in app code, not just tests):
- `DashboardScreen._load()` had a genuine `setState()`-after-dispose gap — two of its
  three `setState` calls weren't `mounted`-guarded (only the `finally` block's was),
  latent since Sprint 1.1 and only surfaced once a test navigated away mid-fetch.
- The form screen originally used `ListView(children: [...])` for a bounded-size form.
  Unlike `SingleChildScrollView`/`Column` (used successfully in Login/Register),
  `ListView` is Sliver-backed and lazily builds only children near the viewport even
  with a fixed children list — fields further down the form didn't exist in the widget
  tree until scrolled into view. Switched to `SingleChildScrollView(child: Column(...))`.
- List-field rows now carry explicit `Key`s (`list_<fieldKey>_<index>`) — needed for
  reliable test targeting once multiple same-shaped empty `TextFormField`s exist on one
  screen, and cheap, permanent test-ergonomics value even outside this one sprint.
- MOB-GEN-01's "disable generation with a clear message" requirement is a deliberate
  mobile improvement over web's current behavior — crypto.ts's `generatePassword`
  silently falls back to lowercase-only when every character class is toggled off;
  `generatePassword()` here returns `null` instead, the sheet shows an inline message in
  place of a password, and "Use This Password" disables (Regenerate stays tappable but
  is a no-op until at least one class is re-enabled). Not filed as a web bug fix (out of
  scope this session), but worth knowing web and mobile deliberately diverge here.

**MOB-CRED-03: Create/edit form shell + type picker** (FR-CRED-02)
- As a user, I pick a credential type from a grid and get the right fields for it.
- Acceptance criteria: type picker shown on create only (immutable after creation,
  matching web); dynamic field rendering driven by the same `FieldDef` table structure
  used in the mockup, ported to cover **all 19 types** from the verified inventory.
- Test cases (template — repeat per type, or parametrize as a single test matrix):
  for each of WebsiteLogin, Database, ApiKey, SshKey, CreditCard, SecureNote, WiFi,
  SoftwareLicense, Certificate, EnvironmentVariables, BankAccount, MobileBankingPin,
  NetworkDevice, Rdp, EmailAccount, IdentityDocument, InsurancePolicy, RecoveryCodes,
  Generic — create one, verify every field round-trips through encrypt→save→fetch→
  decrypt→display correctly. This is the mobile equivalent of the web app's
  `credential-types.spec.ts` Playwright suite — **reuse the same sample-data-per-type
  approach**, don't hand-roll 19 separate ad hoc tests.

**MOB-CRED-04: List-type fields** (FR-CRED-04, NetworkDevice.ipAddresses)
- As a user, I add/remove multiple IP addresses on a Network Device credential.
- Acceptance criteria: add/remove rows, stored as a JSON string array in the encrypted
  payload exactly matching web's format (interop matters here too — a NetworkDevice
  credential created on mobile must display correctly on web and vice versa).
- Test cases: add 3 rows, remove the middle one, save, reload — order and content of
  remaining 2 preserved correctly.

**MOB-CRED-05: Custom fields, tags, folder/group pickers, expiry** (FR-CRED-02)
- As a user, I add arbitrary custom fields, assign tags, pick a folder and/or credential
  group, and set an expiry date.
- Acceptance criteria: matches web's custom-field editor (label/value/type triplets),
  multi-select tag pills, folder picker (flattened indented tree, matching web), credential
  group picker.
- Test cases: a credential with 2 custom fields + 3 tags + a folder + a group saves and
  reloads with all five intact.

**MOB-GEN-01: Password generator bottom sheet** (FR-GEN-01)
- As a user, I generate a strong password from any password field via a bottom sheet with
  live options.
- Acceptance criteria: matches the validated mockup exactly — length slider (8-128,
  default 20), 4 character-class toggles + exclude-ambiguous, live regenerate, strength
  meter, "Use This Password" writes back to the originating field.
- Test cases: (already validated once via the mockup's Playwright script — port those
  same assertions into the real app's widget tests) regenerate produces a different
  value; length slider change regenerates at the new length; toggling all character
  classes off disables generation with a clear message rather than silently producing an
  empty string.

### Sprint 1.5 — Credential Groups, Folders, Tags

**Status: Done (2026-08-09).** Verified end-to-end on the Pixel_10_Pro emulator against
the live Docker dev backend with `integration_test/folders_tags_groups_test.dart`: create
a fresh Credential Group + Folder + Tag, assign one credential to all three, then delete
each in turn and confirm the credential survives with that one association cleared each
time (folder deletion doesn't touch the group/tag; tag deletion doesn't touch the
folder/group; group deletion doesn't touch either) — the core "unlink, don't
cascade-delete" contract shared by all three entities, and the sprint's explicit test
case. Deliberately used fresh throwaway fixtures rather than the account's existing
"E2E ..." seed data from earlier web/mobile testing, since this test is destructive.

Folder/Tag picker read paths from Sprint 1.4's credential form were promoted to full
repository-backed `AsyncNotifierProvider`s (`folderTreeProvider`/`tagListProvider`,
replacing the picker-only `FutureProvider`s) so the same data now backs both the form's
pickers and these new management screens — no duplicate fetch logic.

One real test-authoring bug found and fixed (not an app bug): the `FilterChip` tap for
tag selection intermittently missed because a preceding multi-line text field left the
on-screen keyboard open — `ensureVisible`'s scroll target was computed against the
keyboard-open viewport, then the keyboard closed before the tap fired, shifting the
layout and leaving the tap aimed at a stale position. Fixed by explicitly dismissing the
keyboard (`tester.testTextInput.receiveAction(TextInputAction.done)`) before interacting
with anything below a multi-line field.

**MOB-CGRP-01: Credential Group create/rename/delete + detail** (FR-CGRP-02/03)
**MOB-FOLD-01: Folder tree create/rename/delete, nested** (FR-FOLD-01/02)
**MOB-TAG-01: Tag create/rename/recolor/delete** (FR-TAG-01)
- Each: as a user, I manage groups/folders/tags and see their member credentials via the
  same shared list-row pattern as the main Credentials screen.
- Acceptance criteria (all three): CRUD parity with web's already-built (this session)
  patterns; deleting unlinks/moves-to-"No Folder" rather than deleting member
  credentials, matching web exactly.
- Test cases (all three): delete a folder containing credentials → credentials survive
  with `folderId: null`; delete a credential group → member credentials survive with
  `credentialGroupId: null`; delete a tag → removed from all previously-tagged
  credentials.

### Sprint 1.6 — Attachments

**Status: Done (2026-08-09).** Verified end-to-end on the Pixel_10_Pro emulator against
the live Docker dev backend with `integration_test/attachments_test.dart`: upload a
file, confirm its decrypted original filename appears in the list, download it and
confirm the filename/MIME type/bytes all round-tripped exactly (MOB-ATT-02's core
concern — the same class of bug fixed in the web app earlier this project, not
reintroduced here), attempt an oversized upload against a real non-default
`orgSettings.maxAttachmentSizeMb` (set to 1 MB for this test, restored to 10 afterward)
and confirm client-side rejection shows the real configured figure, then delete the
attachment (with its confirmation dialog) and confirm it's gone.

Real OS file-picker/share-sheet dialogs render outside the Flutter app's own widget
tree, so `WidgetTester` can't drive them — used the same provider-override seam already
established for `BiometricGate`/`ApiClient` in earlier sprints: `FileExchange` (new
platform abstraction, architecture.md §5/§6) is swapped for a fake that returns known
bytes on "pick" and records what it's given on "save/share". Everything else
(encryption, the real backend, decryption) is genuine.

One real dependency-resolution problem hit and fixed: `file_picker` (Android-relevant
versions up to 11.0.3) and `share_plus`/`flutter_secure_storage` disagreed on the
`win32` package's version — a Windows-desktop-only transitive dependency that never
touches the Android build. Forcing a `dependency_overrides` pin initially "fixed" pub's
resolver but left `file_picker`'s actual Windows source code broken at compile time
(written against an older `win32` API) — which matters even for an Android-only app,
because `flutter test` on this Windows host still compiles every platform variant.
Fixed properly by using `file_picker: ^12.0.0-beta.7`, which genuinely depends on a
`win32` version compatible with the others (no override needed).

Two real test-authoring bugs fixed (not app bugs, same recurring class from earlier
sprints): a Save-button tap missed because the keyboard was still open when
`ensureVisible` computed its scroll target (fixed by dismissing the keyboard first,
matching Sprint 1.5's fix); and the delete-attachment assertion ran before dismissing
its own confirmation dialog (a dialog I'd added and then forgotten about when writing
the test), which trivially caused the filename to appear twice in the tree.

**MOB-ATT-01: Upload** (FR-ATT-01)
- As a user, I attach a file to a credential, encrypted client-side.
- Acceptance criteria: filename/mime/data each independently AES-GCM-encrypted (fresh IV
  each) under the parent credential's key, matching web's exact envelope shape; enforces
  the **real** `orgSettings.maxAttachmentSizeMb`.
- Test cases: file under the limit uploads and appears in the list; file over the limit
  is rejected client-side with the correct MB figure shown (from org settings, verified
  against a non-default configured value in the test backend — same discipline as
  MOB-CRED-02's clipboard test).

**MOB-ATT-02: Download** (FR-ATT-02)
- As a user, I download an attachment with its original filename and extension intact.
- Acceptance criteria: decrypted filename + MIME type used in the native save/share flow
  (`FileExchange.saveOrShare`) — this is the mobile equivalent of the exact bug fixed in
  the web app earlier this project (attachment showing "Encrypted file" / losing its
  extension) — **must not reintroduce it**.
- Test cases: upload a `.pdf`, download it, confirm the saved/shared file has the
  original filename and opens correctly (extension-dependent apps on the OS recognize it
  as a PDF, proving the MIME type carried through correctly too).

### Sprint 1.7 — Offline Sync (Write Path)

**MOB-SYNC-02: Queued offline mutations** (requirements §6.3)
- As a user, changes I make while offline are saved locally and sent once I'm back
  online.
- Acceptance criteria: `PendingMutation` queue per architecture.md §2, flushed in order
  on reconnect, each flush failure surfaces a visible conflict banner rather than
  silently overwriting or dropping.
- Test cases: edit a credential offline, go back online, confirm the edit reaches the
  server; edit the *same* credential from the web app while mobile is offline with its
  own pending edit queued, then bring mobile online — confirm the conflict banner
  appears rather than either edit silently winning.

---

## Phase 2 — Collaboration & Admin (Android)

*Goal: sharing, teams, settings, and the core admin subset all reach parity.*

### Sprint 2.1 — Sharing

**MOB-SHARE-01: Shared With Me / Shared By Me** (FR-SHARE-01/02)
**MOB-SHARE-02: Share flow (create + revoke)** (FR-SHARE-03)
- As a user, I share a credential with another user or team, and see/manage what's
  shared with or by me.
- Acceptance criteria: recipient picker uses `GET /users` (not admin-gated), client-side
  re-wrap of the credential's AES key for the recipient's public key exactly matching
  web's envelope-re-wrap logic; revoke requires confirmation.
- Test cases: share a credential, confirm it's decryptable by the recipient (cross-check:
  log in as the recipient account, view the shared credential, confirm correct
  plaintext); revoke, confirm it disappears from the recipient's Shared-With-Me.

### Sprint 2.2 — Teams

**MOB-TEAM-01: Team list/detail/create/add-remove member/delete** (FR-TEAM-01)
- Acceptance criteria: uses `GET /users` for the member picker (the exact endpoint fix
  applied to web this session — mobile never had the bug to begin with, this just
  confirms it's built right from the start).
- Test cases: a non-global-admin team admin successfully adds a member (this is the
  specific scenario the web bug silently broke — confirm mobile doesn't).

### Sprint 2.3 — Settings

**MOB-SET-01: Profile, change login password** (FR-SET-01/02)
**MOB-SET-02: Notification preferences** (FR-SET-03)
**MOB-SET-03: Backup export/restore** (FR-SET-04)
**MOB-SET-04: Master password rotation** (FR-SET-05, FR-AUTH-05)
- The highest-risk Settings story: full client-side re-encryption of every credential's
  wrapped key, matching web's per-credential fallback-to-old-key safety net on individual
  re-wrap failure, **plus** invalidating/re-wrapping the biometric-unlock secure-storage
  entry (mobile-only concern, no web equivalent).
- Test cases: rotate master password, confirm all credentials still decrypt correctly
  under the new key; confirm the *old* wrapped biometric-unlock secret can no longer
  unlock the vault (must re-enroll or use the new master password); simulate one
  credential's re-wrap failing (e.g. malformed test data) and confirm the rest of the
  vault still completes successfully with a clear post-rotation warning about the one
  that didn't.
**MOB-SET-05: Server URL, biometric toggle, auto-lock timeout, Lock Now, Log Out**
(FR-SET-06) — covered incrementally by MOB-SRV-01/MOB-SESS-01/03, this story is the
Settings-screen wiring that surfaces them together.

### Sprint 2.4 — Core Admin

**MOB-ADMIN-01: Users list, role change, activate/deactivate** (FR-ADMIN-01)
**MOB-ADMIN-02: Pending approval** (FR-ADMIN-02)
**MOB-ADMIN-03: Audit log with working filters** (FR-ADMIN-03)
- MOB-ADMIN-03 acceptance criteria explicitly includes wiring `page`/`pageSize`/
  `userId`/`action`/`from`/`to` query params to real UI controls — the web app's gap
  (it never wires these, always shows page 1 of 50) is **not** copied to mobile.
- Test cases: filter audit log by action type, confirm results match; paginate past page
  1, confirm different results load (proves the param is actually reaching the API, not
  just present in the UI with no effect).

---

## Phase 3 — Polish & Android Release

### Sprint 3.1 — Smart Links, Empty States, Accessibility

**MOB-LINK-01: Smart link dispatch** (FR-LINK-01/02)
- Port `computeFieldLink`/`networkDeviceLink` dispatch tables exactly; `url_launcher` for
  OS hand-off.
- Test cases: each `linkType` (email/tel/ssh/rdp/network-device-ip) produces the correct
  URI scheme; tapping a `mailto:`/`tel:` link opens the OS default app (verifiable on a
  real device/emulator with a mail/phone app configured); `ssh:`/`rdp:` links degrade
  gracefully (no crash) when no handler app is installed.

**MOB-POLISH-01: Empty/error/loading states audit**
- Every list screen has a distinct empty state (not just "no items" text) matching the
  mockup's visual language; every network call has a distinguishable offline-vs-error
  state.

**MOB-A11Y-01: Accessibility pass**
- Screen reader labels on icon-only buttons (matching the web app's title-attribute
  additions made during this project's own accessibility fixes), minimum touch target
  sizes, focus order sanity check.

### Sprint 3.2 — Hardening & Release Prep

**MOB-SEC-01: Security review**
- Confirm no sensitive material in logs/crash reports (requirements §6.1); confirm
  `SecureVaultStorage` retrieval genuinely re-prompts biometric each call, not just once
  per app-process lifetime (architecture.md §7 risk #3 — verify, don't assume).

**MOB-REL-01: Play Store submission prep**
- Store listing, privacy policy (data handling disclosure — genuinely zero-knowledge, so
  this should be a straightforward, honest disclosure), signed release build, internal
  testing track.

---

## Phase 4 — iOS Port

*Goal: the same app on iOS, via the platform-abstraction layer built for exactly this
moment.*

### Sprint 4.1 — iOS Platform Implementations

**MOB-IOS-01: SecureVaultStorage (Keychain), BiometricGate (LocalAuthentication),
FileExchange (UIActivityViewController) implementations**
- Test cases: the *entire* Phase 1/2 test suite re-run on iOS with zero shared-code
  changes required — if a shared-code change turns out to be needed, that's a signal the
  Phase 1-3 abstraction boundary (architecture.md §5) leaked, worth a retro note.

**MOB-IOS-02: Apple Developer Program setup, TestFlight**

### Sprint 4.2 — iOS QA & Release

**MOB-IOS-03: iOS-specific QA pass** (safe-area handling, iOS biometric prompt copy/
behavior differences, Dynamic Type support)
**MOB-IOS-04: App Store submission**

---

## Spike Results (fill in as Phase 0 completes)

| Spike | Result | Date | Notes |
|---|---|---|---|
| MOB-SETUP-02 RSA-OAEP interop | **PASS** — confirmed bidirectional | 2026-08-09 | Used Node's `crypto.webcrypto` (the same `crypto.subtle` API/algorithm calls as `crypto.ts`, not a browser) instead of driving the actual web app, since Node 20+'s WebCrypto implementation is spec-identical for RSA-OAEP-2048/SHA-256 — a lower-friction way to get the same guarantee. Script: `src/XCred.Mobile/spike/gen_vectors.mjs` → `test/crypto_interop_spike_test.dart` → `spike/verify_dart_output.mjs`. Found and resolved one real risk along the way: PointyCastle's `OAEPEncoding` doc comment warns it implements the older RFC 2437 encoding (no leading `0x00` byte in EM) rather than RFC 3447/8017 — analysis showed this is a non-issue (a leading zero byte doesn't change the OS2IP-decoded integer), and the empirical spike confirms it: PointyCastle's OAEP interoperates correctly with WebCrypto in both directions. Hand-rolled ASN.1 SPKI/PKCS8 DER codec (`encodeSpki`/`decodeSpki`/`encodePkcs8`/`decodePkcs8` in `crypto_service.dart`) also verified byte-compatible. |
| MOB-SETUP-03 PBKDF2 performance | **~3.28s avg** (600k iterations) | 2026-08-09 | Measured on-device via `integration_test/pbkdf2_perf_test.dart` on the `Pixel_10_Pro` emulator (5 runs after 1 warm-up: 3228/3294/3310/3194/3349 ms, avg 3275ms), using `cryptography_flutter`'s native-accelerated path. **Caveat**: this environment has no physical low/mid-range Android device — `Pixel_10_Pro` is a flagship-tier *emulator*, itself running on the dev machine's host CPU rather than real mobile silicon, so this number is a best-available proxy, not a true low-end-device measurement, and real low-end hardware should be expected to be slower. Even at this best-case figure, ~3.3s meaningfully confirms architecture.md §4.4's performance-risk concern: PBKDF2 must run once at first login only, with biometric-gated secure storage (already the locked design, requirements.md §6.1) carrying every return visit — a spinner/progress state is needed on that first-login path, not just a nice-to-have. |
