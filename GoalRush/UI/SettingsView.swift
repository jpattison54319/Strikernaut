import SwiftUI

struct SettingsView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section("Audio & Feedback") {
                    Toggle("Music", isOn: $store.settings.musicEnabled)
                    Toggle("Sound Effects", isOn: $store.settings.soundEnabled)
                    Toggle("Haptics", isOn: $store.settings.hapticsEnabled)
                }
                Section("Accessibility") {
                    Toggle("Reduce Flashes", isOn: $store.settings.reducedFlashes)
                    Toggle("Assist Mode", isOn: $store.settings.assistMode)
                    Text("Assist Mode widens shots and slows hostile projectiles without reducing rewards.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Your Journey") {
                    LabeledContent("Runs played", value: "\(store.progress.lifetimeStats.totalRuns)")
                    LabeledContent("Endless waves cleared", value: "\(store.progress.lifetimeStats.totalWavesCleared)")
                    LabeledContent("Best combo", value: "×\(store.progress.lifetimeStats.bestCombo)")
                    LabeledContent("Lifetime tokens", value: store.progress.lifetimeStats.totalTokensEarned.formatted())
                }
                Section {
                    Button("Replay Onboarding", systemImage: "play.rectangle") {
                        store.progress.hasSeenOnboarding = false
                        store.saveProgress()
                        store.route = .onboarding
                    }
                    .accessibilityIdentifier("settings-replay-onboarding")
                }
                Section {
                    Button("Reset Progress", role: .destructive) { store.pendingResetConfirmation = true }
                } footer: {
                    Text("This permanently removes campaign progress, Endless records, gear, upgrades, and Training Tokens from this device.")
                }
#if DEBUG
                Section("Developer") {
                    Button("Grant 1,000 Tokens") {
                        store.progress.trainingTokens += 1_000
                        store.saveProgress()
                    }
                    Button("Unlock All Levels") {
                        store.progress.highestUnlockedLevel = GameContent.levels.count
                        store.saveProgress()
                    }
                    Button("Unlock All Gear") {
                        store.progress.unlockedGear = Set(GearID.allCases)
                        store.saveProgress()
                    }
                }
#endif
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Home", systemImage: "chevron.left") {
                        store.uiAudio.play(.tap)
                        store.settings.save()
                        store.route = .home
                    }
                }
            }
            .confirmationDialog("Reset all progress?", isPresented: $store.pendingResetConfirmation, titleVisibility: .visible) {
                Button("Reset Progress", role: .destructive) { store.resetProgress() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Campaign progress, Endless records, gear, upgrades, and Training Tokens cannot be recovered.")
            }
            .onChange(of: store.settings) { _, newValue in
                newValue.save()
                store.uiAudio.isEnabled = newValue.soundEnabled
            }
        }
    }
}
