# Developer Guide

This doc is for people building/extending Lookt itself. Looking to
just use the app? See [README.md](README.md) instead.

# Lookt — Face ID for Mac (scaffold)

A menu-bar utility that watches the camera while your Mac is locked and,
once it recognizes you (with liveness checks to reject photos/video),
wakes the screen and focuses the password field so you can finish
unlocking with Touch ID or your password. It runs alongside Touch ID and
password — it doesn't replace either.

**Fully local.** No network calls anywhere in this codebase. Enrollment
data (face embeddings, not raw images) is stored encrypted in the macOS
Keychain, scoped to this device only.

> **Before you rely on this, read `SECURITY.md`.** In short: the default
> face-matching model is a placeholder (weaker than production face
> recognition), liveness detection is a deterrent rather than a guarantee,
> and there's no auto-password-fill by design. This is a solid scaffold
> for a personal project — treat it as security-hardened only after you've
> extended and tested it yourself.

Requires Apple Silicon (M-series). Not tested on Intel Macs.

## How to open this as an Xcode project

1. Open Xcode → File → New → Project → macOS → App.
2. Name it `Lookt`, interface: SwiftUI, language: Swift.
3. Delete the auto-generated `ContentView.swift` and `LooktApp.swift`.
4. Drag all files from `Sources/Lookt/` in this folder into your
   Xcode project (check "Copy items if needed").
5. Add the Info.plist keys from `Info.plist.additions.xml`.
6. Signing & Capabilities → add **Hardened Runtime**, enable **Camera**.
7. Build & run. You'll get a menu bar icon (face ID glyph) — click it →
   "Enroll / Re-enroll Face" to run the enrollment flow.

## What's implemented vs. what's a stub

**Implemented:**
- Menu bar app shell, no Dock icon (`App.swift`)
- Lock/unlock detection via macOS distributed notifications (`LockScreenWatcher.swift`)
- Camera pipeline via AVFoundation, local frames only (`CameraManager.swift`)
- Face detection + landmarks via Vision (`FaceEmbedder.swift`)
- Multi-frame, multi-signal liveness detection — blink + micro-motion (`LivenessDetector.swift`)
- Multi-condition enrollment (straight/left/right/dim-light, 3 captures each, averaged) (`FaceEnrollment.swift`, `EnrollmentView.swift`)
- Encrypted local storage of embeddings in Keychain, no raw images kept (`KeychainStore.swift`)
- Max-brightness-on-attempt with restore (`BrightnessController.swift`)
- Auth loop requiring liveness + match across multiple consecutive frames before succeeding (`FaceAuthController.swift`)

**Deliberately left as integration points, read the comments in these files before extending:**
- `FaceEmbedder.swift` — ships a placeholder geometric embedding (landmark
  distances). This works out of the box but is **weaker** than a real
  recognition model. Swap in a bundled CoreML face-recognition model
  (converted FaceNet/ArcFace/MobileFaceNet) for production-grade accuracy —
  it's a contained change, only this file.
- `BrightnessController.swift` — uses a private framework
  (`DisplayServices`) since Apple doesn't expose brightness control
  publicly on Apple Silicon. Fine for personal/direct-distribution builds,
  will not pass App Store review.
- `FaceAuthController.onAuthSuccess()` — currently just posts a
  notification. Wiring this to actually wake the display / focus the
  password field, or eventually auto-fill it, is left for you to decide
  deliberately (see the security note in `KeychainStore.swift` about why
  auto-typing the password is the highest-risk part of this whole design).

## Tuning

- `FaceAuthController.matchThreshold` (0.92) and `requiredConsecutiveMatches`
  (4) — start conservative (fewer false accepts), loosen only after testing
  false-reject rate with your own face across lighting conditions.
- `LivenessDetector` blink/motion thresholds — tune against your own webcam;
  values will vary by camera sensor and typical lighting.

## Publishing this publicly

- Add your name/contact to `LICENSE` and `SECURITY.md` before pushing.
- This app cannot ship via the App Store (it uses a private framework for
  brightness control) — distribute via GitHub Releases as a notarized
  `.dmg`/`.app`. Notarizing requires an Apple Developer account ($99/yr);
  without it, users will need to right-click → Open past Gatekeeper.
- Consider adding GitHub's default Code of Conduct and a CONTRIBUTING.md
  if you want outside PRs.

## Next steps I'd suggest, in order

1. Get enrollment + matching working end-to-end with the placeholder
   embedder — confirms the pipeline, camera permissions, Keychain storage.
2. Swap in a real CoreML face-recognition model once the pipeline works.
3. Decide on the "match success" action deliberately (wake+focus vs.
   auto-fill) — this is a security decision, not just a UX one.
4. Test liveness against your own phone/laptop screen replay attempts
   before trusting it.
