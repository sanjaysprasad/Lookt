import Combine
import CoreImage
import Vision
import AppKit
import IOKit.pwr_mgt

/// Coordinates an authentication attempt on screen lock/wake:
/// Prevents display sleep, streams camera frames continuously for up to 40 seconds,
/// provides waiting/wrong face/correct face animations, and triggers MacUnlocker.
final class FaceAuthController {
    private let camera = CameraManager()
    private let embedder = VisionFaceEmbedder()
    private let liveness = LivenessDetector()
    private let brightness = BrightnessController()

    private var cancellable: AnyCancellable?
    private var timeoutWorkItem: DispatchWorkItem?
    private var consecutiveMatches = 0
    private let requiredConsecutiveMatches = 2
    // Strict threshold: same person is >= 0.72 (typically 0.76-0.90), strangers are <= 0.50
    private let matchThreshold: Float = 0.72
    private var isAuthenticating = false
    private var displaySleepAssertion: IOPMAssertionID = 0
    private var lastWrongFaceAlertTime: Date?

    func beginAuthAttempt() {
        startAuthAttempt()
    }

    func startAuthAttempt() {
        guard !isAuthenticating else { return }

        // Check if Lookt is enabled by user
        let isEnabled = UserDefaults.standard.object(forKey: "isLooktEnabled") as? Bool ?? true
        guard isEnabled else { return }

        let profiles = KeychainStore.loadProfiles()
        let neuralProfiles = profiles.filter(\.isNeural)

        // If only legacy profiles exist, inform user directly via Dynamic Island
        guard !neuralProfiles.isEmpty else {
            if !profiles.isEmpty {
                NotificationCenter.default.post(
                    name: .looktFailed,
                    object: nil,
                    userInfo: ["subtitle": "Re-enroll face in app"]
                )
            }
            return
        }

        let referenceEmbeddings = neuralProfiles.flatMap(\.embeddings)
        guard !referenceEmbeddings.isEmpty else { return }

        isAuthenticating = true
        consecutiveMatches = 0
        liveness.reset()
        lastWrongFaceAlertTime = nil

        // Prevent macOS lock screen from sleeping the display while Lookt is scanning
        acquireDisplaySleepAssertion()

        // Temporarily boost brightness for low-light recognition if enabled
        let shouldBoost = UserDefaults.standard.object(forKey: "boostBrightness") as? Bool ?? true
        if shouldBoost {
            brightness.maxOutBrightness()
        }

        NotificationCenter.default.post(
            name: .looktScanStarted,
            object: nil,
            userInfo: ["subtitle": "Looking for face…"]
        )

        camera.requestAccessAndStart { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                self.onAuthFailed(reason: "Camera access denied")
                return
            }
            self.subscribeToCamera(referenceEmbeddings: referenceEmbeddings)
            self.armTimeout()
        }
    }

    func cancelAuthAttempt(notifyScanEnded: Bool = true) {
        isAuthenticating = false
        cancellable?.cancel()
        cancellable = nil
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        camera.stop()
        brightness.restore()
        releaseDisplaySleepAssertion()
        consecutiveMatches = 0
        liveness.reset()

        if notifyScanEnded {
            NotificationCenter.default.post(name: .looktScanEnded, object: nil)
        }
    }

    private func subscribeToCamera(referenceEmbeddings: [FaceEmbedding]) {
        cancellable = camera.framePublisher
            .receive(on: DispatchQueue.global(qos: .userInteractive))
            .compactMap { [weak self] frame in self?.embedder.embed(frame) }
            .sink { [weak self] result in
                self?.processFrame(embedding: result.embedding,
                                    landmarks: result.landmarks,
                                    reference: referenceEmbeddings)
            }
    }

    private func processFrame(embedding: FaceEmbedding, landmarks: VNFaceLandmarks2D?, reference: [FaceEmbedding]) {
        guard isAuthenticating else { return }
        guard !embedding.isEmpty else {
            consecutiveMatches = 0
            return
        }

        var isLive = false
        if let landmarks = landmarks {
            isLive = liveness.ingest(landmarks)
        }

        let bestScore = reference.map { cosineSimilarity($0, embedding) }.max() ?? -1

        // Strict biometric match AND genuine living subject confirmed
        if isLive && bestScore >= matchThreshold {
            consecutiveMatches += 1
        } else {
            consecutiveMatches = 0

            // If a face is in view but unrecognized, trigger wrong face alert and KEEP SCANNING!
            if bestScore >= 0.0 && bestScore < matchThreshold {
                let now = Date()
                if lastWrongFaceAlertTime == nil || now.timeIntervalSince(lastWrongFaceAlertTime!) > 2.2 {
                    lastWrongFaceAlertTime = now
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: .looktWrongFace,
                            object: nil,
                            userInfo: ["subtitle": "Face Not Recognized • Looking…"]
                        )
                    }
                }
            }
        }

        if consecutiveMatches >= requiredConsecutiveMatches {
            consecutiveMatches = 0
            isAuthenticating = false
            cancellable?.cancel()
            cancellable = nil
            DispatchQueue.main.async { [weak self] in
                self?.onAuthSuccess()
            }
        }
    }

    private func armTimeout() {
        // Keep checking for up to 40 seconds before falling back to manual password/Touch ID
        let workItem = DispatchWorkItem { [weak self] in
            self?.onAuthFailed(reason: "Use Touch ID or Password")
        }
        timeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 40, execute: workItem)
    }

    private func onAuthSuccess() {
        cancelAuthAttempt(notifyScanEnded: false)
        NotificationCenter.default.post(name: .looktMatched, object: nil)

        let modeRaw = UserDefaults.standard.string(forKey: "unlockMode") ?? UnlockMode.autoUnlock.rawValue
        let mode = UnlockMode(rawValue: modeRaw) ?? .autoUnlock

        MacUnlocker.shared.performUnlock(mode: mode)
    }

    private func onAuthFailed(reason: String) {
        cancelAuthAttempt(notifyScanEnded: false)
        NotificationCenter.default.post(
            name: .looktFailed,
            object: nil,
            userInfo: ["subtitle": reason]
        )
    }

    private func acquireDisplaySleepAssertion() {
        guard displaySleepAssertion == 0 else { return }
        let reason = "Lookt Face ID Active Scan" as CFString
        IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &displaySleepAssertion
        )
    }

    private func releaseDisplaySleepAssertion() {
        guard displaySleepAssertion != 0 else { return }
        IOPMAssertionRelease(displaySleepAssertion)
        displaySleepAssertion = 0
    }
}

extension Notification.Name {
    static let looktMatched = Notification.Name("LooktMatched")
    static let looktWrongFace = Notification.Name("LooktWrongFace")
    static let looktFailed = Notification.Name("LooktFailed")
    static let looktScanStarted = Notification.Name("LooktScanStarted")
    static let looktScanEnded = Notification.Name("LooktScanEnded")
}
