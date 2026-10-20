import SwiftUI
import AppKit

enum ScanState: Equatable {
    case idle, scanning, success, failed
}

/// An authentic Apple-style Face ID scan view modeled after iOS / Dynamic Island:
/// - Breathing Face ID icon with sweeping laser line and rotating accent ring
/// - Morphing spring checkmark on success with a gentle audio chime
/// - Characteristic horizontal head-shake animation on failure
struct FaceIDScanView: View {
    let state: ScanState
    var size: CGFloat = 110

    @State private var rotation: Double = 0
    @State private var laserOffset: CGFloat = -35
    @State private var shakeOffset: CGFloat = 0
    @State private var successStage: Int = 0
    @State private var lockScale: CGFloat = 0.6
    @State private var checkmarkScale: CGFloat = 0.4
    @State private var rippleScale: CGFloat = 0.8
    @State private var rippleOpacity: Double = 0.8

    var body: some View {
        ZStack {
            // Ambient frosted glass backing
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                        .stroke(ringColor.opacity(0.35), lineWidth: 1.5)
                )
                .shadow(color: ringColor.opacity(state == .success ? 0.45 : 0.15), radius: 12, x: 0, y: 4)

            // Expanding ripple wave on success
            if state == .success {
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                    .stroke(Color.green, lineWidth: 2)
                    .scaleEffect(rippleScale)
                    .opacity(rippleOpacity)
            }

            // Rotating accent scanning ring
            if state == .scanning {
                Circle()
                    .trim(from: 0.1, to: 0.4)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.clear, .cyan, .blue, .clear]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: size * 0.78, height: size * 0.78)
                    .rotationEffect(.degrees(rotation))
            }

            // Laser sweep line moving vertically across the face during scan
            if state == .scanning {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .cyan.opacity(0.8), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size * 0.6, height: 2)
                    .offset(y: laserOffset)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            }

            // Morphing Glyph (faceid -> checkmark / xmark)
            Group {
                switch state {
                case .idle, .scanning:
                    Image(systemName: "faceid")
                        .font(.system(size: size * 0.42, weight: .light))
                        .foregroundColor(ringColor)
                        .scaleEffect(state == .scanning ? 1.05 : 1.0)
                        .animation(
                            state == .scanning
                                ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                                : .default,
                            value: state
                        )

                case .success:
                    ZStack {
                        if successStage == 1 {
                            Image(systemName: "lock.open.fill")
                                .font(.system(size: size * 0.40, weight: .semibold))
                                .foregroundColor(.green)
                                .scaleEffect(lockScale)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: size * 0.44, weight: .semibold))
                                .foregroundColor(.green)
                                .scaleEffect(checkmarkScale)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                case .failed:
                    Image(systemName: "faceid")
                        .font(.system(size: size * 0.42, weight: .light))
                        .foregroundColor(.red)
                }
            }
            .offset(x: shakeOffset)
        }
        .frame(width: size, height: size)
        .onAppear {
            updateAnimationState()
        }
        .onChange(of: state) {
            updateAnimationState()
        }
    }

    private var ringColor: Color {
        switch state {
        case .idle: return .secondary
        case .scanning: return .cyan
        case .success: return .green
        case .failed: return .red
        }
    }

    private func updateAnimationState() {
        switch state {
        case .scanning:
            startScanningAnimations()
        case .success:
            triggerSuccessAnimation()
        case .failed:
            triggerFailureAnimation()
        case .idle:
            rotation = 0
            shakeOffset = 0
        }
    }

    private func startScanningAnimations() {
        rotation = 0
        withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
            rotation = 360
        }

        laserOffset = -size * 0.32
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            laserOffset = size * 0.32
        }
    }

    private func triggerSuccessAnimation() {
        successStage = 1
        lockScale = 0.6
        withAnimation(.spring(response: 0.28, dampingFraction: 0.48)) {
            lockScale = 1.15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) {
                self.successStage = 2
                self.checkmarkScale = 1.15
            }
        }

        rippleScale = 0.85
        rippleOpacity = 0.9
        withAnimation(.easeOut(duration: 0.7)) {
            rippleScale = 1.35
            rippleOpacity = 0.0
        }

        // Play subtle unlock chime
        NSSound(named: "Glass")?.play()
    }

    private func triggerFailureAnimation() {
        shakeOffset = 0
        // Natural multi-step head shake
        withAnimation(.easeInOut(duration: 0.07)) { shakeOffset = -10 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
            withAnimation(.easeInOut(duration: 0.07)) { self.shakeOffset = 10 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.easeInOut(duration: 0.07)) { self.shakeOffset = -6 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.21) {
            withAnimation(.easeInOut(duration: 0.07)) { self.shakeOffset = 6 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            withAnimation(.easeInOut(duration: 0.07)) { self.shakeOffset = 0 }
        }
    }
}
