import SwiftUI

struct WorldEffectBadge: View {
    let rule: WorldRule
    let accentColor: Color
    let isActive: Bool
    let progress: Double

    var body: some View {
        HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
            Image(systemName: icon)
                .foregroundStyle(accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(GoalRushTheme.Typography.captionEmphasized)
                    .foregroundStyle(.white)
                ProgressView(value: min(1, max(0, progress)))
                    .tint(accentColor)
            }
        }
        .padding(.horizontal, GoalRushTheme.Metrics.standardSpacing)
        .padding(.vertical, GoalRushTheme.Metrics.compactSpacing)
        .frame(maxWidth: 210)
        .background(.black.opacity(0.72), in: ComicPanelShape(cut: 7))
        .overlay {
            ComicPanelShape(cut: 7)
                .stroke(accentColor.opacity(isActive ? 0.84 : 0.42), lineWidth: isActive ? 2.5 : 1.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(Int(progress * 100)) percent")
        .accessibilityIdentifier("world-effect")
    }

    private var title: String {
        switch rule {
        case .lunarCycle: isActive ? "ZERO-G ACTIVE" : "GRAVITY SHIFT"
        case .volatileCores: "VOLATILE CORE"
        }
    }

    private var icon: String {
        switch rule {
        case .lunarCycle: "moon.stars.fill"
        case .volatileCores: "flame.fill"
        }
    }
}
