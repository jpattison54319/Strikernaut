import SwiftUI

struct UpgradeTrackStage: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let onSelect: (UpgradeTrack) -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
                    trackColumns
                }
            } else {
                HStack(alignment: .top, spacing: GoalRushTheme.Metrics.standardSpacing) {
                    trackColumns
                }
            }
        }
    }

    @ViewBuilder
    private var trackColumns: some View {
        ForEach(UpgradeCategory.allCases) { category in
            VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
                Label(category.rawValue, systemImage: category == .player ? "figure.run" : "soccerball")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)

                ForEach(UpgradeTrack.allCases.filter { $0.category == category }) { track in
                    trackButton(track)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func trackButton(_ track: UpgradeTrack) -> some View {
        let rank = store.progress.rank(for: track)
        let maximum = rank == UpgradeRules.maxRank
        let cost = UpgradeRules.cost(forNextRank: rank)
        let ready = !maximum && store.progress.trainingTokens >= cost

        return Button {
            onSelect(track)
        } label: {
            HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                Image(systemName: UpgradePresentation.icon(for: track))
                    .font(.headline.bold())
                    .foregroundStyle(GoalRushTheme.gold)
                    .frame(width: 32, height: 32)
                    .background(GoalRushTheme.navy.opacity(0.72), in: .circle)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(UpgradeRules.title(for: track))
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                    Text("Rank \(rank) of \(UpgradeRules.maxRank)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))
                }

                Spacer(minLength: 2)

                if maximum {
                    GameStatusBadge(text: "MAX", tone: .attention)
                } else if ready {
                    GameStatusBadge(text: "READY", tone: .positive)
                }
            }
            .padding(GoalRushTheme.Metrics.compactSpacing)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .gameSurface(.panel)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("upgrade-\(track.rawValue)")
    }
}
