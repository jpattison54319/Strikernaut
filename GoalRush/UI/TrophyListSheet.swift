import SwiftUI

struct TrophyListSheet: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        GameSheetScaffold(
            title: "Trophies",
            subtitle: "\(store.progress.unlockedAchievements.count) of \(AchievementID.allCases.count) complete"
        ) {
            LazyVStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                ForEach(AchievementCatalog.ordered, id: \.self) { id in
                    TrophyListRow(
                        id: id,
                        playerProgress: store.progress
                    )
                }
            }
        }
    }
}
