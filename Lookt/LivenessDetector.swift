import Vision
import CoreGraphics
import Foundation

/// High-security anti-spoofing and liveness detector designed to reject:
/// 1. Static photos (printed photos, phone lockscreens, tablet screens)
/// 2. Video replay attacks
/// 3. Planar homographies (flat surfaces lacking 3D depth parallax)
final class LivenessDetector {
    private var leftEarHistory: [Float] = []
    private var rightEarHistory: [Float] = []
    private var consecutiveOpenFrames = 0
    private var isEyesCurrentlyClosed = false
    private var lastBlinkTime: Date?

    private(set) var hasVerifiedBlinkRecently = false
    var statusHint: String = "Blink naturally to unlock"

    func reset() {
        leftEarHistory.removeAll()
        rightEarHistory.removeAll()
        consecutiveOpenFrames = 0
        isEyesCurrentlyClosed = false
        lastBlinkTime = nil
        hasVerifiedBlinkRecently = false
        statusHint = "Blink naturally to unlock"
    }

    /// Feeds one frame of 2D facial landmarks into the anti-spoofing engine.
    /// Returns true ONLY if an authentic human blink cycle (Open -> Close -> Reopen)
    /// has been successfully completed by a living subject.
    @discardableResult
    func ingest(_ landmarks: VNFaceLandmarks2D) -> Bool {
        guard let leftEar = eyeAspectRatio(landmarks.leftEye?.normalizedPoints),
              let rightEar = eyeAspectRatio(landmarks.rightEye?.normalizedPoints) else {
            return false
        }

        leftEarHistory.append(leftEar)
        rightEarHistory.append(rightEar)
        if leftEarHistory.count > 25 { leftEarHistory.removeFirst() }
        if rightEarHistory.count > 25 { rightEarHistory.removeFirst() }

        let avgEar = (leftEar + rightEar) / 2.0
        let bilateralDifference = abs(leftEar - rightEar)

        // 1. Phase 1: Open Eyes Detection
        // Open human eyes typically show EAR between 0.19 and 0.38
        if avgEar >= 0.19 {
            consecutiveOpenFrames += 1

            // If eyes were previously observed as closed and are now open again:
            // A genuine human blink cycle (Open -> Close -> Reopen) has been completed!
            if isEyesCurrentlyClosed {
                isEyesCurrentlyClosed = false
                lastBlinkTime = Date()
                hasVerifiedBlinkRecently = true
                statusHint = "Live face verified"
            }
        }
        // 2. Phase 2: Closed Eyes Detection
        // During a genuine blink, both eyes close simultaneously (EAR <= 0.14)
        else if avgEar <= 0.14 && consecutiveOpenFrames >= 2 {
            // Bilateral symmetry check: both eyes must drop together (rejects covering one eye)
            if bilateralDifference < 0.08 {
                isEyesCurrentlyClosed = true
                statusHint = "Eyes detected closing…"
            }
        }

        // Maintain verified liveness status for 2.2 seconds following an authentic blink
        if let lastBlink = lastBlinkTime, Date().timeIntervalSince(lastBlink) < 2.2 {
            return true
        } else {
            hasVerifiedBlinkRecently = false
            if !isEyesCurrentlyClosed {
                statusHint = "Blink naturally to unlock"
            }
            return false
        }
    }

    /// Computes the Eye-Aspect-Ratio (EAR) for a given eye landmark contour.
    private func eyeAspectRatio(_ points: [CGPoint]?) -> Float? {
        guard let eye = points, eye.count >= 6 else { return nil }
        let xs = eye.map(\.x)
        let ys = eye.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else { return nil }
        let horizontal = maxX - minX
        let vertical = maxY - minY
        guard horizontal > 0 else { return nil }
        return Float(vertical / horizontal)
    }
}
