import SwiftUI
import AppKit

// MARK: - Native macOS Visual Effect Vibrancy

/// True macOS native glass vibrancy blur bridging NSVisualEffectView into SwiftUI.
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - Apple Liquid Glass Card Modifier

struct LiquidGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 18
    var specularOpacity: Double = 0.38
    var shadowRadius: CGFloat = 16
    var isHovered: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        // Inner specular glass reflection gradient
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered ? 0.12 : 0.05),
                                Color.clear,
                                Color.black.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                // Prismatic Liquid Glass specular bevel stroke
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(specularOpacity), location: 0.0),
                                .init(color: Color.white.opacity(0.12), location: 0.35),
                                .init(color: Color.cyan.opacity(0.20), location: 0.65),
                                .init(color: Color.white.opacity(0.18), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(isHovered ? 0.22 : 0.14),
                radius: isHovered ? shadowRadius + 6 : shadowRadius,
                x: 0,
                y: isHovered ? 10 : 6
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isHovered)
    }
}

extension View {
    /// Applies Apple's signature Liquid Glass frosted material, prismatic rim speculars, and floating shadow.
    func liquidGlassCard(
        cornerRadius: CGFloat = 18,
        specularOpacity: Double = 0.38,
        shadowRadius: CGFloat = 16,
        isHovered: Bool = false
    ) -> some View {
        self.modifier(
            LiquidGlassCardModifier(
                cornerRadius: cornerRadius,
                specularOpacity: specularOpacity,
                shadowRadius: shadowRadius,
                isHovered: isHovered
            )
        )
    }
}

// MARK: - Liquid Glass Badge & Capsule

struct LiquidGlassPill<Content: View>: View {
    var content: Content
    var tintColor: Color = .accentColor

    init(tintColor: Color = .accentColor, @ViewBuilder content: () -> Content) {
        self.tintColor = tintColor
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(tintColor.opacity(0.16))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        tintColor.opacity(0.3),
                                        Color.white.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
    }
}
