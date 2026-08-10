import SwiftUI

struct RelicInventoryGrid: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let relics: [EndlessRelic]
    let equippedID: UUID?
    let isSalvageMode: Bool
    let selectedIDs: Set<UUID>
    let salvagingIDs: Set<UUID>
    let onTap: (EndlessRelic) -> Void

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: 3
    )

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            LazyVStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                relicButtons(useCompactTile: false)
            }
        } else {
            LazyVGrid(columns: columns, spacing: 12) {
                relicButtons(useCompactTile: true)
            }
            .accessibilityIdentifier("relic-inventory-grid")
        }
    }

    @ViewBuilder
    private func relicButtons(useCompactTile: Bool) -> some View {
        ForEach(relics) { relic in
            Button {
                onTap(relic)
            } label: {
                if useCompactTile {
                    RelicInventoryTile(
                        relic: relic,
                        isEquipped: equippedID == relic.id,
                        isSelected: selectedIDs.contains(relic.id),
                        selectionEnabled: isSalvageMode
                    )
                } else {
                    RelicCardView(
                        relic: relic,
                        isEquipped: equippedID == relic.id,
                        isSelected: selectedIDs.contains(relic.id),
                        selectionEnabled: isSalvageMode
                    )
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(salvagingIDs.contains(relic.id) ? 0.38 : 1)
            .rotationEffect(.degrees(salvagingIDs.contains(relic.id) ? 18 : 0))
            .opacity(salvagingIDs.contains(relic.id) ? 0 : 1)
            .accessibilityIdentifier("relic-card-\(relic.id.uuidString)")
            .accessibilityHint(
                isSalvageMode
                    ? "Adds or removes this relic from the salvage selection."
                    : (
                        equippedID == relic.id
                            ? "Unequips this relic."
                            : "Equips this relic."
                    )
            )
        }
    }
}
