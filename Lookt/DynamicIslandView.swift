import SwiftUI
import AppKit

// MARK: - MacBook Hardware Notch Shape with Concave Ears
/// A custom shape that flawlessly connects to the MacBook screen bezel,
/// featuring concave top "ear" curves that flare out into the top screen edge
/// and convex bottom rounded corners that drop down from the camera housing.
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    init(topCornerRadius: CGFloat = 10, bottomCornerRadius: CGFloat = 18) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // 1. Start at top-left flush against the top screen bezel
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // 2. Top-left "ear": concave curve flaring down into the notch body
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY + topCornerRadius),
            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY)
        )

        // 3. Left vertical edge
        path.addLine(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY - bottomCornerRadius))

        // 4. Bottom-left corner: convex curve
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCornerRadius + bottomCornerRadius, y: rect.maxY),
            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY)
        )

        // 5. Bottom horizontal edge
        path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius - bottomCornerRadius, y: rect.maxY))

        // 6. Bottom-right corner: convex curve
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY - bottomCornerRadius),
            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY)
        )

        // 7. Right vertical edge
        path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY + topCornerRadius))

        // 8. Top-right "ear": concave curve flaring back out into the top screen bezel
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY)
        )

        // 9. Close along top bezel
        path.closeSubpath()

        return path
    }
}

// MARK: - Apple Face ID Checkmark Shape
struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.14, y: rect.minY + rect.height * 0.52))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.40, y: rect.minY + rect.height * 0.80))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.86, y: rect.minY + rect.height * 0.24))
        return path
    }
}

// MARK: - Dynamic Island View
struct DynamicIslandView: View {
    let state: ScanState
    var subtitle: String = ""
    var isNotchStyle: Bool = true

    @State private var isExpanded = false
    @State private var radarRotation: Double = 0
    @State private var laserOffset: CGFloat = -14
    @State private var shakeOffset: CGFloat = 0
    @State private var checkmarkProgress: CGFloat = 0.0
    @State private var isCircleMorph = false
    @State private var glyphScale: CGFloat = 1.0
    @State private var rippleScale1: CGFloat = 0.8
    @State private var rippleOpacity1: Double = 0.95
    @State private var rippleScale2: CGFloat = 0.6
    @State private var rippleOpacity2: Double = 0.85

    // Apple Official System Green Palette
    private let appleGreen = Color(red: 0.20, green: 0.78, blue: 0.35)       // #34C759
    private let appleGreenLight = Color(red: 0.35, green: 0.88, blue: 0.48)  // #30D158
    private let appleGreenDark = Color(red: 0.14, green: 0.60, blue: 0.26)

