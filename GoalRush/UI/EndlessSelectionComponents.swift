import SwiftUI

struct EndlessSelectionStage: View {
    let record: EndlessRecord
    let progress: PlayerProgress

    var body: some View {
        VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.sectionSpacing) {
            VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
                Text("World Circuit")
                    .font(GoalRushTheme.Typography.title2)
                    .foregroundStyle(.white)

                Text("The arena changes every \(EndlessRules.wavesPerWorld) waves. Clear every world, then loop with higher difficulty.")
                    .font(GoalRushTheme.Typography.subheadline)
                    .foregroundStyle(.secondary)

                EndlessWorldCircuitView()
            }

            EndlessRecordSummary(
                record: record,
                characterName: CharacterCatalog.character(progress.selectedCharacter).name,
                trainingRankCount: progress.upgradeRanks.values.reduce(0, +)
            )
        }
    }
}
