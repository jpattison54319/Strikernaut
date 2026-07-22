import SwiftUI

struct EndlessSelectionStage: View {
    let world: WorldDefinition
    let record: EndlessRecord
    let progress: PlayerProgress
    let onSelectWorld: (WorldID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.sectionSpacing) {
            VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
                Text("Choose Arena")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(.white)

                WorldSelectionBar(
                    identifierPrefix: "endless-world-",
                    selectedWorld: world.id,
                    progress: progress,
                    onSelect: onSelectWorld
                )
            }

            EndlessRecordSummary(
                world: world,
                record: record,
                equippedGearCount: progress.equippedGear.count,
                trainingRankCount: progress.upgradeRanks.values.reduce(0, +)
            )
        }
    }
}

struct EndlessRulesSheet: View {
    var body: some View {
        GameSheetScaffold(
            title: "Endless Rules",
            subtitle: "Build a run one wave at a time."
        ) {
            VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
                rule("Difficulty keeps scaling", icon: "flame.fill")
                rule("Choose a power after every wave", icon: "sparkles")
                rule("Boss wave every 5 waves", icon: "crown.fill")
                rule("Run powers reset when the run ends", icon: "arrow.counterclockwise")
                rule("Gear and Training upgrades always apply", icon: "checkmark.shield.fill")
            }
        }
    }

    private func rule(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.headline)
            .foregroundStyle(.white)
            .padding(GoalRushTheme.Metrics.standardSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .gameSurface(.panel)
    }
}

private struct EndlessRecordSummary: View {
    let world: WorldDefinition
    let record: EndlessRecord
    let equippedGearCount: Int
    let trainingRankCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
            HStack(alignment: .top, spacing: GoalRushTheme.Metrics.standardSpacing) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(world.name) Record")
                        .font(.caption.bold())
                        .foregroundStyle(world.id.accentColor)
                    Text(record.bestWave > 0 ? "Best Wave \(record.bestWave)" : "No run yet")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(.white)
                    Text(record.bestScore > 0 ? "\(record.bestScore.formatted()) points" : "Start a run to set your first record")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer(minLength: 0)

                Image(systemName: record.bestWave > 0 ? "crown.fill" : "infinity")
                    .font(.title.bold())
                    .foregroundStyle(record.bestWave > 0 ? GoalRushTheme.gold : world.id.accentColor)
                    .accessibilityHidden(true)
            }

            Divider()
                .overlay(GoalRushTheme.surfaceStroke)

            Label("New power after every wave", systemImage: "sparkles")
                .font(.subheadline.bold())
                .foregroundStyle(GoalRushTheme.cyan)

            Label(
                "\(trainingRankCount) Training ranks • \(equippedGearCount) of 5 gear equipped",
                systemImage: "checkmark.shield.fill"
            )
            .font(.caption.bold())
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
        return "\(world.name) record, \(recordText). New power after every wave. \(trainingRankCount) Training ranks, \(equippedGearCount) of 5 gear equipped."
    }
}
