import SwiftUI

struct LevelSelectView: View {
    @Environment(GameStore.self) private var store
    @State private var selectedPreviewLevel: LevelDefinition?
    @State private var showingCampaignInfo = false

    var body: some View {
        AtmosphericGameScreen(backgroundImage: selectedWorld.heroAsset) {
            VStack(spacing: 0) {
                destinationBar

                ScrollView {
                    CampaignSelectionStage(
                        world: selectedWorld,
                        progress: store.progress,
                        onSelectWorld: selectWorld,
                        onSelectLevel: selectLevel
                    )
                    .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
                    .padding(.vertical, GoalRushTheme.Metrics.sectionSpacing)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .sheet(item: $selectedPreviewLevel) { level in
            CampaignLevelPreview(
                level: level,
                record: store.progress.levelRecords[level.number],
                maximumStamina: PlayerStats(progress: store.progress).maxStamina,
                onPlay: { start(level) }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingCampaignInfo) {
            CampaignInfoSheet(world: selectedWorld)
                .presentationDetents([.medium])
        }
        .onAppear(perform: ensureSelectedWorldIsUnlocked)
        .onChange(of: store.selectedWorld) { _, _ in
            selectedPreviewLevel = nil
        }
        .sensoryFeedback(trigger: store.selectedWorld) { _, _ in
            store.settings.hapticsEnabled ? .selection : nil
        }
    }

    private var destinationBar: some View {
        GameDestinationBar(
            title: "Campaign",
            trailingText: "\(store.progress.trainingTokens) Tokens",
            onHome: goHome,
            onInfo: showCampaignInfo
        )
    }

    private var selectedWorld: WorldDefinition {
        GameContent.world(store.selectedWorld)
    }

    private func ensureSelectedWorldIsUnlocked() {
        guard !GameContent.isWorldUnlocked(store.selectedWorld, progress: store.progress) else { return }
        store.selectedWorld = .earth
    }

    private func selectWorld(_ world: WorldID) {
        guard store.selectWorld(world) else { return }
        store.uiAudio.play(.tap)
    }

    private func selectLevel(_ level: LevelDefinition) {
        store.uiAudio.play(.tap)
        selectedPreviewLevel = level
    }

    private func start(_ level: LevelDefinition) {
        store.uiAudio.play(.tap)
        store.start(level: level.number)
    }

    private func showCampaignInfo() {
        store.uiAudio.play(.tap)
        showingCampaignInfo = true
    }

    private func goHome() {
        store.uiAudio.play(.tap)
        store.route = .home
    }
}
