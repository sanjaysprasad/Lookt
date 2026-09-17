import Vision
import CoreImage

/// A face embedding: a fixed-length numeric vector representing one face.
/// Two embeddings from the same person's face should have small cosine
/// distance; different people should have larger distance.
typealias FaceEmbedding = [Float]

protocol FaceEmbedding_Provider {
    /// Returns (embedding, faceBoundingBox, landmarks) for the primary
    /// (largest) face in the frame, or nil if no usable face is found.
    func embed(_ image: CIImage) -> (embedding: FaceEmbedding, box: CGRect, landmarks: VNFaceLandmarks2D?)?
}

/// IMPORTANT — read this before trusting this in production:
///
/// Apple's Vision framework gives you excellent face *detection* and
/// *landmarks* (VNDetectFaceRectanglesRequest, VNDetectFaceLandmarksRequest)
/// but does NOT expose a public face-*recognition* embedding API (the kind
/// Photos.app uses internally to group faces is private). So there are two
/// honest paths:
///
/// 1. Bundle your own small CoreML face-recognition model (a converted
///    FaceNet / ArcFace / MobileFaceNet .mlmodel, ~a few MB, plenty of open
///    source options run fine on the Neural Engine) and call it here per
///    frame. This is the path to real security — swap the body of embed()
///    to run that model instead of geometricEmbedding() below.
///
/// 2. Ship a weaker geometric-landmark embedding (relative distances/angles
///    between eyes, nose, mouth from VNFaceLandmarks2D) as a placeholder.
///    It works today with zero extra dependencies but is noticeably easier
///    to fool and less discriminative between similar-looking people —
///    treat it as a v1 stand-in, not the final security boundary.
///
/// This scaffold ships with (2) so it compiles and runs immediately.
/// Swapping in (1) is a contained change — only this file.
final class VisionFaceEmbedder: FaceEmbedding_Provider {

    func embed(_ image: CIImage) -> (embedding: FaceEmbedding, box: CGRect, landmarks: VNFaceLandmarks2D?)? {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let faces = request.results, !faces.isEmpty else {
            return nil
        }

        // Use the largest face in frame as "the primary user" — ignores
        // bystanders walking past in the background.
        let primary = faces.max(by: { $0.boundingBox.width * $0.boundingBox.height
                                     < $1.boundingBox.width * $1.boundingBox.height })!

        guard let landmarks = primary.landmarks else { return nil }
        let vector = geometricEmbedding(from: landmarks)
        return (vector, primary.boundingBox, landmarks)
    }

    /// Placeholder embedding — see doc comment above. Produces a normalized
    /// vector of pairwise distances between key landmark points, which is
    /// roughly scale/rotation tolerant but NOT a substitute for a trained
    /// recognition model.
    private func geometricEmbedding(from landmarks: VNFaceLandmarks2D) -> FaceEmbedding {
        var points: [CGPoint] = []
        for region in [landmarks.leftEye, landmarks.rightEye, landmarks.nose,
                        landmarks.outerLips, landmarks.leftEyebrow, landmarks.rightEyebrow] {
            if let region = region {
                points.append(contentsOf: region.normalizedPoints)
            }
        }
        guard points.count > 1 else { return [] }

        // All pairwise distances, flattened, then L2-normalized.
        var distances: [Float] = []
        for i in 0..<points.count {
            for j in (i + 1)..<points.count {
                let dx = Float(points[i].x - points[j].x)
                let dy = Float(points[i].y - points[j].y)
                distances.append((dx * dx + dy * dy).squareRoot())
            }
        }
        let norm = (distances.map { $0 * $0 }.reduce(0, +)).squareRoot()
        guard norm > 0 else { return distances }
        return distances.map { $0 / norm }
    }
}

func cosineSimilarity(_ a: FaceEmbedding, _ b: FaceEmbedding) -> Float {
    guard a.count == b.count, !a.isEmpty else { return -1 }
    var dot: Float = 0, normA: Float = 0, normB: Float = 0
    for i in 0..<a.count {
        dot += a[i] * b[i]
        normA += a[i] * a[i]
        normB += b[i] * b[i]
    }
    guard normA > 0, normB > 0 else { return -1 }
    return dot / (normA.squareRoot() * normB.squareRoot())
}
