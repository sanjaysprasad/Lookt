import AVFoundation
import CoreImage
import Combine

/// Wraps the built-in camera and streams frames as CIImage via a publisher.
/// Everything here is local — no network, no cloud upload, frames never
/// leave the process.
final class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let outputQueue = DispatchQueue(label: "camera.frame.queue")
    let framePublisher = PassthroughSubject<CIImage, Never>()

    private var isRunning = false

    /// Exposed so SwiftUI can render a live preview via CameraPreviewView.
    var captureSession: AVCaptureSession { session }

    func requestAccessAndStart(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sessionQueue.async { [weak self] in
                self?.configureAndStart()
                DispatchQueue.main.async {
                    completion(true)
                }
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.sessionQueue.async {
                        self?.configureAndStart()
                        DispatchQueue.main.async {
                            completion(true)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            }
        default:
            completion(false)
        }
    }

    private func configureAndStart() {
        guard !isRunning else { return }
        disableSystemVideoEffects()

        session.beginConfiguration()
        session.sessionPreset = .medium // 480p is plenty for face detection, saves CPU

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: outputQueue)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        session.commitConfiguration()
        session.startRunning()
        isRunning = true
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.isRunning else { return }
            self.session.stopRunning()
            self.isRunning = false
        }
    }

    /// Opts this app out of Center Stage / Portrait / Studio Light / Reactions —
    /// macOS's built-in camera video-effects pipeline. These are applied at
    /// the system level and can interfere with raw frame delivery for apps
    /// doing their own face analysis.
    private func disableSystemVideoEffects() {
        if #available(macOS 13.0, *) {
            AVCaptureDevice.centerStageControlMode = .app
            AVCaptureDevice.isCenterStageEnabled = false
        }
    }

    func captureOutput(_ output: AVCaptureOutput,
                        didOutput sampleBuffer: CMSampleBuffer,
                        from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        framePublisher.send(ciImage)
    }
}
