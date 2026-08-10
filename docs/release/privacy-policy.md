# XCred Mobile — Privacy Policy

**Effective date:** [TODO: fill in before publishing]
**Last updated:** 2026-08-10

This policy covers the XCred mobile app ("the App"), a client for the self-hosted XCred
credential vault. XCred is **zero-knowledge**: the App is built so that neither the
XCred server operator nor anyone else can read your stored credentials — only you can,
using your master password. This document explains exactly what that means in practice,
and what limited account/operational data the server your organization runs *does* see.

> XCred is self-hosted software. The App connects to whichever server URL you or your
> organization's administrator configures — there is no XCred-operated cloud service.
> The operator of that server (your employer, team, or you yourself) is the data
> controller for the account data described below, not the App's developer. If you're
> an end user of an organization's XCred deployment, that organization's own IT/privacy
> policies govern how they operate the server; this document describes what the App
> itself does with your data on the device and in transit.

## What the App never sees, stores, transmits, or can access

- **Your master password.** It is used only to derive an encryption key on your device
  (PBKDF2-SHA256, 600,000 iterations) and is never sent to the server, stored anywhere,
  written to any log, or included in any crash report.
- **Your decrypted credential data** — passwords, notes, custom fields, attachment
  contents, or any other vault content in plaintext. All of it is encrypted
  (AES-256-GCM) on your device before it is ever sent to the server; the server only
  ever stores and returns ciphertext it cannot read.
- **Your derived encryption key or decrypted private key.** These exist only in memory
  while the App is unlocked, or (if you enable "Quick Unlock") wrapped behind an
  OS-level biometric/PIN check in your device's secure storage (Android Keystore) —
  never transmitted anywhere.

## What the server (your organization's XCred deployment) does store

Because the App needs an account system, sharing, folders/tags, and an audit trail to
function, the following is stored server-side, in plaintext (not end-to-end encrypted,
since none of it is vault content):

- **Account data:** username, email address, and a salted hash of your login password
  (never your master password).
- **Organizational metadata:** folder names, tag names, credential group names, team
  names/memberships — the *labels* you choose, not the credential values inside them.
- **Sharing metadata:** who a credential was shared with and when, so access can be
  managed and revoked — not the credential's decrypted content.
- **Audit log entries:** action type (e.g. login, credential viewed, share created),
  timestamp, the acting user, and the IP address the request came from — this exists so
  an administrator can detect suspicious activity on their own deployment.
- **Encrypted blobs:** your encrypted credential fields and encrypted attachment files,
  stored as opaque ciphertext the server cannot decrypt.

## What stays on your device only

- Your master password (only ever held in memory during a session, or briefly during
  entry).
- A locally cached copy of your vault for offline access, stored in an on-device
  encrypted database.
- If enabled, a biometric/PIN-gated wrapped key used for "Quick Unlock" — retrieving it
  requires a fresh OS-level biometric or device-PIN check every time, not just once per
  app session.

## Device permissions the App requests, and why

- **Internet access** — to talk to the XCred server you configure.
- **Biometric hardware** — only used if you opt in to "Quick Unlock"; you can always
  fall back to your full master password instead.
- **File access (via the system file/share picker)** — only when you explicitly choose
  to attach a file to a credential or export/share one; the App does not scan your
  device's files otherwise.

## Analytics, advertising, and crash reporting

**None.** The App does not integrate any analytics SDK, advertising SDK, or crash
reporting service. No usage data, device identifiers, or crash reports are collected or
transmitted to any third party by the App itself. (Your organization's server operator
may separately log standard web-server access logs for their own deployment, per the
Audit log entries described above — that's a server-side operational concern, not
something the App adds.)

## Data retention and deletion

Your organization's XCred administrator controls retention of account and audit data on
their deployment. To request deletion of your account or data, contact your
organization's XCred administrator directly, or [TODO: fill in a contact
method/support email for the App's developer, for App-level questions].

## Children's privacy

The App is not directed at children and is not intended for use by anyone under the age
required by their jurisdiction to manage online accounts without guardian consent.

## Changes to this policy

If this policy changes, the "Last updated" date above will change accordingly. Material
changes will be reflected in the App's store listing changelog.

## Contact

[TODO: fill in — developer/company name, support email, and/or website, before
publishing this policy publicly or submitting to an app store.]
