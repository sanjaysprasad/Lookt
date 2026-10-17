import SwiftUI
import AppKit

/// An authentic Apple-style Dynamic Island pill designed specifically for MacBooks:
/// - Seamlessly flows and expands out of the MacBook notch
/// - Smooth spring physics for expansion, morphing, and contraction
/// - High-contrast OLED black aesthetic with subtle specular border highlight
struct DynamicIslandView: View {
    let state: ScanState
    var subtitle: String = ""

    @State private var isExpanded = false
    @State private var rotation: Double = 0
    @State private var laserOffset: CGFloat = -18
    @State private var shakeOffset: CGFloat = 0
    @State private var checkmarkScale: CGFloat = 0.5
    @State private var rippleScale: CGFloat = 0.8
    @State private var rippleOpacity: Double = 0.8

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Left: Face ID Glyph / Animated Icon
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 44, height: 44)

                    if state == .scanning {
                        Circle()
                            .trim(from: 0.15, to: 0.45)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [.clear, .cyan, .blue, .clear]),
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(rotation))
                    }

                    if state == .success {
                        Circle()
                            .stroke(Color.green, lineWidth: 2)
                            .frame(width: 42, height: 42)
                            .scaleEffect(rippleScale)
                            .opacity(rippleOpacity)
                    }

                    Group {
                        switch state {
                        case .idle, .scanning:
                            Image(systemName: "faceid")
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(glyphColor)
                                .scaleEffect(state == .scanning ? 1.06 : 1.0)
                                .animation(
                                    state == .scanning
                                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                                        : .default,
                                    value: state
                                )

                        case .success:
                            Image(systemName: "checkmark")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.green)
                                .scaleEffect(checkmarkScale)

                        case .failed:
                            Image(systemName: "faceid")
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(.red)
                        }
                    }
                }
                .frame(width: 46, height: 46)

                // Right: Typography
                VStack(alignment: .leading, spacing: 3) {
                    Text(titleText)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Text(subtitleText)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(state == .failed ? .red.opacity(0.85) : .white.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 16)
            .frame(width: isExpanded ? 280 : 180, height: isExpanded ? 64 : 34)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.22),
                                        Color.white.opacity(0.06),
                                        Color.white.opacity(0.12)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.45), radius: 14, x: 0, y: 6)
            )
            .offset(x: shakeOffset)
            .animation(.spring(response: 0.38, dampingFraction: 0.65), value: isExpanded)

            Spacer()
        }
        .frame(width: 300, height: 80)
        .onAppear {
            triggerAppearAnimation()
        }
        .onChange(of: state) {
            triggerAppearAnimation()
        }
    }

    private var glyphColor: Color {
        switch state {
        case .idle: return .white.opacity(0.7)
        case .scanning: return .cyan
        case .success: return .green
        case .failed: return .red
        }
    }

    private var titleText: String {
        switch state {
        case .idle: return "Lookt"
        case .scanning: return "Lookt Face ID"
        case .success: return "Unlocked"
        case .failed: return "Not Recognized"
        }
    }

    private var subtitleText: String {
        if !subtitle.isEmpty { return subtitle }
        switch state {
        case .idle: return "Ready"
        case .scanning: return "Blink naturally to unlock"
        case .success: return "Welcome back"
        case .failed: return "Use Touch ID or Password"
        }
    }

    private func triggerAppearAnimation() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
            isExpanded = true
        }

        switch state {
        case .scanning:
            startScanning()
        case .success:
            triggerSuccess()
        case .failed:
            triggerFailure()
        case .idle:
            rotation = 0
            shakeOffset = 0
        }
    }

    private func startScanning() {
        rotation = 0
        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }

    private func triggerSuccess() {
        checkmarkScale = 0.4
        withAnimation(.spring(response: 0.35, dampingFraction: 0.52)) {
            checkmarkScale = 1.15
        }

        rippleScale = 0.8
        rippleOpacity = 0.95
        withAnimation(.easeOut(duration: 0.65)) {
            rippleScale = 1.35
            rippleOpacity = 0.0
        }

        NSSound(named: "Glass")?.play()
    }

    private func triggerFailure() {
        shakeOffset = 0
        withAnimation(.easeInOut(duration: 0.06)) { shakeOffset = -9 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(.easeInOut(duration: 0.06)) { self.shakeOffset = 9 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeInOut(duration: 0.06)) { self.shakeOffset = -5 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeInOut(duration: 0.06)) { self.shakeOffset = 5 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.easeInOut(duration: 0.06)) { self.shakeOffset = 0 }
        }
    }
}
