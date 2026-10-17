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
            break

        case .autoUnlock:
            guard let password = KeychainStore.loadLoginPassword(), !password.isEmpty else {
                return
            }

            // Allow display and lockscreen 0.45s to wake and stabilize input focus
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.45) { [weak self] in
                self?.typePassword(password)
            }
        }
    }

    /// Wakes the display and dismisses the lockscreen screensaver to focus the password field.
    private func wakeDisplay() {
        var assertionID: IOPMAssertionID = 0
        let reason = "Lookt Face ID Match Wake" as CFString
        IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                    reason,
                                    &assertionID)

        let task = Process()
        task.launchPath = "/usr/bin/caffeinate"
        task.arguments = ["-u", "-t", "5"]
        try? task.run()

        // Send Space key to immediately dismiss the lockscreen clock/screensaver and bring up the password field
        if let source = CGEventSource(stateID: .hidSystemState) {
            sendSingleKey(keyCode: 0x31, flags: [], source: source) // Spacebar
        }

        if assertionID != 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
                IOPMAssertionRelease(assertionID)
            }
        }
    }

    /// Simulates typing the password cleanly without doubling or clipping keystrokes.
    /// Strictly posts to cghidEventTap only with a natural key-hold duration.
    private func typePassword(_ password: String) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        // 1. Clear any wake space or accidental characters by sending Delete keypresses
        for _ in 0..<8 {
            sendSingleKey(keyCode: 0x33, flags: [], source: source) // Delete
            usleep(20_000)
        }
        usleep(60_000) // 60ms pause before typing

        // 2. Type each character with hardware-accurate keycode, shift flag, and natural hold
        for char in password {
            if let mapping = Self.keyMapping(for: char) {
                let flags: CGEventFlags = mapping.needsShift ? [.maskShift] : []
                sendSingleKey(keyCode: mapping.keyCode, flags: flags, unicodeChar: char, source: source)
            } else {
                sendSingleUnicode(char: char, source: source)
            }
            // 35ms cadence between characters to let WindowServer securely process each character
            usleep(35_000)
        }

        // 3. Pause 120ms then send Return to submit the password
        usleep(120_000)
        sendSingleKey(keyCode: 0x24, flags: [], source: source) // Return / Enter
    }

    private func sendSingleKey(keyCode: CGKeyCode, flags: CGEventFlags, unicodeChar: Character? = nil, source: CGEventSource) {
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return }

        keyDown.flags = flags
        keyUp.flags = flags

        if let char = unicodeChar {
            var codeUnit = Array(String(char).utf16)[0]
            keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: &codeUnit)
            keyUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: &codeUnit)
        }

        // Post ONLY to cghidEventTap to prevent event duplication
        keyDown.post(tap: .cghidEventTap)
        usleep(16_000) // 16ms natural hardware key hold duration
        keyUp.post(tap: .cghidEventTap)
    }

    private func sendSingleUnicode(char: Character, source: CGEventSource) {
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return }

        keyDown.flags = []
        keyUp.flags = []

        var codeUnit = Array(String(char).utf16)[0]
        keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: &codeUnit)
        keyUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: &codeUnit)

        keyDown.post(tap: .cghidEventTap)
        usleep(16_000)
        keyUp.post(tap: .cghidEventTap)
    }

    // MARK: - Hardware Keycode Translation Table (US / ABC Keyboard)

    private struct KeyMapping {
        let keyCode: CGKeyCode
        let needsShift: Bool
    }

    private static func keyMapping(for char: Character) -> KeyMapping? {
        switch char {
        case "a": return KeyMapping(keyCode: 0x00, needsShift: false)
        case "A": return KeyMapping(keyCode: 0x00, needsShift: true)
        case "b": return KeyMapping(keyCode: 0x0B, needsShift: false)
        case "B": return KeyMapping(keyCode: 0x0B, needsShift: true)
        case "c": return KeyMapping(keyCode: 0x08, needsShift: false)
        case "C": return KeyMapping(keyCode: 0x08, needsShift: true)
        case "d": return KeyMapping(keyCode: 0x02, needsShift: false)
        case "D": return KeyMapping(keyCode: 0x02, needsShift: true)
        case "e": return KeyMapping(keyCode: 0x0E, needsShift: false)
        case "E": return KeyMapping(keyCode: 0x0E, needsShift: true)
        case "f": return KeyMapping(keyCode: 0x03, needsShift: false)
        case "F": return KeyMapping(keyCode: 0x03, needsShift: true)
        case "g": return KeyMapping(keyCode: 0x05, needsShift: false)
        case "G": return KeyMapping(keyCode: 0x05, needsShift: true)
        case "h": return KeyMapping(keyCode: 0x04, needsShift: false)
        case "H": return KeyMapping(keyCode: 0x04, needsShift: true)
        case "i": return KeyMapping(keyCode: 0x22, needsShift: false)
        case "I": return KeyMapping(keyCode: 0x22, needsShift: true)
        case "j": return KeyMapping(keyCode: 0x26, needsShift: false)
        case "J": return KeyMapping(keyCode: 0x26, needsShift: true)
        case "k": return KeyMapping(keyCode: 0x28, needsShift: false)
        case "K": return KeyMapping(keyCode: 0x28, needsShift: true)
        case "l": return KeyMapping(keyCode: 0x25, needsShift: false)
        case "L": return KeyMapping(keyCode: 0x25, needsShift: true)
        case "m": return KeyMapping(keyCode: 0x2E, needsShift: false)
        case "M": return KeyMapping(keyCode: 0x2E, needsShift: true)
        case "n": return KeyMapping(keyCode: 0x2D, needsShift: false)
        case "N": return KeyMapping(keyCode: 0x2D, needsShift: true)
        case "o": return KeyMapping(keyCode: 0x1F, needsShift: false)
        case "O": return KeyMapping(keyCode: 0x1F, needsShift: true)
        case "p": return KeyMapping(keyCode: 0x23, needsShift: false)
        case "P": return KeyMapping(keyCode: 0x23, needsShift: true)
        case "q": return KeyMapping(keyCode: 0x0C, needsShift: false)
        case "Q": return KeyMapping(keyCode: 0x0C, needsShift: true)
        case "r": return KeyMapping(keyCode: 0x0F, needsShift: false)
        case "R": return KeyMapping(keyCode: 0x0F, needsShift: true)
        case "s": return KeyMapping(keyCode: 0x01, needsShift: false)
        case "S": return KeyMapping(keyCode: 0x01, needsShift: true)
        case "t": return KeyMapping(keyCode: 0x11, needsShift: false)
        case "T": return KeyMapping(keyCode: 0x11, needsShift: true)
        case "u": return KeyMapping(keyCode: 0x20, needsShift: false)
        case "U": return KeyMapping(keyCode: 0x20, needsShift: true)
        case "v": return KeyMapping(keyCode: 0x09, needsShift: false)
        case "V": return KeyMapping(keyCode: 0x09, needsShift: true)
        case "w": return KeyMapping(keyCode: 0x0D, needsShift: false)
        case "W": return KeyMapping(keyCode: 0x0D, needsShift: true)
        case "x": return KeyMapping(keyCode: 0x07, needsShift: false)
        case "X": return KeyMapping(keyCode: 0x07, needsShift: true)
        case "y": return KeyMapping(keyCode: 0x10, needsShift: false)
        case "Y": return KeyMapping(keyCode: 0x10, needsShift: true)
        case "z": return KeyMapping(keyCode: 0x06, needsShift: false)
        case "Z": return KeyMapping(keyCode: 0x06, needsShift: true)

        case "1": return KeyMapping(keyCode: 0x12, needsShift: false)
        case "!": return KeyMapping(keyCode: 0x12, needsShift: true)
        case "2": return KeyMapping(keyCode: 0x13, needsShift: false)
        case "@": return KeyMapping(keyCode: 0x13, needsShift: true)
        case "3": return KeyMapping(keyCode: 0x14, needsShift: false)
        case "#": return KeyMapping(keyCode: 0x14, needsShift: true)
        case "4": return KeyMapping(keyCode: 0x15, needsShift: false)
        case "$": return KeyMapping(keyCode: 0x15, needsShift: true)
        case "5": return KeyMapping(keyCode: 0x17, needsShift: false)
        case "%": return KeyMapping(keyCode: 0x17, needsShift: true)
        case "6": return KeyMapping(keyCode: 0x16, needsShift: false)
        case "^": return KeyMapping(keyCode: 0x16, needsShift: true)
        case "7": return KeyMapping(keyCode: 0x1A, needsShift: false)
        case "&": return KeyMapping(keyCode: 0x1A, needsShift: true)
        case "8": return KeyMapping(keyCode: 0x1C, needsShift: false)
        case "*": return KeyMapping(keyCode: 0x1C, needsShift: true)
        case "9": return KeyMapping(keyCode: 0x19, needsShift: false)
        case "(": return KeyMapping(keyCode: 0x19, needsShift: true)
        case "0": return KeyMapping(keyCode: 0x1D, needsShift: false)
        case ")": return KeyMapping(keyCode: 0x1D, needsShift: true)

        case " ": return KeyMapping(keyCode: 0x31, needsShift: false)
        case "-": return KeyMapping(keyCode: 0x1B, needsShift: false)
        case "_": return KeyMapping(keyCode: 0x1B, needsShift: true)
        case "=": return KeyMapping(keyCode: 0x18, needsShift: false)
        case "+": return KeyMapping(keyCode: 0x18, needsShift: true)
        case "[": return KeyMapping(keyCode: 0x21, needsShift: false)
        case "{": return KeyMapping(keyCode: 0x21, needsShift: true)
        case "]": return KeyMapping(keyCode: 0x1E, needsShift: false)
        case "}": return KeyMapping(keyCode: 0x1E, needsShift: true)
        case "\\": return KeyMapping(keyCode: 0x2A, needsShift: false)
        case "|": return KeyMapping(keyCode: 0x2A, needsShift: true)
        case ";": return KeyMapping(keyCode: 0x29, needsShift: false)
        case ":": return KeyMapping(keyCode: 0x29, needsShift: true)
        case "'": return KeyMapping(keyCode: 0x27, needsShift: false)
        case "\"": return KeyMapping(keyCode: 0x27, needsShift: true)
        case ",": return KeyMapping(keyCode: 0x2B, needsShift: false)
        case "<": return KeyMapping(keyCode: 0x2B, needsShift: true)
        case ".": return KeyMapping(keyCode: 0x2F, needsShift: false)
        case ">": return KeyMapping(keyCode: 0x2F, needsShift: true)
        case "/": return KeyMapping(keyCode: 0x2C, needsShift: false)
        case "?": return KeyMapping(keyCode: 0x2C, needsShift: true)
        case "`": return KeyMapping(keyCode: 0x32, needsShift: false)
        case "~": return KeyMapping(keyCode: 0x32, needsShift: true)

        default: return nil
        }
    }
}
