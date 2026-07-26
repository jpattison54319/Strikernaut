import SwiftUI

struct CharacterRosterView: View {
    @Environment(GameStore.self) private var store
    @State private var showingInfo = false

    var body: some View {
        AtmosphericGameScreen(backgroundImage: "UpgradeBay") {
            VStack(spacing: 0) {
                GameDestinationBar(
                        title: "Characters",
                        trailingText: "Choose Your Hero",
                        onHome: goHome,
                        onInfo: showInfo
                )

                ScrollView {
                    LazyVStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
                    VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                        Text("BUILD POWER. UNLEASH THE MOMENT.")
                            .font(GoalRushTheme.Typography.captionEmphasized)
                            .tracking(1.1)
                            .foregroundStyle(GoalRushTheme.gold)
                        Text("Every hero charges a unique super ability by defeating enemies.")
                            .font(GoalRushTheme.Typography.headline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.82))
                    }
                    .padding(GoalRushTheme.Metrics.standardSpacing)
                    .frame(maxWidth: .infinity)
                    .gameSurface(.hud)

                    ForEach(CharacterCatalog.characters) { character in
                        CharacterRosterCard(
                            character: character,
                            isUnlocked: store.progress.unlockedCharacters.contains(character.id),
                            isSelected: store.progress.selectedCharacter == character.id,
                            select: { select(character.id) }
                        )
                    }
                    }
                    .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
                    .padding(.vertical, GoalRushTheme.Metrics.sectionSpacing)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .sheet(isPresented: $showingInfo) { CharacterInfoView() }
    }

    private func select(_ id: CharacterID) {
        guard store.selectCharacter(id) else {
            store.uiAudio.play(.locked)
            return
        }
        store.uiAudio.play(.tap)
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
