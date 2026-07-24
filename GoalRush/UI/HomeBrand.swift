import SwiftUI

struct HomeBrand: View {
    var body: some View {
        VStack(spacing: 1) {
            Text("STRIKERNAUT")
                .font(GoalRushTheme.Typography.display(size: 44, relativeTo: .largeTitle))
                .tracking(1.1)
                .foregroundStyle(GoalRushTheme.paper)
                .shadow(color: GoalRushTheme.ink, radius: 0, x: 3, y: 3)
                .shadow(color: GoalRushTheme.cyan.opacity(0.82), radius: 0, x: -2, y: 2)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home-brand")
    }
}
