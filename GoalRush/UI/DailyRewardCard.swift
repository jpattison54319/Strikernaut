import SwiftUI

struct DailyRewardCard: View {
    @Environment(GameStore.self) private var store
    @State private var claimedReward: Int?

    var body: some View {
        VStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
            if let claimedReward {
                claimedContent(reward: claimedReward)
            } else {
                previewContent
            }
        }
        .frame(maxWidth: .infinity)
        .padding(GoalRushTheme.Metrics.sectionSpacing)
        .gameSurface(.modal)
    }

    private var previewContent: some View {
        VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            Image("DailyChest")
                .resizable()
                .scaledToFill()
                .frame(width: 112, height: 112)
                .clipShape(.rect(cornerRadius: GoalRushTheme.Metrics.panelRadius))
                .shadow(color: GoalRushTheme.gold.opacity(0.38), radius: 18)
                .accessibilityHidden(true)

            Text(store.isDailyRewardClaimable ? "DAY \(store.nextStreakDay) REWARD" : "REWARD COLLECTED")
                .font(.caption.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.72))

            if store.isDailyRewardClaimable {
                Label("+\(store.nextDailyReward) Training Tokens", systemImage: "hexagon.fill")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(GoalRushTheme.gold)

                Text(store.dailyStreak > 0
                     ? "Keep your \(store.dailyStreak)-day streak moving."
                     : "Collect to start your daily streak.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)

                Button("Collect Reward", systemImage: "gift.fill", action: claimReward)
                    .buttonStyle(GameLaunchButtonStyle())
                    .accessibilityIdentifier("daily-collect")
            } else {
                Label("Day \(store.dailyStreak) secured", systemImage: "checkmark.seal.fill")
                    .font(.headline.bold())
                    .foregroundStyle(GoalRushTheme.positive)
                Text("Come back tomorrow for your next streak reward.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func claimedContent(reward: Int) -> some View {
        ZStack {
            if HomePresentation.showsDailyCelebration(
                claimedReward: claimedReward,
                reducedFlashes: store.settings.reducedFlashes
            ) {
                ConfettiBurst(accent: GoalRushTheme.gold)
                    .accessibilityHidden(true)
            }

            VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 58, weight: .bold))
                    .foregroundStyle(GoalRushTheme.positive)
                    .accessibilityHidden(true)
                Text("REWARD COLLECTED")
                    .font(.caption.weight(.heavy))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.72))
                Label("+\(reward) Training Tokens", systemImage: "hexagon.fill")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(GoalRushTheme.gold)
                Text("Day \(store.dailyStreak) is secure. Come back tomorrow for \(DailyRewardEngine.reward(forStreakDay: min(store.dailyStreak + 1, 7))) tokens.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, GoalRushTheme.Metrics.sectionSpacing)
        }
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
