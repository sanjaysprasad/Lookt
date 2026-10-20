import Combine
import CoreImage
import Vision
import AVFoundation

/// Runs the detection → liveness → matching pipeline in the foreground
/// with a live preview, matching against all enrolled face profiles and
/// reporting live scores, liveness status, and matched profile names.
final class FaceTestController: ObservableObject {
    @Published var scanState: ScanState = .idle
    @Published var lastScore: Float = 0
    @Published var resultMessage: String = ""
    @Published var matchedProfileInfo: String = ""

    let camera = CameraManager()
    private let embedder = VisionFaceEmbedder()
    private let liveness = LivenessDetector()
    private var cancellable: AnyCancellable?
    private var consecutiveMatches = 0
    private let requiredConsecutiveMatches = 2
    // MobileFaceNet ArcFace threshold:
    // Owner across angles: >= 0.58 (typically 0.68 - 0.88)
    // Strangers: <= 0.35
    private let matchThreshold: Float = 0.58
    private var timeoutWorkItem: DispatchWorkItem?
    private let timeoutSeconds: TimeInterval = 12
    private var isScanning = false

    var previewSession: AVCaptureSession { camera.captureSession }

    func start() {
        guard KeychainStore.hasProfiles() else {
            scanState = .failed
            resultMessage = "No profiles found — add a face profile first."
            return
        }
        consecutiveMatches = 0
        liveness.reset()
        isScanning = true
        scanState = .scanning
        resultMessage = "Scanning… Look at camera and blink"
        matchedProfileInfo = ""
        OverlayPanelController.shared.show(state: .scanning, subtitle: "Looking for face…")

        camera.requestAccessAndStart { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                self.isScanning = false
                self.scanState = .failed
                self.resultMessage = "Camera access denied."
                return
            }
            self.subscribe()
            self.armTimeout()
        }
    }

    func stop() {
        isScanning = false
        cancellable?.cancel()
        cancellable = nil
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        camera.stop()
        OverlayPanelController.shared.hide()
    }

    func reset() {
        stop()
        scanState = .idle
        resultMessage = ""
        matchedProfileInfo = ""
        lastScore = 0
    }

    private func armTimeout() {
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.isScanning else { return }
            self.stop()
            self.scanState = .failed
            self.resultMessage = "Authentication timed out — face did not match or blink not detected."
            OverlayPanelController.shared.show(state: .failed, subtitle: "Authentication timed out", autoHideAfter: 2.0)
        }
        timeoutWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds, execute: work)
    }

    private func subscribe() {
        let profiles = KeychainStore.loadProfiles()
        guard !profiles.isEmpty else { return }

        cancellable = camera.framePublisher
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .compactMap { [weak self] frame in self?.embedder.embed(frame) }
            .sink { [weak self] result in
                self?.process(embedding: result.embedding, landmarks: result.landmarks, profiles: profiles)
            }
    }

    private func process(embedding: FaceEmbedding, landmarks: VNFaceLandmarks2D?, profiles: [FaceProfile]) {
        guard isScanning else { return }
        guard !embedding.isEmpty else { consecutiveMatches = 0; return }

        var isLive = false
        if let landmarks = landmarks {
            isLive = liveness.ingest(landmarks)
        }

        var topScore: Float = -1
        var topName: String = ""

        for profile in profiles {
            let score = profile.embeddings.map { cosineSimilarity($0, embedding) }.max() ?? -1
            if score > topScore {
                topScore = score
                topName = "\(profile.name) • \(profile.style.rawValue)"
            }
        }

        let livenessHint = liveness.statusHint
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.lastScore = topScore
            if self.isScanning {
                if topScore < self.matchThreshold {
                    self.resultMessage = String(format: "Score: %.2f (Need >= %.2f) • Unrecognized Face", topScore, self.matchThreshold)
                } else if !isLive {
                    self.resultMessage = String(format: "Score: %.2f (Face recognized!) • %@", topScore, livenessHint)
                }
            }
        }

        if isLive && topScore >= matchThreshold {
            consecutiveMatches += 1
        } else {
            consecutiveMatches = 0
        }

        if consecutiveMatches >= requiredConsecutiveMatches {
            consecutiveMatches = 0
            isScanning = false
            cancellable?.cancel()
            cancellable = nil
            let matchedName = topName
            let finalScore = topScore
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.scanState = .success
                OverlayPanelController.shared.show(state: .success, subtitle: "Welcome back", autoHideAfter: 2.2)
                self.matchedProfileInfo = matchedName
                self.resultMessage = String(format: "✅ Matched: %@ (Score: %.2f)", matchedName, finalScore)
                self.stop()
            }
        }
    }
}
