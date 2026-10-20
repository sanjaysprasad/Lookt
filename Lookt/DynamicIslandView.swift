import SwiftUI
import AppKit

/// Apple-style Dynamic Island engineered specifically for MacBooks with a physical camera notch (M2/M3/M4):
/// - Organically pours downwards and expands outwards directly from the physical notch.
/// - Fluid spring morphing physics (expanding out of notch, retracting back in).
/// - High-tech Electric Blue & Cyan biometric colorway (lock spring -> checkmark with dual sapphire shockwaves).
/// - Prismatic Liquid Glass specular bevel and ambient blue glow.
struct DynamicIslandView: View {
    let state: ScanState
    var subtitle: String = ""
    var isNotchStyle: Bool = true
    var onDismissRequested: (() -> Void)? = nil

    @State private var isExpanded = false
    @State private var rotation: Double = 0
    @State private var laserOffset: CGFloat = -16
    @State private var shakeOffset: CGFloat = 0
    @State private var successStage: Int = 0 // 1: lock open spring, 2: blue checkmark
    @State private var lockScale: CGFloat = 0.8
    @State private var checkmarkScale: CGFloat = 0.4
    @State private var rippleScale1: CGFloat = 0.8
    @State private var rippleOpacity1: Double = 0.95
    @State private var rippleScale2: CGFloat = 0.6
    @State private var rippleOpacity2: Double = 0.85
    @State private var isSearchingPulse = false

