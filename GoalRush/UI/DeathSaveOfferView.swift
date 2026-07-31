import SwiftUI

struct DeathSaveOfferView: View {
    @Environment(RewardedAdService.self) private var rewardedAds
    @State private var didEarnContinue = false
    @State private var isShowingUnavailableAlert = false

    let mode: RunMode
    let wave: Int
    let continueRun: () -> Void
    let finishRun: () -> Void

    var body: some View {
        Color.black.opacity(0.78)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 52, weight: .black))
                        .foregroundStyle(GoalRushTheme.orange)
                        .accessibilityHidden(true)

                    VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                        Text("SECOND CHANCE?")
                            .font(GoalRushTheme.Typography.title)
                            .multilineTextAlignment(.center)

                        Text(runPosition)
                            .font(GoalRushTheme.Typography.headline)
                            .foregroundStyle(GoalRushTheme.cyan)
                            .multilineTextAlignment(.center)

                        Text("Restore 35% stamina with a brief shield. Available once per run.")
                            .font(GoalRushTheme.Typography.body)
                            .foregroundStyle(.white.opacity(0.78))
                            .multilineTextAlignment(.center)
                    }

                    Button(action: watchOrLoadAd) {
                        Label(primaryButtonTitle, systemImage: "play.rectangle.fill")
                    }
                    .buttonStyle(GameLaunchButtonStyle())
                    .disabled(isPrimaryButtonDisabled)
                    .accessibilityIdentifier("death-save-watch")
                    .accessibilityHint(
                        "Plays an optional full-screen ad, then continues this run."
                    )

                    Button("Let Me Die", role: .destructive, action: finishRun)
                        .buttonStyle(SecondaryGameButton())
                        .accessibilityIdentifier("death-save-decline")
                }
                .padding(GoalRushTheme.Metrics.sectionSpacing)
                .gameSurface(.modal)
                .frame(maxWidth: 360)
                .padding(24)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("death-save-offer")
            }
            .task {
                rewardedAds.loadAdIfNeeded()
            }
            .onChange(of: rewardedAds.isPresenting) { wasPresenting, isPresenting in
                if wasPresenting && !isPresenting {
                    completeContinueIfReady()
                }
            }
            .onChange(of: didEarnContinue) { _, _ in
                completeContinueIfReady()
            }
            .alert("Continue Unavailable", isPresented: $isShowingUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The ad could not be shown. You can try again or finish the run.")
            }
    }

    private var runPosition: String {
        switch mode {
        case .campaign(let level):
            "Continue Level \(level)"
        case .endless:
            "Continue Endless · Wave \(GameNumberFormatter.compact(wave))"
        }
    }

    private var primaryButtonTitle: String {
        if rewardedAds.isReady {
            return "Watch Ad & Continue"
        }
        if rewardedAds.isLoading || rewardedAds.lastErrorMessage == nil {
            return "Preparing Ad…"
        }
        return "Try Loading Ad"
    }

    private var isPrimaryButtonDisabled: Bool {
        !rewardedAds.isConfigured
            || rewardedAds.isPresenting
            || rewardedAds.isLoading
            || (!rewardedAds.isReady && rewardedAds.lastErrorMessage == nil)
    }

    private func watchOrLoadAd() {
        guard rewardedAds.isReady else {
            rewardedAds.loadAdIfNeeded()
            return
        }

        let didPresent = rewardedAds.presentRewardedAd {
            didEarnContinue = true
        }
        if !didPresent {
            isShowingUnavailableAlert = true
        }
    }

    private func completeContinueIfReady() {
        guard didEarnContinue, !rewardedAds.isPresenting else { return }
        didEarnContinue = false
        continueRun()
    }
}
