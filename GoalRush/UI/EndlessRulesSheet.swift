import SwiftUI

struct EndlessRulesSheet: View {
    var body: some View {
        GameSheetScaffold(
            title: "Endless Rules",
            subtitle: "Build one continuous run across every world."
        ) {
            VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
                rule("World changes every 10 waves", icon: "globe.americas.fill")
                rule("The world circuit repeats forever", icon: "arrow.trianglehead.2.clockwise.rotate.90")
                rule("Difficulty keeps scaling", icon: "flame.fill")
                rule("Choose a power after every wave", icon: "sparkles")
                rule("Boss wave every 5 waves", icon: "crown.fill")
                rule("Run powers reset when the run ends", icon: "arrow.counterclockwise")
                rule("Your selected hero and Training upgrades always apply", icon: "checkmark.shield.fill")
            }
        }
    }

    private func rule(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(GoalRushTheme.Typography.headline)
            .foregroundStyle(.white)
            .padding(GoalRushTheme.Metrics.standardSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .gameSurface(.panel)
    }
}
