# Lookt

<p align="center">
  <img src="assets/banner.png" alt="Lookt — Face ID for macOS" width="100%">
</p>

<p align="center">
  <a href="https://github.com/sanjaysprasad/Lookt"><img src="https://img.shields.io/badge/Platform-macOS%2013%2B-blue?style=flat-square&logo=apple" alt="macOS 13+"></a>
  <a href="https://github.com/sanjaysprasad/Lookt"><img src="https://img.shields.io/badge/Architecture-Apple%20Silicon%20(M1--M4)-black?style=flat-square&logo=apple" alt="Apple Silicon"></a>
  <a href="https://github.com/sanjaysprasad/Lookt"><img src="https://img.shields.io/badge/Security-Apple%20Vision%20Neural%20Prints-00E5FF?style=flat-square" alt="Vision Neural"></a>
  <a href="https://github.com/sanjaysprasad/Lookt"><img src="https://img.shields.io/badge/Liveness-Anti--Spoofing%20Blink%20Cycle-00E676?style=flat-square" alt="Anti-Spoofing"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-lightgrey?style=flat-square" alt="MIT License"></a>
</p>

---

**Lookt** brings Apple iPhone-style **Face ID** authentication to your Mac. Operating directly under the MacBook display notch with an organic **Dynamic Island** animation, Lookt utilizes Apple Silicon's Neural Engine and Vision framework to securely identify your face, reject spoofing attempts, and automatically unlock your Mac.

Everything runs **100% locally and offline** on your device. Zero cloud dependencies, zero analytics, zero external network traffic.

---

## ✨ Key Features

- **🏝️ Dynamic Island Notch Animation**  
  Flows smoothly out of the physical MacBook notch using native spring physics. Displays real-time state feedback: looking for face, live blink prompts, wrong face shake warnings, and Apple-style checkmark success chimes. Visible seamlessly over macOS lock screens.

- **⚡️ Apple Vision Neural Feature Prints (778-dim)**  
  Replaces naive landmark points with Apple's high-dimensional convolutional neural feature vectors (`VNGenerateImageFeaturePrintRequest`) fused with 3D anthropometric facial ratios. Delivers enterprise-grade biometric accuracy (cosine similarity $\ge 0.78$).

- **🛡️ Anti-Spoofing & Liveness Detection Engine**  
  Rejects static printed photos, smartphone screen replays, and video loops using a continuous 3-phase bilateral blink state machine (Open $\to$ Closed $\to$ Reopen) combined with 3D dynamic micro-parallax head tracking.

- **🔄 Continuous Face Polling**  
  If an unrecognized face glances at the camera, Lookt flashes a subtle warning pill and keeps actively scanning for up to 40 seconds—never giving up on the first failed frame.

- **🎭 Multi-Appearance Face Profiles**  
  Enroll multiple looks to ensure seamless recognition across different conditions:
  - *Default Face* (standard daytime appearance)
  - *With Glasses* (prescriptions, sunglasses)
  - *Low Light / Night* (under dim lighting with automatic brightness boost)
  - *Headwear* (beanies, caps, hats)
  - *Alternative Look* (different hairstyles, facial hair)

- **🔓 Flexible Unlock Modes**  
  - **Auto-Unlock**: Automatically submits your encrypted password from the local macOS Keychain via direct hardware keycode simulation upon a verified Face ID match.
  - **Wake & Focus Only**: Wakes the display and focuses the password field; you complete authentication via Touch ID or password.

---

## 💻 Requirements

- **Mac**: Apple Silicon (M1, M2, M3, M4 series)
- **Operating System**: macOS 13.0 (Ventura), macOS 14.0 (Sonoma), or macOS 15.0+ (Sequoia)
- **Camera**: Built-in FaceTime HD camera or external USB/Continuity camera
- **Permissions**: Camera Access and Accessibility (for Auto-Unlock keypress emulation)

---

## 🚀 Installation

### Option 1: Download `.dmg` Installer
1. Download `Lookt.dmg` from the repository root or [Releases](../../releases).
2. Open `Lookt.dmg` and drag **Lookt** into your `Applications` folder.
3. Launch Lookt from Launchpad or Spotlight.

### Option 2: Build from Source
```bash
git clone https://github.com/sanjaysprasad/Lookt.git
cd Lookt
open Lookt.xcodeproj
```
Select the **Lookt** scheme, choose **My Mac (Mac Catalyst or macOS)**, and press `⌘ + R` to build and run.

---

## 🛠️ Quick Setup Guide

1. **Launch Lookt**: The setup window will open presenting your Face Profile Manager.
2. **Add Face Profile**: Click **Add Face Style**, select an appearance mode, and look straight into the camera.
3. **Set Auto-Unlock (Optional)**: If you want automatic hands-free unlock, enter your macOS login password in the encrypted Keychain prompt.
4. **Grant Accessibility**: If prompted, enable Lookt in `System Settings → Privacy & Security → Accessibility` so it can simulate unlock signals at the lock screen.
5. **Test Face ID**:
   - In-app: Click **Test Face ID** in the setup window to preview neural matching and anti-spoofing in real time.
   - Lock your Mac: Press `⌃ + ⌘ + Q` (Control + Command + Q). Look at the camera notch and blink naturally—your Mac unlocks instantly!

---

## 🔒 Security & Privacy Architecture

- **Encrypted Local Storage**: Biometric feature vectors and unlock credentials never leave your Mac and are saved exclusively in the macOS Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).
- **No Network Permissions**: Lookt contains zero networking code, URL sessions, or outbound telemetry.
- **Hardware-Level Display Control**: Uses native `IOPMAssertion` to keep the screen active during biometric scans without interfering with system power management.
- For complete security disclosure and architectural design, please consult [SECURITY.md](SECURITY.md).

---

## 🤝 Acknowledgements & Open Source Credits

- **MobileFaceNet (ArcFace)**: Sheng Chen et al. Deep face recognition architecture trained with additive angular margin loss.
- **[FaceGate-Mac](https://github.com/dweep-desai/FaceGate-Mac)** by [@dweep-desai](https://github.com/dweep-desai): Pre-compiled CoreML weights reference and normalization pipeline under the MIT License.
- **Apple CoreML & Vision**: For hardware-accelerated on-device neural processing.

---

## 👤 Author & Maintainer

**Sanjay Sivaprasad**  
- **Email**: [sjp.builds@gmail.com](mailto:sjp.builds@gmail.com)  
- **GitHub**: [@sanjaysprasad](https://github.com/sanjaysprasad)

---

## 📄 License

Lookt is released under the **MIT License**. See [LICENSE](../LICENSE) for details.  
Copyright (c) 2026 Sanjay Sivaprasad <sjp.builds@gmail.com>.
