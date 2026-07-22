import SwiftUI

private struct PulseGlow: ViewModifier {
    let active: Bool
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowing = false

    func body(content: Content) -> some View {
        content
            .shadow(color: active ? color.opacity(glowing ? 0.55 : 0.18) : .clear,
                    radius: glowing ? 16 : 7)
            .onAppear {
                guard active, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    glowing = true
                }
            }
    }
}

private struct Shimmer: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content.overlay {
            if active && !reduceMotion {
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.22), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: phase * geometry.size.width * 1.6)
                }
                .clipped()
                .allowsHitTesting(false)
                .onAppear {
                    withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
            }
        }
    }
}

extension View {
    func pulseGlow(_ active: Bool, color: Color = GoalRushTheme.gold) -> some View {
        modifier(PulseGlow(active: active, color: color))
    }

    func shimmer(active: Bool = true) -> some View {
        modifier(Shimmer(active: active))
    }
}
