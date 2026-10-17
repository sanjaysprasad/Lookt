import Combine
import CoreImage
import Vision
import Foundation

/// Coordinates a Face ID unlock attempt when the screen is locked:
/// 1. Checks if Lookt is enabled by user
/// 2. Engages camera and evaluates liveness (blink + natural micro-motion)
/// 3. Compares incoming embeddings against all enrolled face profiles
/// 4. Once verified across consecutive frames, invokes MacUnlocker (Auto-Unlock or Wake Only)
final class FaceAuthController {
    private let camera = CameraManager()
    private let embedder = VisionFaceEmbedder()
    private let liveness = LivenessDetector()
    private let brightness = BrightnessController()

    private var cancellable: AnyCancellable?
    private var consecutiveMatches = 0
    private let requiredConsecutiveMatches = 3
    private let matchThreshold: Float = 0.88
    private var timeoutWorkItem: DispatchWorkItem?

    func beginAuthAttempt() {
        // Master toggle check
        let isEnabled = UserDefaults.standard.object(forKey: "isLooktEnabled") as? Bool ?? true
        guard isEnabled else { return }

        // Must have at least one enrolled profile
        guard KeychainStore.hasProfiles() else { return }
        guard cancellable == nil else { return } // already in progress

        consecutiveMatches = 0
        liveness.reset()

        let boostBrightness = UserDefaults.standard.object(forKey: "boostBrightness") as? Bool ?? true
        if boostBrightness {
            brightness.maxOutBrightness()
        }

        NotificationCenter.default.post(name: .looktScanStarted, object: nil)

        camera.requestAccessAndStart { [weak self] granted in
            guard granted, let self = self else { return }
            self.subscribe()
            self.armTimeout()
        }
    }

    func cancelAuthAttempt(notifyScanEnded: Bool = true) {
        cancellable?.cancel()
        cancellable = nil
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        camera.stop()
        brightness.restore()
        if notifyScanEnded {
            NotificationCenter.default.post(name: .looktScanEnded, object: nil)
        }
    }

    private func subscribe() {
        let referenceEmbeddings = KeychainStore.allEmbeddings()
        guard !referenceEmbeddings.isEmpty else { return }

        cancellable = camera.framePublisher
            .receive(on: DispatchQueue.global(qos: .userInitiated))
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
            self?.cancelAuthAttempt(notifyScanEnded: true)
        }
        timeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: workItem)
    }

    private func onAuthSuccess() {
        // Stop camera and restore brightness without posting looktScanEnded
        cancelAuthAttempt(notifyScanEnded: false)

        // Show the success animation over the lock screen
        NotificationCenter.default.post(name: .looktMatched, object: nil)

        // Read user's chosen unlock mode
        let modeRaw = UserDefaults.standard.string(forKey: "unlockMode") ?? UnlockMode.autoUnlock.rawValue
        let mode = UnlockMode(rawValue: modeRaw) ?? .autoUnlock

        // Perform unlock via MacUnlocker
        MacUnlocker.shared.performUnlock(mode: mode)
    }
}

extension Notification.Name {
    static let looktMatched = Notification.Name("LooktMatched")
    static let looktScanStarted = Notification.Name("LooktScanStarted")
    static let looktScanEnded = Notification.Name("LooktScanEnded")
}
