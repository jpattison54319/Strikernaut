import SwiftUI

struct GameplayStatusBar: View {
    let world: WorldID
    let stamina: Double
    let maxStamina: Double
    let staminaTint: Color
    let tokens: Int
    let shieldCharges: Int
    let pause: () -> Void

    var body: some View {
        HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
            CompactStaminaBar(
                stamina: stamina,
                maxStamina: maxStamina,
                tint: staminaTint
            )
            .layoutPriority(1)

            Spacer(minLength: 2)

            HStack(spacing: 4) {
                TrainingTokenIcon(size: 18)
                Text(tokens.formatted())
                    .font(GoalRushTheme.Typography.subheadlineEmphasized)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .foregroundStyle(GoalRushTheme.gold)
            .animation(.snappy, value: tokens)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(tokens) Training Tokens")

            if shieldCharges > 0 {
                Label("\(shieldCharges)", systemImage: "shield.fill")
                    .font(GoalRushTheme.Typography.subheadlineEmphasized)
                    .foregroundStyle(GoalRushTheme.cyan)
                    .labelStyle(.titleAndIcon)
                    .accessibilityLabel("\(shieldCharges) shield blocks")
            }

            Button("Pause", systemImage: "pause.fill", action: pause)
                .labelStyle(.iconOnly)
                .font(GoalRushTheme.Typography.headline)
                .frame(
                    width: GoalRushTheme.Metrics.minimumTapTarget,
                    height: GoalRushTheme.Metrics.minimumTapTarget
                )
                .background(.white.opacity(0.09), in: .circle)
                .contentShape(.circle)
                .accessibilityIdentifier("pause")
        }
        .padding(.leading, 7)
        .padding(.trailing, 4)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, minHeight: 50)
        .background {
            ComicPanelShape(cut: 7)
                .fill(GoalRushTheme.ink.opacity(0.92))
        }
        .overlay {
            ComicPanelShape(cut: 7)
                .stroke(world.accentColor.opacity(0.34), lineWidth: 1.25)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("gameplay-status-bar")
    }
}
