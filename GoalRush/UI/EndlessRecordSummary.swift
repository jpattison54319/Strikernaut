import SwiftUI

struct EndlessRecordSummary: View {
    let record: EndlessRecord
    let characterName: String
    let trainingRankCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
            HStack(alignment: .top, spacing: GoalRushTheme.Metrics.standardSpacing) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Endless Record")
                        .font(GoalRushTheme.Typography.captionEmphasized)
                        .foregroundStyle(GoalRushTheme.cyan)
                    Text(record.bestWave > 0 ? "Best Wave \(record.bestWave)" : "No run yet")
                        .font(GoalRushTheme.Typography.title2)
                        .foregroundStyle(.white)
                    Text(
                        record.bestScore > 0
                            ? "\(record.bestScore.formatted()) points"
                            : "Start a run to set your first record"
                    )
                    .font(GoalRushTheme.Typography.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                }

                Spacer(minLength: 0)

                Image(systemName: record.bestWave > 0 ? "crown.fill" : "infinity")
                    .font(GoalRushTheme.Typography.title)
                    .foregroundStyle(record.bestWave > 0 ? GoalRushTheme.gold : GoalRushTheme.cyan)
                    .accessibilityHidden(true)
            }

            Divider()
                .overlay(GoalRushTheme.surfaceStroke)

            Label("New power after every wave", systemImage: "sparkles")
                .font(GoalRushTheme.Typography.subheadlineEmphasized)
                .foregroundStyle(GoalRushTheme.cyan)

            Label(
                "\(trainingRankCount) Training ranks • \(characterName) selected",
                systemImage: "checkmark.shield.fill"
            )
            .font(GoalRushTheme.Typography.captionEmphasized)
            .foregroundStyle(.white.opacity(0.76))
        }
        .padding(GoalRushTheme.Metrics.sectionSpacing)
        .gameSurface(.panel)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let recordText = record.bestWave > 0
            ? "Best wave \(record.bestWave), \(record.bestScore) points"
            : "No run yet"
        return "Endless record, \(recordText). New power after every wave. \(trainingRankCount) Training ranks, \(characterName) selected."
    }
}
