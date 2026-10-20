import Foundation

/// Represents a distinct enrolled face condition (e.g. Normal, With Glasses, Low Light).
/// Having multiple profiles significantly improves recognition accuracy across different
/// environments and appearances without degrading security.
enum ProfileStyle: String, Codable, CaseIterable, Identifiable {
    case defaultFace = "Default"
    case glasses = "With Glasses"
    case headwear = "Hat / Headwear"
    case lowLight = "Low Light / Night"
    case alternative = "Alternative Look"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .defaultFace: return "person.crop.circle"
        case .glasses: return "eyeglasses"
        case .headwear: return "crown"
        case .lowLight: return "moon.stars"
        case .alternative: return "sparkles"
        }
    }

    var description: String {
        switch self {
        case .defaultFace: return "Standard daytime profile without accessories"
        case .glasses: return "Wear your regular reading or sun glasses"
        case .headwear: return "Wear a cap, beanie, or hair covering"
        case .lowLight: return "Captured under dim room lighting"
        case .alternative: return "Alternative hairstyle, facial hair, or expression"
        }
    }
}

/// A stored face profile containing a user-assigned label, style, and
/// the computed landmark reference embeddings.
struct FaceProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var style: ProfileStyle
    let dateEnrolled: Date
    var embeddings: [FaceEmbedding]

    init(id: UUID = UUID(), name: String, style: ProfileStyle = .defaultFace, dateEnrolled: Date = Date(), embeddings: [FaceEmbedding]) {
        self.id = id
        self.name = name
        self.style = style
        self.dateEnrolled = dateEnrolled
        self.embeddings = embeddings
    }

    /// Profiles using MobileFaceNet 512-dimensional ArcFace neural embeddings.
    var isNeural: Bool {
        guard let length = embeddings.first?.count else { return false }
        return length == 512
    }
}
