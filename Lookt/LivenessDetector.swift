import Vision
import CoreGraphics

/// Combines two independent liveness signals so a static photo or a
/// paused video frame can't pass:
///   1. Blink detection — eye-aspect-ratio dips across frames
///   2. Micro-motion — natural jitter/parallax in landmark positions
///      between consecutive frames, which a flat photo held still won't
///      produce, and which a screen replay attack tends to render
///      differently (uniform motion vs. organic motion).
///
/// Requires BOTH signals within a short rolling window before declaring
/// "live" — single-signal liveness is easy to spoof with a video replay.
final class LivenessDetector {
    private var earHistory: [Float] = []      // eye-aspect-ratio samples
    private var motionHistory: [CGFloat] = [] // frame-to-frame landmark drift
    private var lastNosePoint: CGPoint?

    private let windowSize = 24 // ~1-1.5s of frames at typical capture rate
    private var blinkDetected = false
    private var motionDetected = false

    func reset() {
        earHistory.removeAll()
        motionHistory.removeAll()
        lastNosePoint = nil
        blinkDetected = false
        motionDetected = false
    }

    /// Feed one frame's landmarks in. Returns true once both liveness
    /// signals have fired within the current window.
    @discardableResult
    func ingest(_ landmarks: VNFaceLandmarks2D) -> Bool {
        if let ear = eyeAspectRatio(landmarks) {
            earHistory.append(ear)
            if earHistory.count > windowSize { earHistory.removeFirst() }
            checkForBlink()
        }

        if let nose = landmarks.nose?.normalizedPoints.first {
            if let last = lastNosePoint {
                let dx = nose.x - last.x, dy = nose.y - last.y
                let drift = (dx * dx + dy * dy).squareRoot()
                motionHistory.append(drift)
                if motionHistory.count > windowSize { motionHistory.removeFirst() }
                checkForMotion()
            }
            lastNosePoint = nose
        }

        return blinkDetected && motionDetected
    }

    private func eyeAspectRatio(_ landmarks: VNFaceLandmarks2D) -> Float? {
        guard let eye = landmarks.leftEye?.normalizedPoints, eye.count >= 6 else { return nil }
        let xs = eye.map(\.x)
        let ys = eye.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else { return nil }
        let horizontal = maxX - minX
        let vertical = maxY - minY
        guard horizontal > 0 else { return nil }
        return Float(vertical / horizontal)
    }

    private func checkForBlink() {
        guard earHistory.count >= 5 else { return }
        // A blink = a brief dip well below the recent baseline.
        let baseline = earHistory.dropLast(3).reduce(0, +) / Float(max(earHistory.count - 3, 1))
        let recentMin = earHistory.suffix(3).min() ?? baseline
        if baseline - recentMin > 0.05 {
            blinkDetected = true
        }
    }

    private func checkForMotion() {
        guard motionHistory.count >= 5 else { return }
        // Organic, non-zero, non-uniform drift — real faces never hold
        // perfectly still. Flags flat photos / paused video frames.
        let avg = motionHistory.reduce(0, +) / CGFloat(motionHistory.count)
        if avg > 0.0015 && avg < 0.05 { // present but not wildly erratic (waving photo around)
            motionDetected = true
        }
    }
}
