import Combine
import CoreImage
import Vision
import AppKit

/// Coordinates an authentication attempt on screen lock/wake:
/// Boosts brightness in low light, streams frames from the camera,
/// runs the deep neural embedding + anti-spoofing liveness check, and unlocks via MacUnlocker.
final class FaceAuthController {
    private let camera = CameraManager()
    private let embedder = VisionFaceEmbedder()
    private let liveness = LivenessDetector()
    private let brightness = BrightnessController()

    private var cancellable: AnyCancellable?
    private var timeoutWorkItem: DispatchWorkItem?
    private var consecutiveMatches = 0
    private let requiredConsecutiveMatches = 2
    // Strict biometric threshold for combined neural + anthropometric signature:
    // Same person: >= 0.78
    // Different person: <= 0.55
    private let matchThreshold: Float = 0.78
    private var isAuthenticating = false

    func beginAuthAttempt() {
        startAuthAttempt()
    }

    func startAuthAttempt() {
        guard !isAuthenticating else { return }

        // Check if Lookt is enabled by user
        let isEnabled = UserDefaults.standard.object(forKey: "isLooktEnabled") as? Bool ?? true
        guard isEnabled else { return }

        let profiles = KeychainStore.loadProfiles()
        let neuralProfiles = profiles.filter { ($0.embeddings.first?.count ?? 0) == 522 }

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

        // Temporarily boost brightness for low-light recognition if enabled
        let shouldBoost = UserDefaults.standard.object(forKey: "boostBrightness") as? Bool ?? true
        if shouldBoost {
            brightness.maxOutBrightness()
        }

        NotificationCenter.default.post(name: .looktScanStarted, object: nil)

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
        guard !embedding.isEmpty else { consecutiveMatches = 0; return }

        var isLive = false
        if let landmarks = landmarks {
            isLive = liveness.ingest(landmarks)
        }

        let bestScore = reference.map { cosineSimilarity($0, embedding) }.max() ?? -1

        // Strict biometric match AND genuine human blink verification required
        if isLive && bestScore >= matchThreshold {
            consecutiveMatches += 1
        } else {
            consecutiveMatches = 0
        }

        if consecutiveMatches >= requiredConsecutiveMatches {
            consecutiveMatches = 0
            cancellable?.cancel()
            cancellable = nil
            DispatchQueue.main.async { [weak self] in
                self?.onAuthSuccess()
            }
        }
    }

    private func armTimeout() {
        let workItem = DispatchWorkItem { [weak self] in
            self?.onAuthFailed(reason: "Use Touch ID or Password")
        }
        timeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: workItem)
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
}

extension Notification.Name {
    static let looktMatched = Notification.Name("LooktMatched")
    static let looktFailed = Notification.Name("LooktFailed")
    static let looktScanStarted = Notification.Name("LooktScanStarted")
    static let looktScanEnded = Notification.Name("LooktScanEnded")
}
