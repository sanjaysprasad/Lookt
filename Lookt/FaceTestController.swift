import Combine
import CoreImage
import Vision
import AVFoundation

/// Runs the exact same detection → liveness → matching pipeline as
/// FaceAuthController, but in the foreground with a live preview, so you
/// can verify accuracy and tune thresholds without it ever touching the
/// real macOS lock screen or typing anything. Purely a visual pass/fail
/// readout.
final class FaceTestController: ObservableObject {
    @Published var scanState: ScanState = .idle
    @Published var lastScore: Float = 0
    @Published var resultMessage: String = ""

    let camera = CameraManager()
    private let embedder = VisionFaceEmbedder()
    private let liveness = LivenessDetector()
    private var cancellable: AnyCancellable?
    private var consecutiveMatches = 0
    private let requiredConsecutiveMatches = 3
    private let matchThreshold: Float = 0.88
    private var timeoutWorkItem: DispatchWorkItem?
    private let timeoutSeconds: TimeInterval = 10
    private var isScanning = false

    var previewSession: AVCaptureSession { camera.captureSession }

    func start() {
        guard KeychainStore.hasEnrollment() else {
            scanState = .failed
            resultMessage = "No enrollment found — enroll first."
            return
        }
        consecutiveMatches = 0
        liveness.reset()
        isScanning = true
        scanState = .scanning
        resultMessage = "Scanning…"

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

    /// Stops the camera but leaves the last result (success/failed) visible
    /// rather than resetting to idle — so you can actually read the outcome.
    func stop() {
        isScanning = false
        cancellable?.cancel()
        cancellable = nil
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        camera.stop()
    }

    /// Fully resets so a fresh "Test My Face" click starts clean.
    func reset() {
        stop()
        scanState = .idle
        resultMessage = ""
        lastScore = 0
    }

    private func armTimeout() {
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.isScanning else { return }
            self.stop()
            self.scanState = .failed
            self.resultMessage = "No match found — try again with better lighting or a more direct angle."
        }
        timeoutWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds, execute: work)
    }

    private func subscribe() {
        let reference = KeychainStore.loadEmbeddings()
        guard !reference.isEmpty else { return }

        cancellable = camera.framePublisher
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .compactMap { [weak self] frame in self?.embedder.embed(frame) }
            .sink { [weak self] result in
                self?.process(embedding: result.embedding, landmarks: result.landmarks, reference: reference)
            }
    }

    private func process(embedding: FaceEmbedding, landmarks: VNFaceLandmarks2D?, reference: [FaceEmbedding]) {
        guard isScanning else { return } // ignore stray frames after timeout/success
        guard !embedding.isEmpty else { consecutiveMatches = 0; return }

        var isLive = false
        if let landmarks = landmarks {
            isLive = liveness.ingest(landmarks)
        }

        let bestScore = reference.map { cosineSimilarity($0, embedding) }.max() ?? -1

        DispatchQueue.main.async { [weak self] in
            self?.lastScore = bestScore
        }

        if isLive && bestScore >= matchThreshold {
            consecutiveMatches += 1
        } else {
            consecutiveMatches = 0
        }

        if consecutiveMatches >= requiredConsecutiveMatches {
            consecutiveMatches = 0
            isScanning = false
            cancellable?.cancel()
            cancellable = nil
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.scanState = .success
                self.resultMessage = "✅ Matched — that's you."
                self.stop()
            }
        }
    }
}
