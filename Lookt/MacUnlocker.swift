import Foundation
import AppKit
import CoreGraphics
import IOKit.pwr_mgt

enum UnlockMode: String, CaseIterable, Identifiable {
    case autoUnlock = "Auto-Unlock"
    case wakeOnly = "Wake & Focus Only"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .autoUnlock:
            return "Automatically types your stored password on a verified face match to unlock your Mac immediately."
        case .wakeOnly:
            return "Wakes the screen and focuses the password field; you complete unlock with Touch ID or your password."
        }
    }
}

/// Handles waking the display and completing authentication upon a verified Face ID match.
final class MacUnlocker {
    static let shared = MacUnlocker()

    private init() {}

    /// Checks whether Lookt has macOS Accessibility permissions to simulate keystrokes.
    var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts macOS to display the Accessibility permission request dialog or opens System Settings.
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    /// Performs the unlock action according to the user's configured mode.
    func performUnlock(mode: UnlockMode) {
        wakeDisplay()

        switch mode {
        case .wakeOnly:
            // Waking display + short delay + pressing Space to focus the password prompt
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.pressKey(virtualKey: 0x31) // Space bar
            }

        case .autoUnlock:
            guard let password = KeychainStore.loadLoginPassword(), !password.isEmpty else {
                // If password is not stored, gracefully fall back to wake only
                DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.pressKey(virtualKey: 0x31)
                }
                return
            }

            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.typePassword(password)
            }
        }
    }

    /// Wakes the display using an IOKit power assertion and caffeinate signal.
    private func wakeDisplay() {
        var assertionID: IOPMAssertionID = 0
        let reason = "Lookt Face ID Match Wake" as CFString
        IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                    reason,
                                    &assertionID)

        // Run caffeinate user activity probe to signal screen wake
        let task = Process()
        task.launchPath = "/usr/bin/caffeinate"
        task.arguments = ["-u", "-t", "2"]
        try? task.run()

        if assertionID != 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                IOPMAssertionRelease(assertionID)
            }
        }
    }

    /// Simulates typing the password and pressing Return using CoreGraphics HID events.
    private func typePassword(_ password: String) {
        // Send a wake-up key (Space/Esc) to ensure password field is focused
        pressKey(virtualKey: 0x35) // Esc to clear any stale screensaver overlay
        usleep(150_000) // 150ms

        let utf16 = Array(password.utf16)
        for char in utf16 {
            guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else { continue }
            var codeUnit = char
            keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: &codeUnit)
            keyUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: &codeUnit)
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
            usleep(10_000) // 10ms between keystrokes
        }

        usleep(100_000) // 100ms before Return
        pressKey(virtualKey: 0x24) // Return / Enter
    }

    private func pressKey(virtualKey: CGKeyCode) {
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: virtualKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: virtualKey, keyDown: false) else { return }
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
