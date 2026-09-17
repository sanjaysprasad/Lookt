import Combine
import CoreImage
import Vision

/// Coordinates a single Face ID attempt while the screen is locked:
/// max brightness → watch camera → require liveness AND embedding match
/// across several frames → on success, surface the unlock affordance.
///
/// Deliberately does NOT auto-type the login password (see the note in
/// KeychainStore.saveLoginPasswordReference()). What it does instead:
/// once matched + live, it wakes the display and focuses the password
/// field, so Touch ID / password entry remain the actual unlock
/// mechanism — this reduces "face recognition bug = account takeover"
/// risk while still saving the user the walk-up-and-notice step.
/// If you want full auto-fill later, that's a deliberate, isolated
/// decision to make once the matching pipeline is proven reliable.
final class FaceAuthController {
    private let camera = CameraManager()
    private let embedder = VisionFaceEmbedder()
    private let liveness = LivenessDetector()
    private let brightness = BrightnessController()

    private var cancellable: AnyCancellable?
    private var consecutiveMatches = 0
    private let requiredConsecutiveMatches = 3
    private let matchThreshold: Float = 0.88    // cosine similarity cutoff — tune during testing
    private var timeoutWorkItem: DispatchWorkItem?

    func beginAuthAttempt() {
        guard KeychainStore.hasEnrollment() else { return } // nothing enrolled, nothing to do
        consecutiveMatches = 0
        liveness.reset()
        brightness.maxOutBrightness()
        NotificationCenter.default.post(name: .looktScanStarted, object: nil)

        camera.requestAccessAndStart { [weak self] granted in
            guard granted, let self = self else { return }
            self.subscribe()
            self.armTimeout()
        }
    }

    func cancelAuthAttempt() {
        cancellable?.cancel()
        timeoutWorkItem?.cancel()
        camera.stop()
        brightness.restore()
        NotificationCenter.default.post(name: .looktScanEnded, object: nil)
    }

    private func subscribe() {
        let reference = KeychainStore.loadEmbeddings()
        guard !reference.isEmpty else { return }

        cancellable = camera.framePublisher
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .compactMap { [weak self] frame in self?.embedder.embed(frame) }
            .sink { [weak self] result in
                self?.processFrame(embedding: result.embedding,
                                    landmarks: result.landmarks,
                                    reference: reference)
            }
    }

    private func processFrame(embedding: FaceEmbedding, landmarks: VNFaceLandmarks2D?, reference: [FaceEmbedding]) {
        guard !embedding.isEmpty else { consecutiveMatches = 0; return }

        // Liveness must pass on this stream before a match even counts.
        var isLive = false
        if let landmarks = landmarks {
            isLive = liveness.ingest(landmarks)
        }

        let bestScore = reference.map { cosineSimilarity($0, embedding) }.max() ?? -1

        if isLive && bestScore >= matchThreshold {
            consecutiveMatches += 1
        } else {
            consecutiveMatches = 0
        }

        if consecutiveMatches >= requiredConsecutiveMatches {
            DispatchQueue.main.async { [weak self] in
                self?.onAuthSuccess()
            }
        }
    }

    private func armTimeout() {
        let workItem = DispatchWorkItem { [weak self] in
            self?.cancelAuthAttempt() // give up gracefully, user falls back to Touch ID/password
        }
        timeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: workItem)
    }

    private func onAuthSuccess() {
        cancelAuthAttempt()
        // Wake display + focus password field via Accessibility APIs here.
        // Left as an integration point — depends on whether you're
        // targeting the login window or just screensaver/lock overlay.
        NotificationCenter.default.post(name: .looktMatched, object: nil)
    }
}

extension Notification.Name {
    static let looktMatched = Notification.Name("LooktMatched")
    static let looktScanStarted = Notification.Name("LooktScanStarted")
    static let looktScanEnded = Notification.Name("LooktScanEnded") // timeout/cancel without a match
}
