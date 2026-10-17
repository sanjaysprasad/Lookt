import SwiftUI
import AppKit
import Combine

/// Displays a sleek Dynamic Island expanding organically out of the MacBook notch
/// elevated above the lock screen and all desktop windows.
final class OverlayPanelController {
    private var panel: NSPanel?
    private var hostingController: NSHostingController<DynamicIslandView>?
    private var cancellables = Set<AnyCancellable>()
    private var hideWorkItem: DispatchWorkItem?

    func start() {
        NotificationCenter.default.publisher(for: .looktScanStarted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.show(state: .scanning) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .looktMatched)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.show(state: .success, autoHideAfter: 2.2) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .looktScanEnded)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.hide() }
            .store(in: &cancellables)
    }

    private func show(state: ScanState, autoHideAfter: TimeInterval? = nil) {
        dispatchPrecondition(condition: .onQueue(.main))
        hideWorkItem?.cancel()

        let islandView = DynamicIslandView(state: state)

        if panel == nil {
            let hosting = NSHostingController(rootView: islandView)
            hostingController = hosting

            let p = NSPanel(contentViewController: hosting)
            p.styleMask = [.nonactivatingPanel, .borderless]
            p.titleVisibility = .hidden
            p.titlebarAppearsTransparent = true
            p.isFloatingPanel = true

            // Set window level to maximum level so it is visible over lockscreen / screensaver
            p.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 25)

            // Attach to all desktop spaces, fullscreen apps, and lock sessions
            p.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary,
                .stationary,
                .ignoresCycle
            ]

            p.backgroundColor = .clear
            p.isOpaque = false
            p.hasShadow = false
            p.hidesOnDeactivate = false
            p.setContentSize(NSSize(width: 320, height: 90))
            panel = p
        } else {
            hostingController?.rootView = islandView
        }

        positionAtNotch()
        panel?.orderFrontRegardless()

        if let delay = autoHideAfter {
            let work = DispatchWorkItem { [weak self] in self?.hide() }
            hideWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    private func hide() {
        dispatchPrecondition(condition: .onQueue(.main))
        hideWorkItem?.cancel()
        panel?.orderOut(nil)
    }

    private func positionAtNotch() {
        guard let panel = panel else { return }
        // Fall back to first screen if main screen is nil during lock / wake
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let screenFrame = screen.frame
        let x = screenFrame.midX - panel.frame.width / 2
        // Flush against the top bezel of the screen directly at the notch
        let y = screenFrame.maxY - panel.frame.height
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
