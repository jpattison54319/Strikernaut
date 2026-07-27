import SwiftUI

struct EndlessHubView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        AtmosphericGameScreen(backgroundImage: "EndlessHub") {
            VStack(spacing: 0) {
                GameDestinationBar(
                    title: "Endless",
                    onHome: goHome
                )

                ScrollView {
                    EndlessRunStatsView(record: store.progress.endlessRecord)
                        .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
                        .padding(.top, GoalRushTheme.Metrics.sectionSpacing)
                }
                .scrollBounceBehavior(.basedOnSize)

                Button("Start Endless", systemImage: "infinity", action: startEndless)
                    .buttonStyle(GameLaunchButtonStyle())
                    .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
                    .padding(.bottom, GoalRushTheme.Metrics.standardSpacing)
                    .accessibilityIdentifier("start-endless")
            }
        }
    }

    private func startEndless() {
        store.uiAudio.play(.tap)
        store.startEndless()
    }

    private func goHome() {
        store.uiAudio.play(.tap)
        store.route = .home
    }
}
