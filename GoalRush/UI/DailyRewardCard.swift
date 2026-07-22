import SwiftUI

struct DailyRewardCard: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var claimedReward: ClaimedReward?

    var body: some View {
        Button {
            if store.isDailyRewardClaimable {
                store.uiAudio.play(.claim)
                let amount = store.claimDailyReward()
                if amount > 0 { claimedReward = ClaimedReward(amount: amount) }
            } else {
                store.uiAudio.play(.locked, volume: 0.5)
            }
        } label: {
            HStack(spacing: 13) {
                Image("DailyChest")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(.rect(cornerRadius: 14))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.isDailyRewardClaimable ? "Daily reward ready" : "Daily reward claimed")
                        .font(.headline)
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(GoalRushTheme.orange)
                        Text(store.dailyStreak > 0 ? "Day \(store.dailyStreak) streak" : "Start your streak")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 4)
                if store.isDailyRewardClaimable {
                    Text("+\(store.nextDailyReward)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(GoalRushTheme.gold)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(GoalRushTheme.positive)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [GoalRushTheme.gold.opacity(store.isDailyRewardClaimable ? 0.22 : 0.08), GoalRushTheme.surface.opacity(0.95)],
                    startPoint: .leading, endPoint: .trailing
                ),
                in: .rect(cornerRadius: 20)
            )
            .overlay { RoundedRectangle(cornerRadius: 20).stroke(GoalRushTheme.gold.opacity(store.isDailyRewardClaimable ? 0.5 : 0.15)) }
        }
        .buttonStyle(.plain)
        .pulseGlow(store.isDailyRewardClaimable)
        .accessibilityIdentifier("daily-chest")
        .accessibilityLabel(store.isDailyRewardClaimable
                            ? "Claim daily reward, plus \(store.nextDailyReward) tokens, streak day \(store.nextStreakDay)"
                            : "Daily reward claimed, streak day \(store.dailyStreak)")
        .sheet(item: $claimedReward) { claim in
            DailyRewardClaimSheet(reward: claim.amount, streak: store.dailyStreak)
                .presentationDetents([.medium])
        }
    }
}

private struct ClaimedReward: Identifiable {
    let id = UUID()
    let amount: Int
}

private struct DailyRewardClaimSheet: View {
    let reward: Int
    let streak: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            GoalRushTheme.navy.ignoresSafeArea()
            ConfettiBurst(accent: GoalRushTheme.gold)
            VStack(spacing: 18) {
                Spacer()
                Image("DailyChest")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(.rect(cornerRadius: 28))
                    .shadow(color: GoalRushTheme.gold.opacity(0.4), radius: 20)
                    .accessibilityHidden(true)
                Text("DAY \(streak) REWARD")
                    .font(.caption.bold())
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Image(systemName: "hexagon.fill").foregroundStyle(GoalRushTheme.gold)
                    CountUpText(value: reward, font: .system(size: 44, weight: .bold), color: GoalRushTheme.gold)
                }
                Text("Come back tomorrow for \(DailyRewardEngine.reward(forStreakDay: min(streak + 1, 7))) tokens")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Collect", systemImage: "checkmark") { dismiss() }
                    .buttonStyle(PrimaryGameButton())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                    .accessibilityIdentifier("daily-collect")
            }
        }
    }
}
