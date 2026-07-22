import SwiftUI

struct HomeCommandStage: View {
    let content: HomeStageContent
    let onDaily: () -> Void
    let onMissions: () -> Void
    let onPrimary: () -> Void
    let onCampaign: () -> Void
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
                onCampaign: onCampaign,
                onEndless: onEndless
            )

            Spacer(minLength: GoalRushTheme.Metrics.compactSpacing)

            HomeLaunchControl(
                eyebrow: content.primaryEyebrow,
                title: content.primaryTitle,
                action: onPrimary
            )
            HomeClubhouseDock()
        }
        .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
        .padding(.vertical, GoalRushTheme.Metrics.compactSpacing)
    }
}
