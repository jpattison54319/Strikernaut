import SwiftUI

struct DailyRewardCard: View {
    @Environment(GameStore.self) private var store
    @State private var claimedReward: Int?

    var body: some View {
        ZStack {
            DailyRewardBoard(
                activeDay: store.nextDailyRewardDay,
                completedThrough: completedThrough,
                onCollect: claimReward
            )
            .frame(maxWidth: .infinity)
            .padding(GoalRushTheme.Metrics.standardSpacing)
            .gameSurface(.modal)

            if HomePresentation.showsDailyCelebration(
                claimedReward: claimedReward,
                reducedFlashes: store.settings.reducedFlashes
            ) {
                ConfettiBurst(accent: GoalRushTheme.gold)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
        }
    }

    private var completedThrough: Int {
        store.isDailyRewardClaimable ? max(store.nextDailyRewardDay - 1, 0) : store.nextDailyRewardDay
    }

    private func claimReward() {
        guard store.isDailyRewardClaimable else {
            store.uiAudio.play(.locked, volume: 0.5)
            return
        }
        store.uiAudio.play(.claim)
        let reward = store.claimDailyReward()
        if reward > 0 {
            claimedReward = reward
        }
    }
}
