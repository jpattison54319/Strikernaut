import SwiftUI

struct CharacterInfoView: View {
    var body: some View {
        GameSheetScaffold(
            title: "Character Abilities",
            subtitle: "Pick a hero whose super ability matches your play style."
        ) {
            VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
                Label("Defeats build about one full charge per wave.", systemImage: "bolt.fill")
                Label("Boss damage can build half a charge.", systemImage: "target")
                Label("Tap the glowing ability button during live play.", systemImage: "hand.tap.fill")
                Label("Supers and reinforcements do not recharge it.", systemImage: "arrow.clockwise")
                Label("Characters change abilities, not permanent Training upgrades.", systemImage: "arrow.up.circle.fill")
            }
            .font(GoalRushTheme.Typography.headline)
            .foregroundStyle(.white)
        }
    }
}
