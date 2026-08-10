import SwiftUI

struct EndlessRunStatsView: View {
    let record: EndlessRecord

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                    lastRunCard
                    bestCard
                }
            } else {
                HStack(alignment: .top, spacing: GoalRushTheme.Metrics.standardSpacing) {
                    lastRunCard
                    bestCard
                }
            }
        }
    }

    private var lastRunCard: some View {
        EndlessRunStatCard(
            title: "Last Run",
            systemImage: "clock.arrow.circlepath",
            accent: GoalRushTheme.cyan,
            wave: record.lastWave,
            score: record.lastScore,
            accessibilityIdentifier: "endless-last-run"
        )
    }

    private var bestCard: some View {
        EndlessRunStatCard(
            title: "Best",
            systemImage: "crown.fill",
            accent: GoalRushTheme.gold,
            wave: record.bestWave > 0 ? record.bestWave : nil,
            score: record.bestScore > 0 ? record.bestScore : nil,
            accessibilityIdentifier: "endless-best"
        )
    }
}
