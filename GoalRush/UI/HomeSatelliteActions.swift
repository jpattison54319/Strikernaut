import SwiftUI

struct HomeSatelliteActions: View {
    let content: HomeStageContent
    let onDaily: () -> Void
    let onMissions: () -> Void
    let onProgress: () -> Void
    let onEndless: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: GoalRushTheme.Metrics.standardSpacing) {
            VStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
                FloatingGameActionButton(
                    title: "Daily",
                    systemImage: "gift.fill",
                    badge: content.dailyBadge,
                    accent: GoalRushTheme.gold,
                    action: onDaily
                )
                .accessibilityIdentifier("daily-chest")
                .accessibilityValue(content.dailySubtitle)

                FloatingGameActionButton(
                    title: "Missions",
                    systemImage: "target",
                    badge: content.missionBadge,
                    accent: GoalRushTheme.cyan,
                    action: onMissions
                )
                .accessibilityIdentifier("missions")
                .accessibilityValue(content.missionsSubtitle)
            }

            Spacer(minLength: 72)

            VStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
                FloatingGameActionButton(
                    title: "Progress",
                    systemImage: "trophy.fill",
                    accent: GoalRushTheme.cyan,
                    action: onProgress
                )
                .accessibilityIdentifier("trophies")

                FloatingGameActionButton(
                    title: "Endless",
                    systemImage: "infinity",
                    accent: GoalRushTheme.orange,
                    action: onEndless
                )
                .accessibilityIdentifier("endless")
                .accessibilityValue(content.endlessStatus)
            }
        }
    }
}
