import SwiftUI

struct HomeClubhouseDock: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: GoalRushTheme.Metrics.compactSpacing))
            : AnyLayout(HStackLayout(spacing: GoalRushTheme.Metrics.compactSpacing))

        layout {
            HomeDockButton(
                title: "Characters",
                systemImage: "person.3.fill",
                identifier: "characters",
                action: openCharacters
            )
            HomeDockButton(
                title: "Upgrades",
                systemImage: "arrow.up.circle.fill",
                identifier: "upgrades",
                action: openUpgrades
            )
        }
        .padding(GoalRushTheme.Metrics.compactSpacing)
        .gameSurface(.hud)
    }

    private func openCharacters() {
        open(.characters)
    }

    private func openUpgrades() {
        open(.upgrades)
    }

    private func open(_ route: GameStore.Route) {
        store.uiAudio.play(.tap)
        store.route = route
    }
}
