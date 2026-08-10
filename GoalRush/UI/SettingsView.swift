import SwiftUI

struct SettingsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedGroup: SettingsGroup?

    var body: some View {
        @Bindable var store = store

        AtmosphericGameScreen(backgroundImage: "MenuHero") {
            VStack(spacing: 0) {
                GameDestinationBar(
                    title: "Settings",
                    trailingText: "Support",
                    onHome: goHome,
                    onInfo: { open(.support) }
                )

                ScrollView {
                    VStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
                        Text("Tune Strikernaut to feel right for you.")
                            .font(GoalRushTheme.Typography.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        preferenceGroups

                        Button("Reset Account", systemImage: "arrow.counterclockwise", role: .destructive) {
                            store.uiAudio.play(.tap)
                            store.pendingResetConfirmation = true
                        }
                        .font(GoalRushTheme.Typography.headline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .gameSurface(.panel)
                        .accessibilityIdentifier("settings-reset-account")

                        Text("Restart as a new player. This permanently removes campaign progress, Endless records, characters, upgrades, and Training Tokens from this device.")
                            .font(GoalRushTheme.Typography.caption)
                            .foregroundStyle(.white.opacity(0.72))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
                    .padding(.vertical, GoalRushTheme.Metrics.sectionSpacing)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .sheet(item: $selectedGroup) { group in
            SettingsGroupSheet(group: group)
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog("Reset your account?", isPresented: $store.pendingResetConfirmation, titleVisibility: .visible) {
            Button("Reset Account", role: .destructive) {
                store.uiAudio.requestFeedback(.warning)
                store.resetProgress()
            }
            Button("Cancel", role: .cancel) {
                store.uiAudio.requestFeedback(.selection)
            }
        } message: {
            Text("You will return to onboarding as a new player. Your progress cannot be recovered.")
        }
        .onChange(of: store.settings) { oldValue, newValue in
            if oldValue.hapticsEnabled {
                store.uiAudio.requestFeedback(.selection)
            }
            store.uiAudio.isHapticsEnabled = newValue.hapticsEnabled
            if !oldValue.hapticsEnabled, newValue.hapticsEnabled {
                store.uiAudio.requestFeedback(.selection)
            }
            newValue.save()
            store.uiAudio.isEnabled = newValue.soundEnabled
        }
    }

    @ViewBuilder
    private var preferenceGroups: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
                groupButtons
            }
        } else {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: GoalRushTheme.Metrics.sectionSpacing
            ) {
                groupButtons
            }
        }
    }

    @ViewBuilder
    private var groupButtons: some View {
            groupButton(.audio, subtitle: audioSummary, identifier: "settings-audio")
            groupButton(.accessibility, subtitle: accessibilitySummary, identifier: "settings-accessibility")
            groupButton(.support, subtitle: "Onboarding and help", identifier: "settings-support")
#if DEBUG
            groupButton(.developer, subtitle: "Testing shortcuts", identifier: "settings-developer")
#endif
    }

    private func groupButton(_ group: SettingsGroup, subtitle: String, identifier: String) -> some View {
        FloatingGameActionButton(
            title: group.title,
            subtitle: subtitle,
            systemImage: group.icon,
            accent: group.accent
        ) {
            open(group)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .accessibilityIdentifier(identifier)
    }

    private var audioSummary: String {
        store.settings.soundEnabled ? "Sound on" : "Sound off"
    }

    private var accessibilitySummary: String {
        store.settings.assistMode ? "Assist Mode on" : "Display and play assists"
    }

    private func open(_ group: SettingsGroup) {
        store.uiAudio.play(.tap)
        selectedGroup = group
    }

    private func goHome() {
        store.uiAudio.play(.tap)
        store.settings.save()
        store.route = .home
    }
}
