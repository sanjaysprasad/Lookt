import SwiftUI
import AppKit
import Combine

/// Displays a sleek floating Face ID capsule right beneath the top menu bar / notch,
/// mimicking the iPhone Dynamic Island Face ID unlock prompt.
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
            .sink { [weak self] _ in self?.show(state: .success, autoHideAfter: 1.2) }
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
            let scanView = FaceIDScanView(state: state, size: 96)
            let hosting = NSHostingController(rootView: scanView)
            hostingController = hosting

            let p = NSPanel(contentViewController: hosting)
            p.styleMask = [.nonactivatingPanel, .titled, .fullSizeContentView]
            p.titleVisibility = .hidden
            p.titlebarAppearsTransparent = true
            p.isFloatingPanel = true
            p.level = .floating
            p.backgroundColor = .clear
            p.isOpaque = false
            p.hasShadow = false // FaceIDScanView handles its own glowing shadow
            p.setContentSize(NSSize(width: 130, height: 130))
            p.isMovableByWindowBackground = false
            panel = p
        } else {
            hostingController?.rootView = FaceIDScanView(state: state, size: 96)
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
        let y = screenFrame.maxY - panel.frame.height - 40
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
