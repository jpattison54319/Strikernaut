import SwiftUI

struct HomeBrand: View {
    var body: some View {
        VStack(spacing: 1) {
            Text("GOAL RUSH")
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .tracking(1.6)
                .foregroundStyle(.white)
                .shadow(color: GoalRushTheme.blue.opacity(0.8), radius: 10)
            Text("STADIUM COMMAND")
                .font(.caption2.weight(.heavy))
                .tracking(2)
                .foregroundStyle(GoalRushTheme.cyan)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }
}
