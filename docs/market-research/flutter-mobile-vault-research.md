# Market & Technical Research — XCred Flutter Mobile App

Researched 2026-08-09, in support of designing a Flutter mobile client for XCred with
feature parity to the existing web app. Two kinds of research below: (1) direct reads of
the actual XCred codebase (verified, not guessed), (2) web research on Flutter crypto
tooling and comparable mobile password-manager conventions (external, not independently
verified beyond what the search results state — flagged as such).

## 1. XCred web app — verified by direct code read

A full feature/API/crypto inventory was compiled by reading the current working tree
directly (including uncommitted work) rather than relying on `docs/`, which is out of
date relative to the code (e.g. it doesn't yet document the new `Rdp` credential type).
That inventory is long enough to live in the requirements doc directly rather than
duplicated here — see `docs/Requirements/Requirements.md` §"Feature Inventory" once
written. Highlights most relevant to mobile design decisions:

- **Crypto is PBKDF2-SHA256 (600,000 iterations)**, not Argon2id despite some stale
  comments/naming in the codebase suggesting otherwise. Mobile must match this exactly —
  same salt + same password must derive the same key on both platforms, since a user's
  vault is one shared ciphertext store regardless of which client opens it.
- **RSA-OAEP-2048 + AES-256-GCM envelope encryption** for sharing; each credential has
  its own random AES key, wrapped in RSA-OAEP for the owner (and separately, per
  recipient, for shares).
- **Zero-knowledge invariant**: the web app never persists the derived symmetric key or
  decrypted RSA private key to disk — only auth tokens/user/public key go to
  localStorage. A page reload always requires re-entering the master password. This is a
  core security property, not an implementation detail, and is the central design
  question for mobile (see clarifying questions).
- The API is a normal self-hosted REST backend (no multi-tenant SaaS layer) — mobile
  needs some notion of "which server" to talk to, unlike a fixed-backend consumer app.

## 2. Flutter cryptography tooling (external research)

Search: *"Flutter PBKDF2 SHA256 AES-GCM RSA-OAEP 2048 cryptography package dart 2026"*

- **`cryptography` (pub.dev, Google-maintained)** — supports PBKDF2, SHA-256, AES-GCM
  natively in pure Dart, with a companion **`cryptography_flutter`** plugin that routes
  the expensive operations (PBKDF2 in particular) to native platform crypto APIs for
  real performance — relevant given 600k PBKDF2 iterations is deliberately slow-by-design
  and a pure-Dart implementation could be noticeably worse on lower-end phones.
- RSA-OAEP-2048 support is thinner across the Dart crypto ecosystem than AES/PBKDF2.
  **PointyCastle** is the commonly-cited option for RSA-OAEP specifically. Likely
  approach: `cryptography`/`cryptography_flutter` for PBKDF2 + AES-GCM, PointyCastle (or
  `webcrypto.dart`, a Google package wrapping platform WebCrypto-equivalent APIs) for
  RSA-OAEP. This needs a short spike/proof-of-concept early in implementation to confirm
  interop with the exact ciphertext format the .NET/Web Crypto side produces (padding
  scheme, key encoding) — flagged as a technical risk in the design doc, not something to
  hand-wave.
- Sources: [aes256 pub.dev](https://pub.dev/packages/aes256), [cryptography pub.dev](https://pub.dev/packages/cryptography), [webcrypto.dart](https://github.com/google/webcrypto.dart/blob/master/README.md), [Pbkdf2 class docs](https://pub.dev/documentation/cryptography/latest/cryptography/Pbkdf2-class.html)

## 3. Biometric unlock & secure storage conventions (external research)

Search: *"flutter_secure_storage biometric unlock local_auth password manager best
practice 2026"*

- Standard stack: **`flutter_secure_storage`** (backs onto iOS Keychain / Android
  Keystore — OS-managed encryption at rest) for anything sensitive that must persist,
  **`local_auth`** for the biometric prompt itself (returns only a boolean — never raw
  biometric data), optionally **`biometric_storage`** for data stores gated directly
  behind a biometric/device-credential check.
- Consistent guidance across sources: biometrics authenticate *device presence*, not a
  server session — they should unlock a *locally stored secret*, not replace the backend
  JWT/OAuth flow. A PIN fallback is expected (Face ID/Touch ID can fail — gloves, angle,
  hardware issues) after a small number of failed biometric attempts.
- Sources: [Flutter Studio security guide](https://flutterstudio.dev/blog/flutter-app-security-guide.html), [Flutter Gems biometric packages](https://fluttergems.dev/biometric-local-auth/), [biometric_storage](https://github.com/authpass/biometric_storage)

## 4. Comparable product: Bitwarden mobile (external research)

Search: *"Bitwarden mobile app architecture offline vault sync autofill 2026"*

Bitwarden is the closest public analog to XCred (self-hostable, zero-knowledge,
client-server, open-source mobile clients) and is a reasonable precedent to check XCred's
mobile design against, though XCred is not required to match it feature-for-feature.

- **Vault lock/unlock model**: encrypted vault data is cached locally; "lock" keeps the
  ciphertext on-device but discards the derived key, unlockable again via master
  password, **PIN, or biometrics** — i.e. Bitwarden does NOT require full master-password
  re-entry on every app open in the way XCred's web client currently does. This is
  presented as the standard/expected mobile UX for this class of app.
  [source](https://bitwarden.com/help/getting-started-mobile/)
- **Offline access**: most Bitwarden clients work offline once initially synced, since
  the encrypted vault is cached locally — full end-to-end encryption is preserved because
  the cache is ciphertext, decrypted only in memory after unlock.
  [source](https://bitwarden.com/blog/configuring-bitwarden-clients-for-offline-access/)
- **Autofill**: iOS uses the native Credential Provider extension (offered directly from
  within the app); Android uses the Autofill Framework (API 26+) and, on Android 10+,
  FIDO's Credential Exchange Protocol for cross-app import/export.
  [iOS autofill](https://bitwarden.com/help/auto-fill-ios/), [Android autofill](https://bitwarden.com/help/auto-fill-android/)

**Implication for XCred mobile**: matching this UX (lock/unlock with biometrics+PIN,
offline cache, autofill) is a materially larger scope than "port the web screens to
Flutter" — each is a real architecture decision, not a UI nicety, and is exactly what the
clarifying-questions pass needs to resolve deliberately rather than assume.
