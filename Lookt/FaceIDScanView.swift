import SwiftUI

enum ScanState {
    case idle, scanning, success, failed
}

/// A circular scan animation modeled on the classic Face ID look: a
/// rotating dashed ring around a face-outline glyph, morphing into a
/// checkmark on success or an x on failure.
struct FaceIDScanView: View {
    let state: ScanState
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 6)

            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(rotation))
                .opacity(state == .scanning ? 1 : 0)

            Image(systemName: iconName)
                .font(.system(size: 46, weight: .medium))
                .foregroundColor(ringColor)
                .scaleEffect(state == .success ? 1.1 : 1.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: state)
        }
        .frame(width: 110, height: 110)
        .onAppear { startRotationIfNeeded() }
        .onChange(of: state) { _ in startRotationIfNeeded() }
    }

    private var iconName: String {
        switch state {
        case .idle, .scanning: return "faceid"
        case .success: return "checkmark"
        case .failed: return "xmark"
        }
    }

    private var ringColor: Color {
        switch state {
        case .idle: return .secondary
        case .scanning: return .accentColor
        case .success: return .green
        case .failed: return .red
        }
    }

    private func startRotationIfNeeded() {
        guard state == .scanning else { return }
        rotation = 0
        withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }
}
