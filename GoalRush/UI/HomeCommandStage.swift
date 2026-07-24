import SwiftUI

struct HomeCommandStage: View {
    let content: HomeStageContent
    let onDaily: () -> Void
    let onMissions: () -> Void
    let onPrimary: () -> Void
    let onCampaign: () -> Void
    let onProgress: () -> Void
    let onEndless: () -> Void

    var body: some View {
        VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            HomeTopHUD()
            HomeBrand()

            Spacer(minLength: GoalRushTheme.Metrics.compactSpacing)

            HomeSatelliteActions(
                content: content,
                onDaily: onDaily,
                onMissions: onMissions,
                onProgress: onProgress,
                onEndless: onEndless
            )
            .accessibilitySortPriority(50)

            Spacer(minLength: GoalRushTheme.Metrics.compactSpacing)

            HStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                Button("Campaign", systemImage: "map.fill", action: onCampaign)
                    .labelStyle(.iconOnly)
                    .buttonStyle(GameLaunchButtonStyle(circular: true))
                    .accessibilityIdentifier("play")

                HomeLaunchControl(
                    eyebrow: content.primaryEyebrow,
                    title: content.primaryTitle,
                    action: onPrimary
                )
            }
            .accessibilitySortPriority(100)
            HomeClubhouseDock()
                .accessibilitySortPriority(10)
        }
        .accessibilityElement(children: .contain)
        .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
        .padding(.vertical, GoalRushTheme.Metrics.compactSpacing)
    }

}
