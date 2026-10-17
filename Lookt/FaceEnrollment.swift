import Combine
import CoreImage
import AVFoundation

enum EnrollmentStep: Int, CaseIterable {
    case lookStraight, turnLeft, turnRight

    var instruction: String {
        switch self {
        case .lookStraight: return "Look straight at the camera"
        case .turnLeft: return "Slowly turn your head slightly left"
        case .turnRight: return "Slowly turn your head slightly right"
        }
    }

    var framesToCapture: Int { 3 }
}

/// Runs enrollment for a specific profile (e.g. Primary, Glasses, Low Light):
/// Captures multiple frames across angles, computes averaged reference vectors,
/// and saves the resulting FaceProfile into KeychainStore.
final class FaceEnrollmentController: ObservableObject {
    @Published var currentStep: EnrollmentStep = .lookStraight
    @Published var framesCapturedInStep = 0
    @Published var isComplete = false
    @Published var statusMessage = "Ready to enroll"

    var targetProfileName: String = "Primary Face"
    var targetProfileStyle: ProfileStyle = .defaultFace

    private let camera = CameraManager()
    private let embedder = VisionFaceEmbedder()
    private var cancellable: AnyCancellable?
    private var capturedThisStep: [FaceEmbedding] = []
    private var allEnrolledEmbeddings: [FaceEmbedding] = []

    private var isCapturingAllowed = false
    private var lastCaptureTime: Date?
    private let minIntervalBetweenCaptures: TimeInterval = 0.45
    private let getReadyDelay: TimeInterval = 1.2
    private var readyWorkItem: DispatchWorkItem?

    var previewSession: AVCaptureSession { camera.captureSession }

    init() {
        if KeychainStore.hasProfiles() {
            let count = KeychainStore.loadProfiles().count
            isComplete = true
            statusMessage = "\(count) face profile\(count == 1 ? "" : "s") registered."
        }
    }

    func startEnrollment(name: String, style: ProfileStyle) {
        self.targetProfileName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? style.rawValue : name
        self.targetProfileStyle = style
        reset()

        statusMessage = "Requesting camera access…"
        camera.requestAccessAndStart { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                self.statusMessage = "Camera access denied — enable it in System Settings > Privacy & Security > Camera."
                return
            }
            self.subscribeToFrames()
            self.beginCaptureForCurrentStep()
        }
    }

    func reset() {
        cancellable?.cancel()
        cancellable = nil
        readyWorkItem?.cancel()
        readyWorkItem = nil
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
            return
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
        cancellable = nil
        readyWorkItem?.cancel()
        readyWorkItem = nil

        let newProfile = FaceProfile(
            name: targetProfileName,
            style: targetProfileStyle,
            dateEnrolled: Date(),
            embeddings: allEnrolledEmbeddings
        )

        let saved = KeychainStore.addProfile(newProfile)
        if saved {
            statusMessage = "Profile '\(newProfile.name)' saved successfully!"
            isComplete = true
        } else {
            statusMessage = "Failed to save profile to Keychain. Please try again."
            isComplete = false
        }
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
