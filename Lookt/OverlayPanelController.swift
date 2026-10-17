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
            .sink { [weak self] note in
                let sub = note.userInfo?["subtitle"] as? String ?? ""
                self?.show(state: .scanning, subtitle: sub)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .looktMatched)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                let sub = note.userInfo?["subtitle"] as? String ?? ""
                self?.show(state: .success, subtitle: sub, autoHideAfter: 2.2)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .looktFailed)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                let sub = note.userInfo?["subtitle"] as? String ?? "Use Touch ID or Password"
                self?.show(state: .failed, subtitle: sub, autoHideAfter: 2.5)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .looktScanEnded)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.hide() }
            .store(in: &cancellables)
    }

    private func show(state: ScanState, subtitle: String = "", autoHideAfter: TimeInterval? = nil) {
        dispatchPrecondition(condition: .onQueue(.main))
        hideWorkItem?.cancel()

        let islandView = DynamicIslandView(state: state, subtitle: subtitle)

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

    private func positionAtNotch() {
        guard let panel = panel else { return }
        // When screen is locked, NSScreen.main can be nil -> fallback to NSScreen.screens.first
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let screenFrame = screen.frame
        let panelWidth = panel.frame.width
        let panelHeight = panel.frame.height

        // Center horizontally and anchor flush to the top bezel at the physical camera notch
        let x = screenFrame.midX - (panelWidth / 2.0)
        let y = screenFrame.maxY - panelHeight

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func hide() {
        dispatchPrecondition(condition: .onQueue(.main))
        hideWorkItem?.cancel()
        hideWorkItem = nil
        panel?.orderOut(nil)
    }
}
