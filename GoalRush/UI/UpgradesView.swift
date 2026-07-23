import SwiftUI

struct UpgradesView: View {
    @Environment(GameStore.self) private var store
    @State private var selectedTrack: UpgradeTrack?
    @State private var showingInfo = false

    var body: some View {
        AtmosphericGameScreen(backgroundImage: "MenuHero") {
            VStack(spacing: 0) {
                GameDestinationBar(
                    title: "Upgrades",
                    trailingText: "How It Works",
                    onHome: goHome,
                    onInfo: showInfo
                )

                ScrollView {
                    VStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
                        tokenSummary
                        UpgradeTrackStage { track in
                            store.uiAudio.play(.tap)
                            selectedTrack = track
                        }
                    }
                    .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
                    .padding(.vertical, GoalRushTheme.Metrics.sectionSpacing)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .sheet(item: $selectedTrack) { track in
            GameSheetScaffold(
                title: UpgradeRules.title(for: track),
                subtitle: UpgradePresentation.benefit(for: track)
            ) {
                UpgradeCardView(track: track)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("upgrade-detail")
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showingInfo) {
            UpgradeInfoView()
                .presentationDetents([.medium])
        }
        .onAppear { store.uiAudio.play(.whoosh, volume: 0.35) }
    }

    private var tokenSummary: some View {
        HStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            Image(systemName: "hexagon.fill")
                .font(.title2.bold())
                .foregroundStyle(GoalRushTheme.gold)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("TRAINING TOKENS")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.68))
                Text(store.progress.trainingTokens.formatted())
                    .font(.title2.weight(.heavy).monospacedDigit())
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 0)
            Text("Choose a track")
                .font(.subheadline.bold())
                .foregroundStyle(GoalRushTheme.cyan)
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .gameSurface(.hud)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(store.progress.trainingTokens) Training Tokens. Choose a track.")
    }

    private func goHome() {
        store.uiAudio.play(.tap)
        store.route = .home
    }

    private func showInfo() {
        store.uiAudio.play(.tap)
        showingInfo = true
    }
}

private struct UpgradeInfoView: View {
    var body: some View {
        GameSheetScaffold(title: "Upgrades", subtitle: "Permanent improvements for every mode.") {
            VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
                Label("Upgrades are permanent", systemImage: "checkmark.shield.fill")
                Label("Active in Campaign and Endless", systemImage: "gamecontroller.fill")
                Label("Details show current and next values", systemImage: "arrow.right")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding(GoalRushTheme.Metrics.standardSpacing)
            .gameSurface(.panel)
        }
    }
}
