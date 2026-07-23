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
                        .font(.footnote)
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
    }

#if DEBUG
    @ViewBuilder
    private var developerActions: some View {
        Button("Grant 1,000 Tokens") {
            store.progress.trainingTokens += 1_000
            store.saveProgress()
        }
        .buttonStyle(SecondaryGameButton())

        Button("Unlock All Levels") {
            store.progress.highestUnlockedLevel = GameContent.levels.count
            store.saveProgress()
        }
        .buttonStyle(SecondaryGameButton())

        Button("Unlock All Gear") {
            store.progress.unlockedGear = Set(GearID.allCases)
            store.saveProgress()
        }
        .buttonStyle(SecondaryGameButton())
    }
#endif

    private var subtitle: String {
        switch group {
        case .audio: "Music, sound, and tactile feedback."
        case .accessibility: "Comfort and gameplay assistance."
        case .support: "Replay the introduction whenever you need it."
#if DEBUG
        case .developer: "Local testing actions."
#endif
        }
    }
}
