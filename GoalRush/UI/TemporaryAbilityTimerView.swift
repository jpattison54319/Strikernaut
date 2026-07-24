import SwiftUI

struct TemporaryAbilityTimerView: View {
    let ability: TemporaryBallAbility
    let remaining: TimeInterval
    let duration: TimeInterval

    private var fraction: Double {
        min(1, max(0, remaining / max(duration, 0.01)))
    }

    var body: some View {
        Image(systemName: TemporaryAbilityRules.icon(for: ability))
            .font(.headline.bold())
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(.black.opacity(0.72), in: .circle)
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.16), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        GoalRushTheme.gold,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            .shadow(color: GoalRushTheme.gold.opacity(0.28), radius: 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(TemporaryAbilityRules.title(for: ability))
            .accessibilityValue("\(Int(remaining.rounded(.up))) seconds remaining")
            .accessibilityIdentifier("temporary-ability-timer")
    }
}
