import SwiftUI
import AppKit
import Combine

/// Shows a small floating Face ID-style scan animation once the screen is
/// interactive again after waking/unlocking begins.
///
/// IMPORTANT: this cannot and does not draw over the actual macOS lock
/// screen — Apple reserves that surface for system UI only, the same
/// restriction that suspends camera access while truly locked (see
/// FaceAuthController's comments). What this DOES do: as soon as the
/// screen wakes and hands control back to regular apps, if a scan is in
/// progress or just completed, a small borderless panel appears near the
/// top of the screen showing the animation — a visible confirmation that
/// runs alongside the real password/Touch ID prompt, not instead of it.
final class OverlayPanelController {
    private var panel: NSPanel?
    private var hostingController: NSHostingController<FaceIDScanView>?
    private var cancellables = Set<AnyCancellable>()
    private var hideWorkItem: DispatchWorkItem?

    func start() {
        NotificationCenter.default.publisher(for: .looktScanStarted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.show(state: .scanning) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .looktMatched)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.show(state: .success, autoHideAfter: 1.5) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .looktScanEnded)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.hide() }
            .store(in: &cancellables)
    }

    private func show(state: ScanState, autoHideAfter: TimeInterval? = nil) {
        dispatchPrecondition(condition: .onQueue(.main))
        hideWorkItem?.cancel()

        if panel == nil {
            let scanView = FaceIDScanView(state: state)
            let hosting = NSHostingController(rootView: scanView)
            hostingController = hosting

            let p = NSPanel(contentViewController: hosting)
            p.styleMask = [.nonactivatingPanel, .titled, .fullSizeContentView]
            p.titleVisibility = .hidden
            p.titlebarAppearsTransparent = true
            p.isFloatingPanel = true
            p.level = .floating
            p.backgroundColor = .clear
            p.hasShadow = true
            p.setContentSize(NSSize(width: 130, height: 130))
            p.isMovableByWindowBackground = false
            panel = p
        } else {
            hostingController?.rootView = FaceIDScanView(state: state)
        }

        positionNearTopCenter()
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

    private func positionNearTopCenter() {
        guard let panel = panel, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - panel.frame.width / 2
        let y = screenFrame.maxY - panel.frame.height - 80
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
