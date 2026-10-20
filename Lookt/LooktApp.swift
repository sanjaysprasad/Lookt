import SwiftUI
import AppKit

@main
struct LooktApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
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
        NSApp.setActivationPolicy(.regular)
        showMainWindow()
        overlay.start()

        lockWatcher.onScreenLocked = { [weak self] in
            self?.authController.beginAuthAttempt()
        }
        lockWatcher.onScreenUnlocked = { [weak self] in
            self?.authController.cancelAuthAttempt()
        }
        lockWatcher.start()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if mainWindow == nil {
            let hosting = NSHostingController(rootView: EnrollmentView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "Lookt — Face ID for Mac"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.setContentSize(NSSize(width: 580, height: 740))
            window.minSize = NSSize(width: 520, height: 620)
            window.center()
            window.isReleasedWhenClosed = false
            mainWindow = window
        }
        mainWindow?.makeKeyAndOrderFront(nil)
    }
}
