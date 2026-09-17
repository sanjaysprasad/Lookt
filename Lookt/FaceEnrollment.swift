import Combine
import CoreImage
import AVFoundation

enum EnrollmentStep: Int, CaseIterable {
    case lookStraight, turnLeft, turnRight, dimLight

    var instruction: String {
        switch self {
        case .lookStraight: return "Look straight at the camera"
        case .turnLeft: return "Slowly turn your head slightly left"
        case .turnRight: return "Slowly turn your head slightly right"
        case .dimLight: return "Optional: repeat in a dimmer room for a stronger profile"
        }
    }

    var framesToCapture: Int { 3 } // 2-3 captures per condition, per your spec
}

/// Runs the one-time enrollment sequence: for each condition (straight,
/// left, right, optionally dim light), capture several frames, extract
/// embeddings, and average them into one reference vector per condition.
/// The whole set (not just one vector) is stored so matching can compare
/// against multiple reference points.
///
/// Captures are deliberately spaced out (not just "the next 3 camera
/// frames", which arrive a fraction of a second apart and look nearly
/// identical) — real spacing gives more natural variation, which makes
/// the resulting reference embeddings meaningfully better for matching.
final class FaceEnrollmentController: ObservableObject {
    @Published var currentStep: EnrollmentStep = .lookStraight
    @Published var framesCapturedInStep = 0
    @Published var isComplete = false
    @Published var statusMessage = "Ready to enroll"

    private let camera = CameraManager()
    private let embedder = VisionFaceEmbedder()
    private var cancellable: AnyCancellable?
    private var capturedThisStep: [FaceEmbedding] = []
    private var allEnrolledEmbeddings: [FaceEmbedding] = []

    private var isCapturingAllowed = false
    private var lastCaptureTime: Date?
    private let minIntervalBetweenCaptures: TimeInterval = 0.5
    private let getReadyDelay: TimeInterval = 1.5
    private var readyWorkItem: DispatchWorkItem?

    /// Exposed so the enrollment UI can show a live preview.
    var previewSession: AVCaptureSession { camera.captureSession }

    /// Resets everything so enrollment can be run again from scratch —
    /// used by the "Re-enroll" button.
    func reset() {
        cancellable?.cancel()
        readyWorkItem?.cancel()
        camera.stop()
        currentStep = .lookStraight
        framesCapturedInStep = 0
        isComplete = false
        statusMessage = "Ready to enroll"
        capturedThisStep.removeAll()
        allEnrolledEmbeddings.removeAll()
        isCapturingAllowed = false
        lastCaptureTime = nil
    }

    func start() {
        statusMessage = "Requesting camera access…"
        camera.requestAccessAndStart { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                self.statusMessage = "Camera access denied — enable it in System Settings > Privacy."
                return
            }
            self.subscribeToFrames()
            self.beginCaptureForCurrentStep()
        }
    }

    /// Shows a short "get ready" pause before capturing starts for a step,
    /// giving you time to actually get into position (especially for the
    /// turn-left/turn-right steps) rather than capturing whatever you
    /// happened to be doing the instant the step changed.
    private func beginCaptureForCurrentStep() {
        isCapturingAllowed = false
        lastCaptureTime = nil
        statusMessage = "Get ready: \(currentStep.instruction)"

        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.isCapturingAllowed = true
            self.statusMessage = self.currentStep.instruction
        }
        readyWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + getReadyDelay, execute: work)
    }

    private func subscribeToFrames() {
        cancellable = camera.framePublisher
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .compactMap { [weak self] frame in self?.embedder.embed(frame) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.handle(embedding: result.embedding)
            }
    }

    private func handle(embedding: FaceEmbedding) {
        guard isCapturingAllowed, !embedding.isEmpty, framesCapturedInStep < currentStep.framesToCapture else { return }

        let now = Date()
        if let last = lastCaptureTime, now.timeIntervalSince(last) < minIntervalBetweenCaptures {
            return // too soon after the last capture — skip this frame
        }
        lastCaptureTime = now

        capturedThisStep.append(embedding)
        framesCapturedInStep += 1
        statusMessage = "\(currentStep.instruction) (\(framesCapturedInStep)/\(currentStep.framesToCapture))"

        if framesCapturedInStep >= currentStep.framesToCapture {
            allEnrolledEmbeddings.append(average(capturedThisStep))
            advanceStep()
        }
    }

    private func advanceStep() {
        capturedThisStep.removeAll()
        framesCapturedInStep = 0

        let allSteps = EnrollmentStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep),
              currentIndex + 1 < allSteps.count else {
            finishEnrollment()
            return
        }
        currentStep = allSteps[currentIndex + 1]
        beginCaptureForCurrentStep()
    }

    private func finishEnrollment() {
        camera.stop()
        cancellable?.cancel()
        readyWorkItem?.cancel()
        let saved = KeychainStore.saveEmbeddings(allEnrolledEmbeddings)
        statusMessage = saved ? "Enrollment complete — \(allEnrolledEmbeddings.count) reference profiles saved."
                               : "Failed to save enrollment. Try again."
        isComplete = saved
    }

    private func average(_ embeddings: [FaceEmbedding]) -> FaceEmbedding {
        guard let length = embeddings.first?.count, length > 0 else { return [] }
        var sum = [Float](repeating: 0, count: length)
        for e in embeddings {
            for i in 0..<length { sum[i] += e[i] }
        }
        return sum.map { $0 / Float(embeddings.count) }
    }
}
