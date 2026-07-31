import SwiftUI

struct RelicDetailSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let relic: EndlessRelic
    @State private var confirmsScrap = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.sectionSpacing) {
                    RelicCardView(relic: relic, isEquipped: isEquipped)
                    RelicComparisonRows(
                        candidate: relic,
                        equipped: comparedRelic
                    )
                    .padding(GoalRushTheme.Metrics.standardSpacing)
                    .gameSurface(.panel)
                }
                .padding(GoalRushTheme.Metrics.horizontalPadding)
            }
            .background(GoalRushTheme.navy.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                actions
                    .padding(GoalRushTheme.Metrics.standardSpacing)
                    .background(.ultraThinMaterial)
            }
            .navigationTitle("Relic Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: dismiss.callAsFunction)
                }
            }
        }
        .confirmationDialog(
            isEquipped ? "Scrap & Unequip?" : "Scrap this relic?",
            isPresented: $confirmsScrap,
            titleVisibility: .visible
        ) {
            Button(
                isEquipped
                    ? "Scrap & Unequip for \(relic.scrapValue)"
                    : "Scrap for \(relic.scrapValue)",
                role: .destructive,
                action: scrap
            )
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This relic will be permanently removed.")
        }
    }

    private var actions: some View {
        VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            Button(action: toggleEquipped) {
                Label(
                    isEquipped ? "Unequip" : "Equip Relic",
                    systemImage: isEquipped ? "xmark.circle.fill" : "checkmark.circle.fill"
                )
            }
            .buttonStyle(PrimaryGameButton())
            .accessibilityIdentifier("relic-detail-equip")

            Button(
                isEquipped ? "Scrap & Unequip" : "Scrap for \(relic.scrapValue)",
                role: .destructive
            ) {
                confirmsScrap = true
            }
            .buttonStyle(SecondaryGameButton())
            .accessibilityIdentifier("relic-detail-scrap")
        }
    }

    private var isEquipped: Bool {
        store.progress.endlessRecord.equippedRelicID == relic.id
    }

    private var comparedRelic: EndlessRelic? {
        guard store.progress.endlessRecord.equippedRelicID != relic.id else {
            return nil
        }
        return store.progress.endlessRecord.equippedRelic
    }

    private func toggleEquipped() {
        store.uiAudio.play(.tap)
        _ = store.equipRelic(isEquipped ? nil : relic.id)
    }

    private func scrap() {
        store.uiAudio.play(.purchase)
        _ = store.scrapRelics([relic.id])
        dismiss()
    }
}
