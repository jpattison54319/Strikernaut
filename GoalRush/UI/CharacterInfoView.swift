import SwiftUI

struct CharacterInfoView: View {
    var body: some View {
        GameSheetScaffold(
            title: "Character Abilities",
            subtitle: "Pick a hero whose super ability matches your play style."
        ) {
            VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
                Label("Defeat five enemies to fully charge your ability.", systemImage: "bolt.fill")
                Label("Tap the glowing ability button during live play.", systemImage: "hand.tap.fill")
                Label("Charge resets after use and builds again immediately.", systemImage: "arrow.clockwise")
                Label("Characters change abilities, not permanent Training upgrades.", systemImage: "arrow.up.circle.fill")
            }
            .font(GoalRushTheme.Typography.headline)
            .foregroundStyle(.white)
        }
    }
}
