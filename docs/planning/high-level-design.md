# XCred Flutter Mobile — High-Level Design

**Status:** Final (post-mockup confirmation, 2026-08-09)
**Supersedes:** `docs/design/flutter-mobile-design.md` (draft)
**Companion docs:** `docs/planning/architecture.md` (system/component architecture),
`docs/Requirements/Requirements-Flutter-Mobile.md`, interactive mockup at
`docs/artifacts/flutter-mobile-mockup.html`

This doc covers screen-by-screen design and the local data model. System architecture,
crypto model, security, and testing strategy live in `architecture.md` — this file
doesn't repeat them.

---

## 1. Screen Designs

Each screen below references its requirements FR-IDs and notes anything the mockup
confirmed or changed versus the original draft design.

### 1.1 Server Setup (`/setup`)
First-run only, plus reachable from Login's "Change" link (mockup confirmed this
placement reads naturally — server identity as a small inline fact on the login screen,
not a separate settings-menu hunt). Single field (URL), validated reachable before
`Continue` enables. FR-SRV-01.

### 1.2 Login (`/login`)
Three fields (username, login password, master password) — **not** collapsed to fewer,
despite the mobile-brevity instinct, because the two-secret model (requirements §4/§6.2)
is a security property, not a UI inconvenience to design around. Live strength meter on
both password fields during registration (not login, where the password already exists).
Mockup confirmed the "your master password never leaves this device" helper note reads
well as a small inline card rather than a modal/tooltip — keeps it visible without
demanding a dismissal. FR-AUTH-01/02/03.

### 1.3 Unlock (`/unlock`)
Shown instead of Login whenever a device unlock is configured and a session exists
(architecture.md §3.2). Single dominant fingerprint affordance, PIN as an equal-weight
fallback link (not buried), "enter master password" as a smaller escape hatch below —
mockup confirmed this hierarchy (biometric primary, PIN secondary, master password
tertiary) reads correctly without instruction text. Authenticating state shows a brief
pulse + checkmark rather than a spinner, since the actual OS biometric prompt is what's
doing the real work — this is just the moment before/after it. FR-SESS-01/02.