    // Physical MacBook notch dimensions (dynamically detected)
    private var notchWidth: CGFloat {
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
                let w = right.minX - left.maxX
                if w > 50 { return w }
            }
        }
        return 179.0
    }

    private var notchHeight: CGFloat {
        if let screen = NSScreen.main ?? NSScreen.screens.first, screen.safeAreaInsets.top > 0 {
            return screen.safeAreaInsets.top
        }
        return 32.0
    }

    private var targetWidth: CGFloat {
        if !isExpanded {
            return isNotchStyle ? notchWidth : 180
        }
        return state == .success ? 315 : 295
    }

    private var targetHeight: CGFloat {
        if !isExpanded {
            return isNotchStyle ? notchHeight : 34
        }
        return state == .success ? 68 : 64
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Content container
                HStack(spacing: 14) {
                    // Left: Biometric Glyph / Morphing Shackle-to-Checkmark in Apple Electric Blue
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.85))
                            .frame(width: 44, height: 44)

                        // Continuous radar scanning ring (Apple Electric Blue & Cyan)
                        if state == .scanning {
                            Circle()
                                .trim(from: 0.1, to: 0.45)
                                .stroke(
                                    AngularGradient(
                                        gradient: Gradient(colors: [
                                            .clear,
                                            Color(red: 0.0, green: 0.85, blue: 1.0),
                                            Color(red: 0.0, green: 0.45, blue: 1.0),
                                            .clear
                                        ]),
                                        center: .center
                                    ),
                                    style: StrokeStyle(lineWidth: 2.8, lineCap: .round)
                                )
                                .frame(width: 42, height: 42)
                                .rotationEffect(.degrees(rotation))
                        }

                        // Sapphire & Electric Blue shockwave ripples on unlock
                        if state == .success {
                            Circle()
                                .stroke(Color(red: 0.0, green: 0.55, blue: 1.0), lineWidth: 2.2)
                                .frame(width: 42, height: 42)
                                .scaleEffect(rippleScale1)
                                .opacity(rippleOpacity1)

                            Circle()
                                .stroke(Color(red: 0.2, green: 0.8, blue: 1.0), lineWidth: 1.6)
                                .frame(width: 42, height: 42)
                                .scaleEffect(rippleScale2)
                                .opacity(rippleOpacity2)
                        }

                        Group {
                            switch state {
                            case .idle:
                                Image(systemName: "faceid")
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundColor(Color(red: 0.4, green: 0.75, blue: 1.0))

                            case .scanning:
                                ZStack {
                                    Image(systemName: "faceid")
                                        .font(.system(size: 24, weight: .light))
                                        .foregroundColor(Color(red: 0.0, green: 0.8, blue: 1.0))
                                        .scaleEffect(isSearchingPulse ? 1.05 : 0.96)

                                    // Electric Blue laser sweep line across Face ID
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    .clear,
                                                    Color(red: 0.0, green: 0.85, blue: 1.0),
                                                    .clear
                                                ],
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
                                        // Stage 1: Shackle pops open in Apple Electric Blue
                                        Image(systemName: "lock.open.fill")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundColor(Color(red: 0.05, green: 0.55, blue: 1.0))
                                            .scaleEffect(lockScale)
                                            .transition(.scale.combined(with: .opacity))
                                    } else {
                                        // Stage 2: Crisp Apple checkmark in Apple Electric Blue
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(Color(red: 0.05, green: 0.55, blue: 1.0))
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

                    // Right: Typography (Apple Electric Blue colorway)
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
                .padding(.top, isNotchStyle ? (notchHeight > 0 ? 6 : 0) : 0)
                .opacity(isExpanded ? 1.0 : 0.0)
            }
            .frame(width: targetWidth, height: targetHeight)
            .background(
                islandBackground
            )
            .offset(x: shakeOffset)
            .animation(.spring(response: 0.42, dampingFraction: 0.68), value: isExpanded)
            .animation(.spring(response: 0.36, dampingFraction: 0.65), value: state)

            Spacer()
        }
        .frame(width: 340, height: 95, alignment: .top)
        .onAppear {
            triggerAppearAnimation()
        }
        .onChange(of: state) {
            triggerAppearAnimation()
        }
    }

    @ViewBuilder
    private var islandBackground: some View {
        if isNotchStyle {
            // Emerges directly out of the physical notch: top flush with screen bezel, bottom corners smooth
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 22,
                bottomTrailingRadius: 22,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(Color.black.opacity(0.96))
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 22,
                    bottomTrailingRadius: 22,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .fill(.ultraThinMaterial)
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 22,
                    bottomTrailingRadius: 22,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.20), location: 0.0),
                            .init(color: Color(red: 0.0, green: 0.55, blue: 1.0).opacity(0.55), location: 0.4),
                            .init(color: Color.white.opacity(0.12), location: 0.8),
                            .init(color: Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.4), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
            )
            .shadow(
                color: Color(red: 0.0, green: 0.45, blue: 1.0).opacity(state == .success ? 0.45 : 0.28),
                radius: state == .success ? 20 : 14,
                x: 0,
                y: 8
            )
        } else {
            // Continuous floating capsule (for in-app live test preview)
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.94))
                .background(
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.35), location: 0.0),
                                    .init(color: Color(red: 0.0, green: 0.55, blue: 1.0).opacity(0.6), location: 0.4),
                                    .init(color: Color.white.opacity(0.12), location: 0.8),
                                    .init(color: Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.45), location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
                .shadow(
                    color: Color(red: 0.0, green: 0.45, blue: 1.0).opacity(state == .success ? 0.45 : 0.28),
                    radius: state == .success ? 18 : 12,
                    x: 0,
                    y: 6
                )
        }
    }

    private var subtitleColor: Color {
        switch state {
        case .idle:
            return .white.opacity(0.65)
        case .scanning:
            return subtitle.contains("Looking") ? Color(red: 0.4, green: 0.85, blue: 1.0) : .white.opacity(0.85)
        case .success:
            return Color(red: 0.4, green: 0.8, blue: 1.0)
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
        // Stage 1: Shackle pops open in Apple Electric Blue
        successStage = 1
        lockScale = 0.5
        withAnimation(.spring(response: 0.28, dampingFraction: 0.48)) {
            lockScale = 1.2
        }

        // Stage 2: Morphs into bold Apple checkmark with Electric Blue shockwaves
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) {
                self.successStage = 2
                self.checkmarkScale = 1.2
            }
        }

        // Shockwave Ripple 1 (Electric Blue)
        rippleScale1 = 0.8
        rippleOpacity1 = 0.95
        withAnimation(.easeOut(duration: 0.65)) {
            rippleScale1 = 1.45
            rippleOpacity1 = 0.0
        }

        // Shockwave Ripple 2 (Ice Blue)
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
