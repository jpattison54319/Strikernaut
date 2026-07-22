import SwiftUI

struct RootView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            GoalRushTheme.navy.ignoresSafeArea()
            Group {
                switch store.route {
                case .home: HomeView()
                case .levels: LevelSelectView()
                case .endless: EndlessHubView()
                case .gear: GearView()
                case .upgrades: UpgradesView()
                case .settings: SettingsView()
                case .playing(let mode): GameContainerView(mode: mode, progress: store.progress, settings: store.settings)
                case .result(let result): ResultView(result: result)
                }
            }
            .id(store.route.transitionIdentity)
            .transition(.opacity.combined(with: .scale(scale: 0.99)))
        }
        .tint(GoalRushTheme.gold)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: store.route)
        .sensoryFeedback(trigger: store.route) { _, _ in
            store.settings.hapticsEnabled ? .selection : nil
        }
    }
}

private extension GameStore.Route {
    var transitionIdentity: String {
        switch self {
        case .home: "home"
        case .levels: "levels"
        case .endless: "endless"
        case .gear: "gear"
        case .upgrades: "upgrades"
        case .settings: "settings"
        case .playing(let mode): "playing-\(mode.transitionIdentity)"
        case .result(let result): "result-\(result.mode.transitionIdentity)-\(result.didWin)-\(result.wave)"
        }
    }
}

private extension RunMode {
    var transitionIdentity: String {
        switch self {
        case .campaign(let level): "campaign-\(level)"
        case .endless(let world): "endless-\(world.rawValue)"
        }
    }
}