### 1.4 Dashboard (`/dashboard`)
Three-stat row (credentials/shared/teams) using tabular-nums so the numbers don't jitter
on refresh, expiring-soon list (empty state distinct from "loading" — a checkmark card,
not a blank list), recent activity feed. Fetches `orgSettings` here too
(architecture.md's `OrgSettingsProvider`) — same endpoint the web app uses, and the same
place the web app's earlier hardcoded-defaults bugs originated, so this is the one and
only place mobile reads these values from, matching the web fix made this session.
FR-DASH-01..04.

### 1.5 Credentials (`/credentials`)
The central screen. Expandable Credential Group rows (mirroring the web app's
already-redesigned tree view from this same project) + an "Ungrouped" section, live
search (filters name/type), per-group quick-add. Mockup confirmed the tree pattern
translates directly to mobile with no rework needed — same interaction model (tap row to
expand, chevron rotates), just touch-sized targets instead of mouse-hover affordances.
Folder/Tag filtering surfaces here as a filter control (§6 of architecture.md), not as
separate destinations. FR-CRED-01, FR-CGRP-01/02.

### 1.6 Credential Detail (`/credentials/:id`)
Per-field: label, value (masked for password-type until revealed), and up to 3 inline
icon actions (reveal, open-link where applicable, copy). Mockup confirmed 3 icon buttons
per field row fits at 390px width without crowding, including on the longest field labels
in the type table (e.g. "Transaction PIN (MPIN)"). List-type fields (Network Device IPs)
render as a compact vertical list with a per-item open-link button, not a horizontal
scroller — reads better at phone width than the web app's own layout for the same field.
Copy shows a bottom toast with a live countdown (real `orgSettings.clipboardClearSeconds`,
not hardcoded — same fix applied to web this session). Attachments section: list +
upload; download uses `FileExchange.saveOrShare()` (native share sheet), not a
blob-URL-click trick, since that mechanism doesn't exist on mobile. FR-CRED-03, FR-ATT-02,
FR-LINK-01/02.

### 1.7 Credential Create/Edit (`/credentials/new`, `/credentials/:id/edit`)
Type picker as a 4-column emoji grid at the top (create only; mockup confirmed this fits
cleanly and scans fast even for all 19 types scrolled). Fields render dynamically from
the same `FieldDef` table structure as web (ported field-for-field per the verified
inventory). Password fields get a key icon that opens the **Generator as a bottom sheet**
— mockup confirmed the bottom-sheet pattern (not a full-screen route) keeps the user's
place in the form, and validated the whole flow works: length slider, character-class
toggles, live regenerate, strength meter, "Use This Password" writing straight back into
the calling field. List-type fields (add/remove rows) confirmed working at mobile width
without a separate "manage list" sub-screen. FR-CRED-02/04, FR-GEN-01.

### 1.8 Credential Group Detail (`/groups-cred/:id`)
Member list + add-existing/add-new/remove, same pattern as web's `CredentialGroupDetailPage`.
Not separately mocked (reuses the same list-row component as 1.5/1.6) — flag if you want
this one built out in the interactive prototype too. FR-CGRP-03.

### 1.9 Folders / Tags
Not separate screens — surfaced as filters on Credentials (§1.5, architecture.md §6).
Managing folders/tags themselves (create/rename/delete) lives behind a lightweight
management sheet reachable from the same filter control, mirroring the web app's own
Folders/Tags pages functionally without needing bottom-nav real estate for them.
FR-FOLD-01/02, FR-TAG-01.

### 1.10 Shares (`/shares`)
Two-tab layout (Shared With Me / Shared By Me), status pills (expired/until-date/
until-changed/no-expiry) using the semantic color tokens (warning/danger/success) from
architecture — not the violet accent, keeping status legible at a glance per the "encode
state in form, not just color" UI principle. FR-SHARE-01/02/03.

### 1.11 Teams (`/teams`)
List → expand → members, add/remove (via the corrected `/users` endpoint per the web fix
this session — mobile is built correctly from the start, no bug to avoid). FR-TEAM-01.

### 1.12 Settings (`/settings`)
Grouped sections: Security (biometric toggle, auto-lock timeout, master password),
Server, Data (backup/restore, offline sync status — mockup confirmed a small "Synced Xm
ago" status pill reads well here as a trust signal for the offline-capable design),
Account (Lock Now, Log Out). Mockup confirmed the biometric toggle as a standard settings
row + switch (not a separate onboarding-style screen after the first prompt) is
sufficient — the meaningful decision moment is FR-SESS-01's first-login prompt, this is
just the ongoing control. FR-SET-01..06.

### 1.13 Admin (`/admin`, core subset)
Three tabs: Users, Pending Approval, Audit Log (with the filters the API already
supports, actually wired this time — the web app's gap noted in requirements §5.15,
fixed on mobile from the start). Not in the mockup (role-gated, lower traffic than the
core vault screens) — flag if wanted. FR-ADMIN-01/02/03.

## 2. Local Data Model (drift)

Tables mirror the API's list-endpoint response shapes closely — this keeps the
cache-refresh logic in each Repository simple (largely "upsert what the API returned")
rather than requiring a translation layer:

```
credentials(id, type, encryptedData, dataIv, encryptedCredentialKey, folderId,
            credentialGroupId, expiryDate, updatedAt, isShared, ownerId, syncedAt)
tags(id, name, color, credentialCount, syncedAt)
credential_tags(credentialId, tagId)              -- join table
folders(id, name, parentFolderId, sortOrder, credentialCount, syncedAt)
credential_groups(id, name, icon, groupId, credentialCount, syncedAt)
teams(id, name, description, memberCount, myRole, syncedAt)
team_members(teamId, userId, username, email, role, joinedAt)
shares(id, credentialId, direction, sharedWithOrBy, expiresAt, untilChanged,
       isRevoked, encryptedData, dataIv, encryptedCredentialKey, syncedAt)
attachments(id, credentialId, encryptedFileName, fileNameIv, encryptedMimeType,
            mimeTypeIv, fileSizeBytes, uploadedAt)   -- metadata only; blob fetched
                                                       -- on demand, not pre-cached
                                                       -- (size/storage tradeoff)
pending_mutations(id, entityType, entityId, operation, payloadJson, createdAt, status)
```

Attachments' encrypted **content** is deliberately not pre-synced into the local cache
(unlike everything else) — attachments can be large, and the offline value of "know an
attachment exists, fetch its bytes when actually opened" is a better tradeoff than
bloating the local cache with every attachment's ciphertext on every sync. If this proves
wrong in practice (e.g. users frequently need attachments while genuinely offline), it's
a config toggle to add later, not an architecture change.

## 3. API Mapping

Every mobile Repository method maps 1:1 to an existing endpoint from the verified
inventory (`docs/market-research/flutter-mobile-vault-research.md` §1 references the full
controller list) — **no new backend endpoints required**. The only backend-adjacent
change from this whole effort is the web app bug fixes already shipped this session
(org-settings-driven timeouts, corrected Teams picker endpoint) and the independently-
scheduled Windows Hello feature (requirements §0.2), neither of which mobile depends on.

## 4. Open Items Carried Into Sprint Planning

- RSA-OAEP-2048 interop spike (architecture.md §7 risk #1) — first thing built, Phase 0.
- PBKDF2 performance measurement on real low/mid-range Android hardware — Phase 0.
- Credential Group Detail and Admin screens weren't in the interactive mockup — low risk
  (they reuse already-validated list/tree patterns) but available to mock out on request
  before Phase 1 sprint work starts on them, if wanted.
