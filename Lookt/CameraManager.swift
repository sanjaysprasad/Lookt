import AVFoundation
import CoreImage
import Combine

/// Wraps the built-in camera and streams frames as CIImage via a publisher.
/// Everything here is local — no network, no cloud upload, frames never
/// leave the process.
final class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let outputQueue = DispatchQueue(label: "camera.frame.queue")
    let framePublisher = PassthroughSubject<CIImage, Never>()

    private var isRunning = false

    /// Exposed so SwiftUI can render a live preview via CameraPreviewView.
    var captureSession: AVCaptureSession { session }

    func requestAccessAndStart(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.configureAndStart() }
                    completion(granted)
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
        guard isRunning else { return }
        session.stopRunning()
        isRunning = false
    }

    /// Opts this app out of Center Stage / Portrait / Studio Light / Reactions —
    /// macOS's built-in camera video-effects pipeline. These are applied at
    /// the system level and can interfere with raw frame delivery for apps
    /// doing their own face analysis (this matches the "Portrait.framework
    /// lighting.vfx" errors in Console — that's the effects pipeline trying
    /// to load and failing, not a crash in our code, but best avoided
    /// entirely since we don't want stylized frames anyway).
    private func disableSystemVideoEffects() {
        // Only Center Stage is actually app-controllable on macOS.
        // Portrait/Studio Light/Reactions exist as system-wide user
        // settings (Control Center) but aren't exposed for apps to
        // override on macOS — attempting to compiles as an error, unlike
        // iOS where the full set is available.
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
