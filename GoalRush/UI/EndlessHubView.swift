import SwiftUI

struct EndlessHubView: View {
    @Environment(GameStore.self) private var store
    @State private var showingInfo = false

    var body: some View {
        AtmosphericGameScreen(backgroundImage: selectedWorld.heroAsset) {
            VStack(spacing: 0) {
                destinationBar

                ScrollView {
                    EndlessSelectionStage(
                        world: selectedWorld,
                        record: record,
                        progress: store.progress,
                        onSelectWorld: selectWorld
                    )
                    .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
                    .padding(.vertical, GoalRushTheme.Metrics.sectionSpacing)
                }
                .scrollBounceBehavior(.basedOnSize)

                startButton
                    .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
                    .padding(.bottom, GoalRushTheme.Metrics.standardSpacing)
            }
        }
        .sheet(isPresented: $showingInfo) {
            EndlessRulesSheet()
                .presentationDetents([.medium])
        }
        .onAppear(perform: ensureSelectedWorldIsUnlocked)
    }

    private var destinationBar: some View {
        GameDestinationBar(
            title: "Endless",
            trailingText: "Rules",
            onHome: goHome,
            onInfo: showRules
        )
    }

    private var startButton: some View {
        Button(action: startEndless) {
            Label(startButtonTitle, systemImage: "infinity")
        }
        .buttonStyle(GameLaunchButtonStyle())
        .accessibilityIdentifier("start-endless")
    }

    private var selectedWorld: WorldDefinition {
        GameContent.world(store.selectedWorld)
    }

    private var record: EndlessRecord {
        store.progress.endlessRecord(for: store.selectedWorld)
    }

    private var startButtonTitle: String {
        record.bestWave > 0
            ? "Start \(selectedWorld.name) Run • Best W\(record.bestWave)"
            : "Start \(selectedWorld.name) Run"
    }

    private func ensureSelectedWorldIsUnlocked() {
        guard !GameContent.isWorldUnlocked(store.selectedWorld, progress: store.progress) else { return }
        store.selectedWorld = .earth
    }

    private func selectWorld(_ world: WorldID) {
        guard store.selectWorld(world) else { return }
        store.uiAudio.play(.tap)
    }

    private func startEndless() {
        store.uiAudio.play(.tap)
        store.startEndless(world: store.selectedWorld)
    }

    private func showRules() {
        store.uiAudio.play(.tap)
        showingInfo = true
    }

    private func goHome() {
        store.uiAudio.play(.tap)
        store.route = .home
    }
}
