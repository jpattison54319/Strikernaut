import SwiftUI

struct RewardedTokenBonusCard: View {
    @Environment(GameStore.self) private var store
    @Environment(RewardedAdService.self) private var rewardedAds
    @State private var claimedBonus = 0
    @State private var isShowingUnavailableAlert = false

    let result: RunResult

    var body: some View {
        Group {
            if claimedBonus > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("+50%")
                }
                .font(GoalRushTheme.Typography.captionEmphasized)
                .foregroundStyle(GoalRushTheme.positive)
                .frame(minWidth: 76, minHeight: 44)
                .background(
                    GoalRushTheme.positive.opacity(0.12),
                    in: ComicPanelShape(cut: 6)
                )
                .overlay {
                    ComicPanelShape(cut: 6)
                        .stroke(GoalRushTheme.positive.opacity(0.72), lineWidth: 1.5)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("50 percent token bonus added")
                .accessibilityIdentifier("rewarded-token-bonus-claimed")
            } else if store.canOfferRewardedTokenBonus(for: result), rewardedAds.isReady {
                Button(action: watchAd) {
                    HStack(spacing: 5) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("+50%")
                            .font(GoalRushTheme.Typography.captionEmphasized)
                    }
                    .foregroundStyle(.white)
                    .frame(minWidth: 76, minHeight: 44)
                    .background(
                        GoalRushTheme.blue,
                        in: ComicPanelShape(cut: 6)
                    )
                    .overlay {
                        ComicPanelShape(cut: 6)
                            .stroke(GoalRushTheme.cyan.opacity(0.76), lineWidth: 1.5)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Watch video ad")
                .accessibilityValue("50 percent more Training Tokens")
                .accessibilityHint("Plays an optional video ad.")
                .accessibilityIdentifier("rewarded-token-bonus")
            }
        }
        .task {
            rewardedAds.loadAdIfNeeded()
        }
        .alert("Reward Unavailable", isPresented: $isShowingUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The ad could not be shown. Your earned tokens are unchanged.")
        }
    }

    private func watchAd() {
        store.uiAudio.play(.tap)
        let didPresent = rewardedAds.presentRewardedAd {
            let awarded = store.claimRewardedTokenBonus(for: result)
            guard awarded > 0 else { return }
            claimedBonus = awarded
            store.uiAudio.play(.claim)
        }
        if !didPresent {
            isShowingUnavailableAlert = true
        }
    }
}
