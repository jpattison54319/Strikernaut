import SwiftUI

struct HomeSatelliteActions: View {
    let content: HomeStageContent
    let onDaily: () -> Void
    let onMissions: () -> Void
    let onCampaign: () -> Void
    let onEndless: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: GoalRushTheme.Metrics.standardSpacing) {
            VStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
                FloatingGameActionButton(
                    title: "Daily",
                    subtitle: content.dailySubtitle,
                    systemImage: "gift.fill",
                    badge: content.dailyBadge,
                    accent: GoalRushTheme.gold,
                    action: onDaily
                )
                .accessibilityIdentifier("daily-chest")

                FloatingGameActionButton(
                    title: "Missions",
                    subtitle: content.missionsSubtitle,
                    systemImage: "target",
                    badge: content.missionBadge,
                    accent: GoalRushTheme.cyan,
                    action: onMissions
                )
                .accessibilityIdentifier("missions")
            }

            Spacer(minLength: 72)

            VStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
                FloatingGameActionButton(
                    title: "Campaign",
                    subtitle: content.campaignStatus,
                    systemImage: "map.fill",
                    accent: GoalRushTheme.cyan,
                    action: onCampaign
                )
                .accessibilityIdentifier("play")

                FloatingGameActionButton(
                    title: "Endless",
                    subtitle: content.endlessStatus,
                    systemImage: "infinity",
                    accent: GoalRushTheme.orange,
                    action: onEndless
                )
                .accessibilityIdentifier("endless")
            }
        }
    }
}
