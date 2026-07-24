import SwiftUI

struct DailyRewardBoard: View {
    let activeDay: Int
    let completedThrough: Int
    let onCollect: () -> Void

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: GoalRushTheme.Metrics.compactSpacing),
        count: 3
    )

    var body: some View {
        VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
            LazyVGrid(columns: columns, spacing: GoalRushTheme.Metrics.compactSpacing) {
                ForEach(1...6, id: \.self) { day in
                    let isCurrent = day == activeDay && day > completedThrough
                    DailyRewardTile(
                        day: day,
                        reward: DailyRewardEngine.rewards[day - 1],
                        isCollected: day <= completedThrough,
                        isCurrent: isCurrent,
                        isGrandPrize: false,
                        onCollect: isCurrent ? onCollect : nil
                    )
                }
            }

            let isCurrent = activeDay == 7 && completedThrough < 7
            DailyRewardTile(
                day: 7,
                reward: DailyRewardEngine.rewards[6],
                isCollected: completedThrough == 7,
                isCurrent: isCurrent,
                isGrandPrize: true,
                onCollect: isCurrent ? onCollect : nil
            )
        }
    }
}
