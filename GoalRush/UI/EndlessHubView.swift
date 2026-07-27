import SwiftUI

struct EndlessHubView: View {
    @Environment(GameStore.self) private var store
    @State private var showingInfo = false

    var body: some View {
        AtmosphericGameScreen(backgroundImage: openingWorld.heroAsset) {
            VStack(spacing: 0) {
                destinationBar

                ScrollView {
                    EndlessSelectionStage(
                        record: record,
                        progress: store.progress
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

    private var openingWorld: WorldDefinition {
        GameContent.world(EndlessRules.world(for: 1))
    }

    private var record: EndlessRecord {
        store.progress.endlessRecord
    }

    private var startButtonTitle: String {
        record.bestWave > 0
            ? "Start Endless • Best W\(record.bestWave)"
            : "Start Endless"
    }

    private func startEndless() {
        store.uiAudio.play(.tap)
        store.startEndless()
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
