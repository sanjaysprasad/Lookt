import Foundation

/// Observes macOS screen lock/unlock events so we know when to
/// start/stop the camera-based auth attempt. Uses the standard
/// distributed notifications macOS posts for this — no private APIs.
final class LockScreenWatcher {
    var onScreenLocked: (() -> Void)?
    var onScreenUnlocked: (() -> Void)?

    private let dnc = DistributedNotificationCenter.default()

    func start() {
        dnc.addObserver(self,
                         selector: #selector(screenLocked),
                         name: Notification.Name("com.apple.screenIsLocked"),
                         object: nil)
        dnc.addObserver(self,
                         selector: #selector(screenUnlocked),
                         name: Notification.Name("com.apple.screenIsUnlocked"),
                         object: nil)
    }

    func stop() {
        dnc.removeObserver(self)
    }

    @objc private func screenLocked() {
        onScreenLocked?()
    }

    @objc private func screenUnlocked() {
        onScreenUnlocked?()
    }
}
