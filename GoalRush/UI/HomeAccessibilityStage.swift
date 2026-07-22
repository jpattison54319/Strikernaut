import SwiftUI

struct HomeAccessibilityStage: View {
    let content: HomeStageContent
    let onDaily: () -> Void
    let onMissions: () -> Void
    let onPrimary: () -> Void
    let onCampaign: () -> Void
    let onEndless: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
                HomeTopHUD()
                HomeBrand()
                HomeLaunchControl(
                    eyebrow: content.primaryEyebrow,
                    title: content.primaryTitle,
                    action: onPrimary
                )

                VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                    HomeAccessibilityAction(
                        title: "Daily",
                        subtitle: content.dailySubtitle,
                        systemImage: "gift.fill",
                        badge: content.dailyBadge,
                        accent: GoalRushTheme.gold,
                        action: onDaily
                    )
                    .accessibilityIdentifier("daily-chest")

                    HomeAccessibilityAction(
                        title: "Missions",
                        subtitle: content.missionsSubtitle,
                        systemImage: "target",
                        badge: content.missionBadge,
                        accent: GoalRushTheme.cyan,
                        action: onMissions
                    )
                    .accessibilityIdentifier("missions")
                }

                VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                    HomeAccessibilityAction(
                        title: "Campaign",
                        subtitle: content.campaignStatus,
                        systemImage: "map.fill",
                        accent: GoalRushTheme.cyan,
                        action: onCampaign
                    )
                    .accessibilityIdentifier("play")

                    HomeAccessibilityAction(
                        title: "Endless",
                        subtitle: content.endlessStatus,
                        systemImage: "infinity",
                        accent: GoalRushTheme.orange,
                        action: onEndless
                    )
                    .accessibilityIdentifier("endless")
                }

                HomeClubhouseDock()
            }
            .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
            .padding(.vertical, GoalRushTheme.Metrics.standardSpacing)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}
