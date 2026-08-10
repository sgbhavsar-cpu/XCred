# XCred Mobile — Play Store Listing Copy

Draft copy for the Play Console's "Store listing" page. Character limits are Google
Play's as of this writing — recheck before submitting in case they've changed.

## App name (30 characters max)

```
XCred
```

## Short description (80 characters max)

```
Zero-knowledge credential vault. Your master password never leaves your device.
```
(80/80)

## Full description (4000 characters max)

```
XCred is a zero-knowledge credential vault: a secure place for passwords, payment
cards, secure notes, SSH keys, network device logins, and more — encrypted on your
device before it ever reaches the server, so only you can read it.

CONNECT TO YOUR ORGANIZATION'S XCRED SERVER
XCred is self-hosted. This app is a client — point it at your organization's XCred
server URL and sign in with your existing account. There is no separate XCred cloud
service.

ZERO-KNOWLEDGE ENCRYPTION
Your master password never leaves your device. It's used to derive an encryption key
locally (PBKDF2-SHA256, 600,000 iterations), and every credential is encrypted
(AES-256-GCM) before it's sent to the server. The server only ever stores and returns
ciphertext — it cannot read your vault, and neither can anyone else without your master
password.

EVERYTHING YOU'D EXPECT FROM A VAULT
• 24+ credential types — website logins, payment cards, secure notes, SSH keys, network
  devices, email accounts, identity documents, insurance policies, recovery codes, and
  more, each with the right fields for that type.
• Folders, tags, and Credential Groups to organize things your way.
• Attachments — store an encrypted file alongside a credential.
• Built-in password generator with a real-time strength meter.
• Smart links — tap to open a website, dial a number, email a contact, or launch an SSH/
  RDP client directly from a credential.

SHARE SECURELY, WORK AS A TEAM
Share individual credentials with teammates using public-key envelope encryption — the
underlying credential key is only ever unwrapped for someone you explicitly grant
access to, and you can revoke access at any time. Organize your organization into teams
with their own admins and membership.

QUICK UNLOCK, YOUR WAY
Unlock with your fingerprint, face, or device PIN instead of retyping your master
password every time — protected by a fresh OS-level biometric/PIN check on every
unlock, not just a one-time convenience toggle. Your master password itself is never
stored on the device.

WORKS OFFLINE
Browse and use your vault even without a connection — changes sync automatically once
you're back online, with visible conflict handling if something changed elsewhere while
you were offline.

ADMIN TOOLS
Organization admins get a full panel: approve new accounts, manage roles, activate/
deactivate users, and review a searchable, filterable audit log — all from the phone.

No ads. No analytics. No trackers. Just your vault, encrypted the way it should be.
```

## Category

Productivity (or Tools — pick whichever the org's other listings use for consistency)

## Contact details (Play Console requires these, not shown in copy above)

- Email: [TODO — support email]
- Website: [TODO — if any]
- Privacy policy URL: [TODO — public URL hosting `docs/release/privacy-policy.md`'s
  content; Play Console requires a *live, publicly reachable* URL, a repo-relative path
  is not sufficient]

## Screenshots / graphics needed (not produced by this pass)

Play Console requires, at minimum:
- Phone screenshots: 2–8 images, each 16:9 or 9:16, JPEG/24-bit PNG (no alpha), min
  dimension 320px, max 3840px.
- A 512×512 hi-res icon (32-bit PNG with alpha) — can be exported from
  `assets/icon/icon.png` (currently 1024×1024, downscale to 512×512).
- A 1024×500 feature graphic (JPEG/24-bit PNG, no alpha).

Recommended screenshots (once there's a build to capture them from): Dashboard,
Credentials tree with a Credential Group expanded, Credential detail (password field
masked), Password generator, Smart-link "Open" action, Admin panel's Audit Log tab. Each
should show real (test) data — not empty states — so the listing shows actual product
value.

## Data safety section (Play Console form, not free text)

Per the privacy policy: the app collects/transmits **account data (username, email)**
and **credential ciphertext** (encrypted, not plaintext) to the server the user
configures; it does **not** collect analytics, advertising identifiers, or crash
reports. When filling out Play Console's Data Safety questionnaire, disclose:
- Personal info: email address, username — collected, used for account functionality,
  not shared with third parties, encrypted in transit (assuming the server is deployed
  behind TLS — see the note below).
- Financial info / other data types corresponding to whatever credential types a given
  deployment's users choose to store: mark as encrypted, not readable by the app
  developer or Google, since it's end-to-end encrypted client-side ciphertext the
  server cannot decrypt.
- No location, no contacts, no ads/analytics identifiers collected.

**Before submitting:** confirm the specific server deployment being pointed at for the
submitted build uses HTTPS/TLS in production — `AndroidManifest.xml` currently has
`usesCleartextTraffic="true"` for local dev against an HTTP backend; Play's Data Safety
declarations about "encrypted in transit" assume the deployed server is TLS-terminated.
