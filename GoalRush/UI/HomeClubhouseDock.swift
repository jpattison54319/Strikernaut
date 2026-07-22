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
                title: "Locker",
                systemImage: "tshirt.fill",
                identifier: "gear",
                action: openLocker
            )
            HomeDockButton(
                title: "Upgrades",
                systemImage: "arrow.up.circle.fill",
                identifier: "upgrades",
                action: openUpgrades
            )
            HomeDockButton(
                title: "Progress",
                systemImage: "trophy.fill",
                identifier: "trophies",
                action: openProgress
            )
        }
        .padding(GoalRushTheme.Metrics.compactSpacing)
        .gameSurface(.hud)
    }

    private func openLocker() {
        open(.gear)
    }

    private func openUpgrades() {
        open(.upgrades)
    }

    private func openProgress() {
        open(.trophies)
    }

    private func open(_ route: GameStore.Route) {
        store.uiAudio.play(.tap)
        store.route = route
    }
}
