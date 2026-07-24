import SwiftUI

struct UpgradeTrackStage: View {
    var body: some View {
        LazyVStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            ForEach(UpgradeTrack.allCases) { track in
                UpgradeCardView(track: track)
            }
        }
    }
}
