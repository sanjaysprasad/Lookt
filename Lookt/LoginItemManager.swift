import ServiceManagement
import Combine

/// Registers Lookt to launch automatically at login, using the modern
/// SMAppService API (macOS 13+) — no separate login-helper target needed,
/// this registers the main app bundle itself.
final class LoginItemManager: ObservableObject {
    @Published var isEnabled: Bool = false

    init() {
        refreshStatus()
    }

    func refreshStatus() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshStatus()
        } catch {
            print("Failed to \(enabled ? "register" : "unregister") login item: \(error)")
            refreshStatus() // reflect actual state even on failure
        }
    }
}
