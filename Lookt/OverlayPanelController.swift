import SwiftUI
import AppKit
import Combine

/// Displays a sleek Dynamic Island expanding organically out of the MacBook notch
/// elevated above the lock screen and all desktop windows.
final class OverlayPanelController {
    static let shared = OverlayPanelController()

    private var panel: NSPanel?
    private var hostingController: NSHostingController<DynamicIslandView>?
    private var cancellables = Set<AnyCancellable>()
    private var hideWorkItem: DispatchWorkItem?
    private var isShowingSuccess = false

    init() {}

    func start() {
        NotificationCenter.default.publisher(for: .looktScanStarted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let self = self, !self.isShowingSuccess else { return }
                let sub = note.userInfo?["subtitle"] as? String ?? "Looking for face…"
                self.show(state: .scanning, subtitle: sub)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .looktFaceSearching)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let self = self, !self.isShowingSuccess else { return }
                let sub = note.userInfo?["subtitle"] as? String ?? "Looking for face…"
                self.show(state: .scanning, subtitle: sub)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .looktFaceDetected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let self = self, !self.isShowingSuccess else { return }
                let sub = note.userInfo?["subtitle"] as? String ?? "Face Detected • Blink to unlock"
                self.show(state: .scanning, subtitle: sub)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .looktMatched)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let self = self else { return }
                self.isShowingSuccess = true
                let sub = note.userInfo?["subtitle"] as? String ?? "Welcome back"
                self.show(state: .success, subtitle: sub, autoHideAfter: 2.2)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
                    self?.isShowingSuccess = false
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .looktWrongFace)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let self = self, !self.isShowingSuccess else { return }
                let sub = note.userInfo?["subtitle"] as? String ?? "Face Not Recognized"
                self.show(state: .failed, subtitle: sub)
                // After 1.2s of wrong face alert, return to continuous scanning
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                    guard let strongSelf = self, !strongSelf.isShowingSuccess else { return }
                    strongSelf.show(state: .scanning, subtitle: "Looking for face…")
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .looktFailed)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let self = self, !self.isShowingSuccess else { return }
                let sub = note.userInfo?["subtitle"] as? String ?? "Use Touch ID or Password"
                self.show(state: .failed, subtitle: sub, autoHideAfter: 2.5)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .looktScanEnded)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                // Let the victory unlock animation finish in full glory!
                if !self.isShowingSuccess {
                    self.hide()
                }
            }
            .store(in: &cancellables)

        // Pre-create panel so it is immediately ready when screen locks
        DispatchQueue.main.async { [weak self] in
            self?.ensurePanelCreated()
        }
    }

    /// Plays the full authentic Dynamic Island notch animation sequence on the screen.
    func testAnimationSequence() {
        dispatchPrecondition(condition: .onQueue(.main))
        isShowingSuccess = false
        hideWorkItem?.cancel()

        // 1. Drop down from notch: Scanning / Searching for face
        show(state: .scanning, subtitle: "Looking for face…")

        // 2. Face Detected
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self else { return }
            self.show(state: .scanning, subtitle: "Face Detected • Blink to unlock")
        }

        // 3. Apple Lock Shackle Spring -> Green Checkmark -> Chime -> Unlocked
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            guard let self = self else { return }
            self.isShowingSuccess = true
            self.show(state: .success, subtitle: "Welcome back", autoHideAfter: 2.2)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
                self?.isShowingSuccess = false
            }
        }
    }

    private func ensurePanelCreated() {
        guard panel == nil else { return }
        let initialView = DynamicIslandView(state: .idle, subtitle: "")
        let hosting = NSHostingController(rootView: initialView)
        hostingController = hosting

        let p = NSPanel(contentViewController: hosting)
        p.styleMask = [.nonactivatingPanel, .borderless]
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isFloatingPanel = true

        // Display above all desktop windows, full screen apps, and lock screen
        p.canBecomeVisibleWithoutLogin = true
        p.level = .screenSaver

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
        p.setContentSize(NSSize(width: 380, height: 100))
        panel = p
        positionAtNotch()
    }

    func show(state: ScanState, subtitle: String = "", autoHideAfter: TimeInterval? = nil) {
        dispatchPrecondition(condition: .onQueue(.main))
        hideWorkItem?.cancel()

        ensurePanelCreated()

        let islandView = DynamicIslandView(state: state, subtitle: subtitle)
        hostingController?.rootView = islandView

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
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let screenFrame = screen.frame
        let panelWidth = panel.frame.width
        let panelHeight = panel.frame.height

        // Center horizontally and anchor flush to the top bezel at the physical camera notch
        let x = screenFrame.midX - (panelWidth / 2.0)
        let y = screenFrame.maxY - panelHeight

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func hide() {
        dispatchPrecondition(condition: .onQueue(.main))
        hideWorkItem?.cancel()
        hideWorkItem = nil
        NotificationCenter.default.post(name: NSNotification.Name("RetractDynamicIsland"), object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { [weak self] in
            self?.panel?.orderOut(nil)
        }
    }
}
