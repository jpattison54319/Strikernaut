import SwiftUI

struct ResultMoreActionsSheet: View {
    @Environment(GameStore.self) private var store
    let result: RunResult

    var body: some View {
        GameSheetScaffold(
            title: "More Actions",
            subtitle: "Your result and rewards are already saved."
        ) {
            VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                if let track = nextUpgradeTrack {
                    nextUpgradeButton(track)
                }

                if result.isFirstClear {
                    Button("Spend your tokens", systemImage: "arrow.up.circle.fill") {
                        store.route = .upgrades
                    }
                    .buttonStyle(SecondaryGameButton())
                    .accessibilityIdentifier("result-spend-tokens")
                }

                Button("Upgrades", systemImage: "arrow.up.circle.fill") {
                    store.route = .upgrades
                }
                .buttonStyle(SecondaryGameButton())
                .accessibilityIdentifier("result-more-upgrades")

                Button("Locker", systemImage: "tshirt.fill") {
                    store.route = .gear
                }
                .buttonStyle(SecondaryGameButton())
                .accessibilityIdentifier("result-more-locker")

                Button(result.mode.isEndless ? "Choose Arena" : "Campaign Map", systemImage: "map.fill") {
                    store.route = result.mode.isEndless ? .endless : .levels
                }
                .buttonStyle(SecondaryGameButton())
                .accessibilityIdentifier("result-more-map")
            }
        }
        .accessibilityIdentifier("result-more-actions")
    }

    private func nextUpgradeButton(_ track: UpgradeTrack) -> some View {
        let rank = store.progress.rank(for: track)
        let cost = UpgradeRules.cost(forNextRank: rank)
        let affordable = store.progress.trainingTokens >= cost

        return Button {
            store.route = .upgrades
        } label: {
            VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                HStack {
                    Label("Next upgrade", systemImage: "arrow.up.circle.fill")
                        .font(.subheadline.bold())
                    Spacer()
                    GameStatusBadge(
                        text: affordable ? "READY" : "\(store.progress.trainingTokens)/\(cost)",
                        tone: affordable ? .positive : .neutral
                    )
                }
                Text("\(UpgradeRules.title(for: track)) rank \(rank + 1)")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ProgressView(value: min(1, Double(store.progress.trainingTokens) / Double(cost)))
                    .tint(affordable ? GoalRushTheme.positive : GoalRushTheme.gold)
            }
            .padding(GoalRushTheme.Metrics.standardSpacing)
            .gameSurface(.panel)
        }
        .buttonStyle(.plain)
        .pulseGlow(affordable && !store.settings.reducedFlashes, color: GoalRushTheme.positive)
        .accessibilityIdentifier("result-next-upgrade")
    }

    private var nextUpgradeTrack: UpgradeTrack? {
        UpgradeTrack.allCases
            .filter { store.progress.rank(for: $0) < UpgradeRules.maxRank }
            .min {
                UpgradeRules.cost(forNextRank: store.progress.rank(for: $0))
                    < UpgradeRules.cost(forNextRank: store.progress.rank(for: $1))
            }
    }
}
