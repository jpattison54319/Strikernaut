import SwiftUI

struct MissionsStrip: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        Group {
            if store.progress.missions.isEmpty {
                ContentUnavailableView(
                    "Missions refresh soon",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Check back shortly for a new set of daily objectives.")
                )
                .foregroundStyle(.white)
            } else {
                VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                    ForEach(store.progress.missions) { mission in
                        MissionRow(mission: mission)
                    }
                }
            }
        }
    }
}
