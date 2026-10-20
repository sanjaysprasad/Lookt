import SwiftUI
import AppKit

/// An authentic Apple-style Dynamic Island pill designed specifically for MacBooks:
/// - Flows and expands seamlessly out of the MacBook notch
/// - Authentic iPhone Face ID unlock animation (Lock shackle spring -> morph to Apple checkmark with emerald shockwave)
/// - High-tech radar sweep & scanning laser when searching for a face
/// - Spring physics for expansion, morphing, and contraction
struct DynamicIslandView: View {
    let state: ScanState
    var subtitle: String = ""

    @State private var isExpanded = false
    @State private var rotation: Double = 0
    @State private var laserOffset: CGFloat = -16
    @State private var shakeOffset: CGFloat = 0
    @State private var successStage: Int = 0 // 0: initial, 1: lock open spring, 2: green checkmark
    @State private var lockScale: CGFloat = 0.8
    @State private var checkmarkScale: CGFloat = 0.4
    @State private var rippleScale1: CGFloat = 0.8
    @State private var rippleOpacity1: Double = 0.9
    @State private var rippleScale2: CGFloat = 0.6
    @State private var rippleOpacity2: Double = 0.9
    @State private var isSearchingPulse = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Left: Authentic Face ID Glyph / Morphing Lock-to-Checkmark Icon
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 44, height: 44)

                    // Continuous radar scanning ring
                    if state == .scanning {
                        Circle()
                            .trim(from: 0.1, to: 0.45)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [.clear, .cyan, .blue, .clear]),
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 2.8, lineCap: .round)
                            )
                            .frame(width: 42, height: 42)
                            .rotationEffect(.degrees(rotation))
                    }

                    // Emerald shockwave ripples on unlock
                    if state == .success {
                        Circle()
                            .stroke(Color(red: 0.18, green: 0.86, blue: 0.38), lineWidth: 2)
                            .frame(width: 42, height: 42)
                            .scaleEffect(rippleScale1)
                            .opacity(rippleOpacity1)

                        Circle()
                            .stroke(Color(red: 0.25, green: 0.95, blue: 0.45), lineWidth: 1.5)
                            .frame(width: 42, height: 42)
                            .scaleEffect(rippleScale2)
                            .opacity(rippleOpacity2)
                    }

                    Group {
                        switch state {
                        case .idle:
                            Image(systemName: "faceid")
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(.white.opacity(0.75))

                        case .scanning:
                            ZStack {
                                Image(systemName: "faceid")
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundColor(.cyan)
                                    .scaleEffect(isSearchingPulse ? 1.05 : 0.96)

                                // Sweeping laser line across Face ID
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.clear, .cyan.opacity(0.85), .clear],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 28, height: 2)
                                    .offset(y: laserOffset)
                            }
                            .clipShape(Circle().inset(by: 3))

                        case .success:
                            ZStack {
                                if successStage == 1 {
                                    // Stage 1: Shackle pops open like iPhone Lock Screen
                                    Image(systemName: "lock.open.fill")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundColor(Color(red: 0.18, green: 0.86, blue: 0.38))
                                        .scaleEffect(lockScale)
                                        .transition(.scale.combined(with: .opacity))
                                } else {
                                    // Stage 2: Crisp Apple Face ID green checkmark
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(Color(red: 0.18, green: 0.86, blue: 0.38))
                                        .scaleEffect(checkmarkScale)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }

                        case .failed:
                            Image(systemName: "faceid")
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(.red)
                        }
                    }
                }
                .frame(width: 46, height: 46)

                // Right: Dynamic Island Typography
                VStack(alignment: .leading, spacing: 3) {
                    Text(titleText)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Text(subtitleText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(subtitleColor)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 16)
            .frame(
                width: isExpanded ? (state == .success ? 305 : 285) : 180,
                height: isExpanded ? (state == .success ? 66 : 64) : 34
            )
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(
                                state == .success
                                    ? AnyShapeStyle(Color(red: 0.18, green: 0.86, blue: 0.38).opacity(0.45))
                                    : AnyShapeStyle(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.24),
                                                Color.white.opacity(0.06),
                                                Color.white.opacity(0.14)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    ),
                                lineWidth: state == .success ? 1.5 : 1
                            )
                    )
                    .shadow(
                        color: state == .success ? Color.green.opacity(0.35) : Color.black.opacity(0.45),
                        radius: state == .success ? 16 : 14,
                        x: 0,
                        y: 6
                    )
            )
            .offset(y: isExpanded ? 0 : -32)
            .offset(x: shakeOffset)
            .animation(.spring(response: 0.40, dampingFraction: 0.65), value: isExpanded)
            .animation(.spring(response: 0.36, dampingFraction: 0.62), value: state)

            Spacer()
        }
        .frame(width: 320, height: 84)
        .onAppear {
            triggerAppearAnimation()
        }
        .onChange(of: state) {
            triggerAppearAnimation()
        }
    }

    private var subtitleColor: Color {
        switch state {
        case .idle:
            return .white.opacity(0.65)
        case .scanning:
            return subtitle.contains("Looking") ? .cyan.opacity(0.9) : .white.opacity(0.8)
        case .success:
            return Color(red: 0.35, green: 0.95, blue: 0.55)
        case .failed:
            return .red.opacity(0.9)
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
        case .scanning: return "Looking for face…"
        case .success: return "Welcome back"
        case .failed: return "Use Touch ID or Password"
        }
    }

    private func triggerAppearAnimation() {
        withAnimation(.spring(response: 0.40, dampingFraction: 0.68)) {
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
        withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
            rotation = 360
        }

        laserOffset = -16
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            laserOffset = 16
        }

        isSearchingPulse = false
        withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
            isSearchingPulse = true
        }
    }

    private func triggerSuccess() {
        // Stage 1: Lock shackle springs open (authentic Apple Lock Screen unlock)
        successStage = 1
        lockScale = 0.5
        withAnimation(.spring(response: 0.28, dampingFraction: 0.48)) {
            lockScale = 1.2
        }

        // Stage 2: Morphs into bold Apple checkmark with shockwaves
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) {
                self.successStage = 2
                self.checkmarkScale = 1.2
            }
        }

        // Shockwave Ripple 1
        rippleScale1 = 0.8
        rippleOpacity1 = 0.95
        withAnimation(.easeOut(duration: 0.65)) {
            rippleScale1 = 1.45
            rippleOpacity1 = 0.0
        }

        // Shockwave Ripple 2
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            self.rippleScale2 = 0.7
            self.rippleOpacity2 = 0.85
            withAnimation(.easeOut(duration: 0.65)) {
                self.rippleScale2 = 1.35
                self.rippleOpacity2 = 0.0
            }
        }

        // Apple signature unlock audio chime
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
