# XCred Mobile — Release Checklist (MOB-REL-01)

Tracks what's done vs. what requires a human with a Google Play Console account —
nothing past "Signed build" below can be done by an automated agent, since it needs
real payment/identity verification and a Google account.

## Done in this repo

- [x] App icon (padlock on brand purple, `assets/icon/`) generated and wired through
  `flutter_launcher_icons` — Android adaptive icon + iOS icon set both regenerated.
- [x] App display name set to "XCred" (`AndroidManifest.xml`'s `android:label`, iOS
  `Info.plist`'s `CFBundleDisplayName`) — was the default `xcred_mobile`/"Xcred Mobile"
  Flutter-template value.
- [x] Release signing configured (`android/app/build.gradle.kts`'s `signingConfigs`),
  reading from `android/key.properties` (gitignored) — falls back to debug signing if
  that file is absent, so a fresh clone/CI still builds.
- [x] Release keystore generated (`keytool`, RSA 2048, 10,000-day validity) — **see the
  "Keystore backup — read this" section below, this is the single most
  important item on this list.**
- [x] Verified `flutter build appbundle --release` actually signs with the release key
  (not debug) — confirmed via `jarsigner -verify -verbose -certs`, certificate subject
  `CN=XCred`, matching the generated keystore.
- [x] Privacy policy drafted: `docs/release/privacy-policy.md`.
- [x] Store listing copy drafted: `docs/release/play-store-listing.md`.

## Keystore backup — read this before doing anything else

The upload keystore is at:
```
C:\Users\sachin\.android-keystores\xcred\xcred-upload.jks
```
deliberately **outside** this git repository (and `android/key.properties`, which
points at it, is gitignored — per the Flutter template's own `.gitignore` comment
"never publicly share your keystore"). This is correct for security, but it means **it
exists in exactly one place on one machine** right now.

**Back this file up somewhere durable before relying on it** (password manager's file
attachment, encrypted cloud backup, whatever your org's secret-storage practice is) —
the store passwords are in `key.properties`. If this keystore is lost:
- Under Google Play App Signing (the recommended, and default-for-new-apps, flow):
  losing the *upload* key is recoverable — Google support can help re-key ownership
  once the app's already enrolled in Play App Signing, since Google holds the actual
  signing key separately.
- Without Play App Signing (self-managed signing): losing this keystore means **you can
  never publish an update to this app under the same package ID again** — Android
  requires every update to be signed by the same key that signed the first release.

Recommendation: enroll in Play App Signing at first upload (Play Console offers this by
default) specifically so this upload key's loss is recoverable rather than fatal.

## Still needed — requires a human + a Google Play Console account

1. **Create/access a Google Play Console developer account** (one-time $25 fee per
   Google account, identity verification required — cannot be automated).
2. **Create the app listing** in Play Console, paste in the copy from
   `docs/release/play-store-listing.md`, fill in the `[TODO]` placeholders there
   first (support email, privacy policy URL, developer/company name).
3. **Host the privacy policy at a public URL.** `docs/release/privacy-policy.md`'s
   content needs to live somewhere Play Console can link to and Google's review can
   fetch — a GitHub Pages page, the org's own website, etc. A repo-relative path is not
   acceptable to Play Console.
4. **Produce store graphics**: 512×512 hi-res icon (downscale `assets/icon/icon.png`
   from 1024×1024), a 1024×500 feature graphic, and 2–8 phone screenshots — see
   `play-store-listing.md`'s "Screenshots / graphics needed" section for the exact
   specs and suggested screens to capture.
5. **Fill out the Data Safety questionnaire** in Play Console per the guidance in
   `play-store-listing.md`'s "Data safety section".
6. **Confirm the production server's TLS setup** before submitting — `usesCleartextTraffic
   ="true"` in `AndroidManifest.xml` is fine for the local dev backend this project has
   been testing against, but the Data Safety questionnaire's "encrypted in transit"
   answer assumes whatever server URL real users will actually point the app at is
   HTTPS-terminated. If that's not the case yet, that's a server-deployment task, not a
   mobile-app one.
7. **Build the real release artifact**: `flutter build appbundle --release` (already
   verified working) — upload the resulting `.aab` to Play Console's internal testing
   track.
8. **Set up the internal testing track**: add tester email addresses/a Google Group in
   Play Console, share the opt-in link, confirm at least one real install from the
   track before considering this story done.
9. **Bump `pubspec.yaml`'s `version:`** for each subsequent release
   (`versionName+versionCode`, e.g. `1.0.1+2`) — currently `1.0.0+1`, appropriate for
   the very first upload.

## Explicitly out of scope for this pass

- Actual Play Console account creation/payment — needs a human with a Google account
  and a payment method.
- iOS App Store equivalent (Apple Developer Program enrollment, App Store Connect
  listing) — that's Phase 4 (iOS Port) per `docs/planning/sprint-plan.md`, not this
  sprint.