    // Hardware notch metrics
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
            return isNotchStyle ? (notchWidth + 20) : 180
        }
        return state == .success ? 324 : 304
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
                // Content Layer
                HStack(spacing: 14) {
                    // Left: Biometric Glyph / Animated Checkmark
                    ZStack {
                        // Outer Morphing Ring (Squircle -> Circle on success)
                        RoundedRectangle(
                            cornerRadius: isCircleMorph ? 22 : 12,
                            style: .continuous
                        )
                        .stroke(
                            state == .success ? appleGreen : (state == .scanning ? appleGreen.opacity(0.4) : Color.white.opacity(0.15)),
                            lineWidth: 2
                        )
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: isCircleMorph ? 22 : 12, style: .continuous)
                                .fill(Color.black.opacity(0.9))
                        )

                        // Continuous radar sweep arc when scanning (Apple Green)
                        if state == .scanning {
                            Circle()
                                .trim(from: 0.05, to: 0.40)
                                .stroke(
                                    AngularGradient(
                                        gradient: Gradient(colors: [.clear, appleGreenLight, appleGreen, .clear]),
                                        center: .center
                                    ),
                                    style: StrokeStyle(lineWidth: 2.6, lineCap: .round)
                                )
                                .frame(width: 44, height: 44)
                                .rotationEffect(.degrees(radarRotation))
                        }

                        // Success shockwaves in Apple Green
                        if state == .success {
                            Circle()
                                .stroke(appleGreenLight, lineWidth: 2)
                                .frame(width: 44, height: 44)
                                .scaleEffect(rippleScale1)
                                .opacity(rippleOpacity1)

                            Circle()
                                .stroke(appleGreen, lineWidth: 1.5)
                                .frame(width: 44, height: 44)
                                .scaleEffect(rippleScale2)
                                .opacity(rippleOpacity2)
                        }

                        // Center Icon
                        Group {
                            switch state {
                            case .idle:
                                Image(systemName: "faceid")
                                    .font(.system(size: 22, weight: .light))
                                    .foregroundColor(.white.opacity(0.75))

                            case .scanning:
                                ZStack {
                                    Image(systemName: "faceid")
                                        .font(.system(size: 22, weight: .light))
                                        .foregroundColor(appleGreenLight)

                                    // Sweeping laser line
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.clear, appleGreenLight.opacity(0.9), .clear],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: 26, height: 2)
                                        .offset(y: laserOffset)
                                }
                                .clipShape(Circle().inset(by: 3))

                            case .success:
                                CheckmarkShape()
                                    .trim(from: 0, to: checkmarkProgress)
                                    .stroke(
                                        appleGreenLight,
                                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                                    )
                                    .frame(width: 24, height: 24)
                                    .offset(y: 1)

                            case .failed:
                                Image(systemName: "faceid")
                                    .font(.system(size: 22, weight: .light))
                                    .foregroundColor(.red)
                            }
                        }
                        .scaleEffect(glyphScale)
                    }
                    .frame(width: 46, height: 46)

                    // Right: Typography
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
                .padding(.horizontal, 18)
                .padding(.top, isNotchStyle ? (notchHeight > 0 ? 8 : 0) : 0)
                .opacity(isExpanded ? 1.0 : 0.0)
            }
            .frame(width: targetWidth, height: targetHeight)
            .background(islandBackground)
            .offset(x: shakeOffset)
            .animation(.spring(response: 0.38, dampingFraction: 0.72, blendDuration: 0), value: isExpanded)
            .animation(.spring(response: 0.34, dampingFraction: 0.68), value: state)

            Spacer()
        }
        .frame(width: 380, height: 100, alignment: .top)
        .onAppear {
            triggerAppear()
        }
        .onChange(of: state) {
            triggerAppear()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RetractDynamicIsland"))) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.80)) {
                isExpanded = false
            }
        }
    }

    @ViewBuilder
    private var islandBackground: some View {
        if isNotchStyle {
            // Concave ears + convex corners matching MacBook screen bezel
            NotchShape(
                topCornerRadius: isExpanded ? 10 : 4,
                bottomCornerRadius: isExpanded ? 18 : 8
            )
            .fill(Color.black.opacity(0.97))
            .background(
                NotchShape(
                    topCornerRadius: isExpanded ? 10 : 4,
                    bottomCornerRadius: isExpanded ? 18 : 8
                )
                .fill(.ultraThinMaterial)
            )
            .overlay(
                NotchShape(
                    topCornerRadius: isExpanded ? 10 : 4,
                    bottomCornerRadius: isExpanded ? 18 : 8
                )
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.25), location: 0.0),
                            .init(color: state == .success ? appleGreen.opacity(0.7) : Color.white.opacity(0.08), location: 0.4),
                            .init(color: state == .success ? appleGreenLight.opacity(0.5) : Color.white.opacity(0.15), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
            )
            .shadow(
                color: state == .success ? appleGreen.opacity(0.4) : Color.black.opacity(0.35),
                radius: state == .success ? 18 : 12,
                x: 0,
                y: 8
            )
        } else {
            // Floating pill for in-app preview
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.95))
                .background(
                    Capsule(style: .continuous).fill(.ultraThinMaterial)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.3), location: 0.0),
                                    .init(color: state == .success ? appleGreen.opacity(0.7) : Color.white.opacity(0.1), location: 0.4),
                                    .init(color: state == .success ? appleGreenLight.opacity(0.5) : Color.white.opacity(0.18), location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
                .shadow(
                    color: state == .success ? appleGreen.opacity(0.38) : Color.black.opacity(0.25),
                    radius: state == .success ? 16 : 10,
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
            return subtitle.contains("Looking") ? appleGreenLight : .white.opacity(0.85)
        case .success:
            return appleGreenLight
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

    private func triggerAppear() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72, blendDuration: 0)) {
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
            radarRotation = 0
            shakeOffset = 0
            checkmarkProgress = 0
            isCircleMorph = false
        }
    }

    private func startScanning() {
        isCircleMorph = false
        checkmarkProgress = 0
        radarRotation = 0
        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
            radarRotation = 360
        }

        laserOffset = -14
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            laserOffset = 14
        }
    }

    private func triggerSuccess() {
        // Step 1: Morph squircle into circle
        withAnimation(.easeInOut(duration: 0.28)) {
            isCircleMorph = true
        }

        // Step 2: Draw the authentic Apple checkmark path from left to right
        checkmarkProgress = 0.0
        withAnimation(.easeInOut(duration: 0.32).delay(0.12)) {
            checkmarkProgress = 1.0
        }

        // Step 3: Subtle spring scale bump on completion
        withAnimation(.spring(response: 0.26, dampingFraction: 0.50).delay(0.36)) {
            glyphScale = 1.15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.65)) {
                self.glyphScale = 1.0
            }
        }

        // Shockwave Ripples in Apple Green
        rippleScale1 = 0.8
        rippleOpacity1 = 0.95
        withAnimation(.easeOut(duration: 0.60)) {
            rippleScale1 = 1.48
            rippleOpacity1 = 0.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            self.rippleScale2 = 0.7
            self.rippleOpacity2 = 0.85
            withAnimation(.easeOut(duration: 0.60)) {
                self.rippleScale2 = 1.38
                self.rippleOpacity2 = 0.0
            }
        }

        // Audio chime
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
