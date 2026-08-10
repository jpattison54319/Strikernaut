import SwiftUI

struct OnboardingPageStage: View {
    let icon: String
    let accent: Color
    let title: String
    let message: String
    let usesFlexibleSpacing: Bool

    var body: some View {
        VStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
            if usesFlexibleSpacing {
                Spacer(minLength: GoalRushTheme.Metrics.compactSpacing)
            }

            Image(systemName: icon)
                .font(.system(size: 84, weight: .bold))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.4), radius: 24)
                .accessibilityHidden(true)

            VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                Text(title)
                    .font(GoalRushTheme.Typography.display)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(GoalRushTheme.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
            .padding(GoalRushTheme.Metrics.sectionSpacing)
            .frame(maxWidth: .infinity)
            .gameSurface(.modal)

            if usesFlexibleSpacing {
                Spacer(minLength: GoalRushTheme.Metrics.compactSpacing)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
