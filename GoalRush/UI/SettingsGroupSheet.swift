import SwiftUI

enum SettingsGroup: String, Identifiable {
    case audio
    case accessibility
    case support
#if DEBUG
    case developer
#endif

    var id: String { rawValue }

    var title: String {
        switch self {
        case .audio: "Audio & Feedback"
        case .accessibility: "Accessibility"
        case .support: "Support"
#if DEBUG
        case .developer: "Developer"
#endif
        }
    }

    var icon: String {
        switch self {
        case .audio: "speaker.wave.2.fill"
        case .accessibility: "accessibility"
        case .support: "questionmark.circle.fill"
#if DEBUG
        case .developer: "hammer.fill"
#endif
        }
    }

    var accent: Color {
        switch self {
        case .audio: GoalRushTheme.gold
        case .accessibility: GoalRushTheme.cyan
        case .support: GoalRushTheme.positive
#if DEBUG
        case .developer: GoalRushTheme.orange
#endif
        }
    }
}

struct SettingsGroupSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(RewardedAdService.self) private var rewardedAds
    @State private var privacyErrorMessage: String?
    @State private var isShowingPrivacyError = false
    let group: SettingsGroup

    var body: some View {
        @Bindable var store = store

        GameSheetScaffold(title: group.title, subtitle: subtitle) {
            VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
                switch group {
                case .audio:
                    Toggle("Music", isOn: $store.settings.musicEnabled)
                    Toggle("Sound Effects", isOn: $store.settings.soundEnabled)
                    Toggle("Haptics", isOn: $store.settings.hapticsEnabled)

                case .accessibility:
                    Toggle("Reduce Flashes", isOn: $store.settings.reducedFlashes)
                    Toggle("Assist Mode", isOn: $store.settings.assistMode)
                    Text("Assist Mode widens shots and slows hostile projectiles without reducing rewards.")
                        .font(GoalRushTheme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.72))

                case .support:
                    Button("Replay Onboarding", systemImage: "play.rectangle") {
                        store.uiAudio.play(.tap)
                        store.progress.hasSeenOnboarding = false
                        store.saveProgress()
                        store.route = .onboarding
                    }
                    .buttonStyle(SecondaryGameButton())
                    .accessibilityIdentifier("settings-replay-onboarding")

                    Link(destination: URL(string: "https://jpattison54319.github.io/support/")!) {
                        Label("Support Website", systemImage: "safari.fill")
                    }
                    .buttonStyle(SecondaryGameButton())
                    .accessibilityIdentifier("settings-support-website")

                    Link(destination: URL(string: "https://jpattison54319.github.io/privacy/")!) {
                        Label("Privacy Policy", systemImage: "lock.shield.fill")
                    }
                    .buttonStyle(SecondaryGameButton())
                    .accessibilityIdentifier("settings-privacy-policy")

                    if rewardedAds.isPrivacyOptionsRequired {
                        Button(
                            "Privacy Choices",
                            systemImage: "hand.raised.fill",
                            action: showPrivacyChoices
                        )
                        .buttonStyle(SecondaryGameButton())
                        .accessibilityIdentifier("settings-privacy-choices")
                    }

#if DEBUG
                case .developer:
                    developerActions
#endif
                }
            }
            .tint(GoalRushTheme.gold)
            .foregroundStyle(.white)
            .padding(GoalRushTheme.Metrics.standardSpacing)
            .gameSurface(.panel)
        }
        .alert(
            "Privacy Choices Unavailable",
            isPresented: $isShowingPrivacyError
        ) {
            Button("OK", role: .cancel) {
                privacyErrorMessage = nil
            }
        } message: {
            Text(privacyErrorMessage ?? "Please try again later.")
        }
    }

#if DEBUG
    @ViewBuilder
    private var developerActions: some View {
        Button("Grant 1,000 Tokens") {
            store.uiAudio.requestFeedback(.success)
            store.progress.trainingTokens += 1_000
            store.saveProgress()
        }
        .buttonStyle(SecondaryGameButton())

        Button(
            isAllTestContentUnlocked
                ? "All Levels & Characters Unlocked"
                : "Unlock All Levels & Characters",
            systemImage: "lock.open.fill"
        ) {
            store.uiAudio.requestFeedback(.success)
            store.unlockAllContentForTesting()
        }
        .buttonStyle(SecondaryGameButton())
        .disabled(isAllTestContentUnlocked)
        .accessibilityIdentifier("developer-unlock-all-content")

        Text("Unlocks all \(GameContent.levels.count) levels and every character without completing challenges or granting their rewards.")
            .font(GoalRushTheme.Typography.caption)
            .foregroundStyle(.secondary)
    }

    private var isAllTestContentUnlocked: Bool {
        store.progress.highestUnlockedLevel >= GameContent.levels.count
            && store.progress.unlockedCharacters == Set(CharacterID.allCases)
    }
#endif

    private var subtitle: String {
        switch group {
        case .audio: "Music, sound, and tactile feedback."
        case .accessibility: "Comfort and gameplay assistance."
        case .support: "Onboarding, support, and privacy."
#if DEBUG
        case .developer: "Local testing actions."
#endif
        }
    }

    private func showPrivacyChoices() {
        Task {
            do {
                try await rewardedAds.presentPrivacyOptions()
            } catch {
                privacyErrorMessage = "The ad privacy form could not be displayed. Please try again later."
                isShowingPrivacyError = true
            }
        }
    }
}
