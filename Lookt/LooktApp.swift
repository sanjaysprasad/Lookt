import SwiftUI
import AppKit

@main
struct LooktApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Placeholder scene — SwiftUI's App protocol requires at least one.
        // The actual window is managed manually by AppDelegate below.
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindow: NSWindow?
    let lockWatcher = LockScreenWatcher()
    let authController = FaceAuthController()
    let overlay = OverlayPanelController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Regular app (has a Dock icon / Applications entry) rather than a
        // menu-bar-only accessory — per your call, no persistent menu bar
        // icon. Clicking the app icon opens the window; the rest of the
        // time it just runs quietly watching for lock/unlock in the
        // background.
        NSApp.setActivationPolicy(.regular)
        showMainWindow()
        overlay.start()

        // Wire the lock-screen watcher to trigger auth attempts. This runs
        // regardless of whether the window is open — it's the persistent
        // background behavior — and fires every time the screen locks,
        // not just once.
        lockWatcher.onScreenLocked = { [weak self] in
            self?.authController.beginAuthAttempt()
        }
        lockWatcher.onScreenUnlocked = { [weak self] in
            self?.authController.cancelAuthAttempt()
        }
        lockWatcher.start()
    }

    /// Called when the app is already running and the user clicks its icon
    /// again in the Dock/Applications/Launchpad — re-shows the window
    /// instead of doing nothing (the default behavior for a windowless app).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if mainWindow == nil {
            let hosting = NSHostingController(rootView: EnrollmentView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "Lookt"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 400, height: 420))
            window.center()
            window.isReleasedWhenClosed = false
            mainWindow = window
        }
        mainWindow?.makeKeyAndOrderFront(nil)
    }
}
