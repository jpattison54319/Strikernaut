import SwiftUI

struct UpgradeTrackStage: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let onSelect: (UpgradeTrack) -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                verticalCategories
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: GoalRushTheme.Metrics.standardSpacing) {
                        ForEach(UpgradeCategory.allCases) { category in
                            categoryColumn(category)
                                .frame(minWidth: 260, maxWidth: .infinity, alignment: .topLeading)
                        }
                    }

                    verticalCategories
                }
            }
        }
    }

    @ViewBuilder
    private var verticalCategories: some View {
        VStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
            ForEach(UpgradeCategory.allCases) { category in
                categoryColumn(category)
            }
        }
    }

    private func categoryColumn(_ category: UpgradeCategory) -> some View {
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text("Rank \(rank) of \(UpgradeRules.maxRank)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(1)
                }

                Spacer(minLength: 2)

                if maximum {
                    GameStatusBadge(text: "MAX", tone: .attention)
                        .fixedSize()
                } else if ready {
                    GameStatusBadge(text: "READY", tone: .positive)
                        .fixedSize()
                }
            }
            .padding(GoalRushTheme.Metrics.compactSpacing)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .gameSurface(.panel)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("upgrade-\(track.rawValue)")
    }
}
