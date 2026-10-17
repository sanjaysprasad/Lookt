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
            // Wake display and send a non-destructive Shift key to reveal the password prompt
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.wakePromptWithShift()
            }

        case .autoUnlock:
            guard let password = KeychainStore.loadLoginPassword(), !password.isEmpty else {
                // If password is not set, fall back to waking prompt
                DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.35) { [weak self] in
                    self?.wakePromptWithShift()
                }
                return
            }

            // Allow display and loginwindow 0.5s to illuminate and prepare the password field
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.typePassword(password)
            }
        }
    }

    /// Wakes the display using an IOKit power assertion and caffeinate user activity signal.
    private func wakeDisplay() {
        var assertionID: IOPMAssertionID = 0
        let reason = "Lookt Face ID Match Wake" as CFString
        IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                    reason,
                                    &assertionID)

        let task = Process()
        task.launchPath = "/usr/bin/caffeinate"
        task.arguments = ["-u", "-t", "3"]
        try? task.run()

        if assertionID != 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                IOPMAssertionRelease(assertionID)
            }
        }
    }

    /// Safely wakes the lock screen clock/screensaver without typing any character into the password field.
    private func wakePromptWithShift() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        pressKey(virtualKey: 0x38, source: source) // Left Shift
    }

    /// Simulates typing the password and pressing Return using CoreGraphics HID events.
    private func typePassword(_ password: String) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        // 1. Wake the lock screen prompt safely using Shift key (does not type a character)
        pressKey(virtualKey: 0x38, source: source)
        usleep(300_000) // 300ms for password input animation to stabilize

        // 2. Clear any stale contents in the password field (Cmd+A -> Delete)
        if let selectAllDown = CGEvent(keyboardEventSource: source, virtualKey: 0x00, keyDown: true), // 'a'
           let selectAllUp = CGEvent(keyboardEventSource: source, virtualKey: 0x00, keyDown: false) {
            selectAllDown.flags = .maskCommand
            selectAllUp.flags = .maskCommand
            selectAllDown.post(tap: .cghidEventTap)
            selectAllUp.post(tap: .cghidEventTap)
            usleep(50_000)
            pressKey(virtualKey: 0x33, source: source) // Delete / Backspace
            usleep(50_000)
        }

        // 3. Type each character of the password
        for char in password.utf16 {
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { continue }
            var codeUnit = char
            keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: &codeUnit)
            keyUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: &codeUnit)
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
            usleep(15_000) // 15ms per character
        }

        // 4. Send Return to submit the password
        usleep(150_000) // 150ms pause before Enter
        pressKey(virtualKey: 0x24, source: source) // Return / Enter
    }

    private func pressKey(virtualKey: CGKeyCode, source: CGEventSource) {
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false) else { return }
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
