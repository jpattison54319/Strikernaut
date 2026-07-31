import SwiftUI

struct RelicDropCore: View {
    let relic: EndlessRelic
    let stage: RelicDropRevealStage

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            relic.rarity.color.opacity(stage == .revealed ? 0.58 : 0.12),
                            GoalRushTheme.ink.opacity(0.04),
                        ],
                        center: .center,
                        startRadius: 12,
                        endRadius: 110
                    )
                )
                .blur(radius: stage == .impact ? 12 : 2)

            mysteryCore
                .opacity(stage == .revealed ? 0 : 1)

            RelicMedallionView(relic: relic)
                .padding(14)
                .opacity(stage == .revealed ? 1 : 0)
        }
        .scaleEffect(coreScale)
        .rotation3DEffect(
            .degrees(coreRotation),
            axis: (x: 0.35, y: 1, z: 0.12),
            perspective: 0.65
        )
        .shadow(
            color: relic.rarity.color.opacity(stage == .revealed ? 0.90 : 0.28),
            radius: stage == .revealed ? 28 : 10
        )
        .accessibilityHidden(true)
    }

    private var mysteryCore: some View {
        ZStack {
            Image("RelicMedallion")
                .resizable()
                .scaledToFit()
                .saturation(0)
                .brightness(-0.48)
                .padding(14)

            Circle()
                .fill(GoalRushTheme.ink.opacity(0.92))
                .frame(width: 88, height: 88)
                .overlay {
                    Circle()
                        .stroke(GoalRushTheme.cyan.opacity(0.76), lineWidth: 3)
                }

            Image(systemName: "questionmark")
                .font(.system(size: 38, weight: .black))
                .foregroundStyle(GoalRushTheme.cyan)
                .shadow(color: GoalRushTheme.cyan, radius: 8)
        }
    }

    private var coreScale: CGFloat {
        switch stage {
        case .incoming: 0.56
        case .impact: 0.82
        case .revealed: 1
        }
    }

    private var coreRotation: Double {
        switch stage {
        case .incoming: -24
        case .impact: 540
        case .revealed: 720
        }
    }
}
