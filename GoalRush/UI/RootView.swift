import SwiftUI

struct RootView: View {
    @Environment(GameStore.self) private var store
    @Environment(RewardedAdService.self) private var rewardedAds
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var shouldResetRewardAfterBackground = false

    var body: some View {
        ZStack {
            GoalRushTheme.navy.ignoresSafeArea()
            Group {
                switch store.route {
                case .home: HomeView()
                case .campaign(let campaignRoute):
                    CampaignNavigationView(route: campaignRoute)
                case .endless: EndlessHubView()
                case .characters: CharacterRosterView()
                case .relics: RelicsView()
                case .relicForge: RelicForgeView()
                case .upgrades: UpgradesView()
                case .settings: SettingsView()
                case .onboarding: OnboardingView()
                case .trophies: TrophiesView()
                case .playing(let mode):
                    RunLaunchView(
                        mode: mode,
                        progress: store.progress,
                        settings: store.settings
                    )
                case .relicDrop(let result):
                    RelicDropRevealView(result: result)
                case .result(let result): ResultView(result: result)
                }
            }
            .id(store.route.transitionIdentity)
            if let celebration = store.celebrations.first {
                VStack {
                    CelebrationToast(celebration: celebration) {
                        store.dismissCelebration(celebration)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .padding(.top, 8)
                .zIndex(10)
            }
        }
        .tint(GoalRushTheme.gold)
        .font(GoalRushTheme.Typography.body)
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: store.celebrations)
        .sensoryFeedback(.selection, trigger: store.uiAudio.selectionFeedbackPulse)
        .sensoryFeedback(.success, trigger: store.uiAudio.successFeedbackPulse)
        .sensoryFeedback(.warning, trigger: store.uiAudio.warningFeedbackPulse)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.75), trigger: store.uiAudio.impactFeedbackPulse)
        .task {
            await Task.yield()
            await store.uiAudio.prepare()
            rewardedAds.configure()
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        if newPhase == .background, !rewardedAds.isPresenting {
            shouldResetRewardAfterBackground = true
        } else if newPhase == .active, shouldResetRewardAfterBackground {
            shouldResetRewardAfterBackground = false
            store.resetRewardedTokenBonusEligibility()
        }
    }
}

private extension GameStore.Route {
    var transitionIdentity: String {
        switch self {
        case .home: "home"
        case .campaign(let route): "campaign-\(route.transitionIdentity)"
        case .endless: "endless"
        case .characters: "characters"
        case .relics: "relics"
        case .relicForge: "relic-forge"
        case .upgrades: "upgrades"
        case .settings: "settings"
        case .onboarding: "onboarding"
        case .trophies: "trophies"
        case .playing(let mode): "playing-\(mode.transitionIdentity)"
        case .relicDrop(let result): "relic-drop-\(result.runID.uuidString)"
        case .result(let result): "result-\(result.mode.transitionIdentity)-\(result.didWin)-\(result.wave)"
        }
    }
}

private extension CampaignRoute {
    var transitionIdentity: String {
        switch self {
        case .planets(let page):
            "planets-\(page)"
        case .worldMap(let world, let focusLevel):
            "map-\(world.rawValue)-\(focusLevel ?? 0)"
        }
    }
}

private extension RunMode {
    var transitionIdentity: String {
        switch self {
        case .campaign(let level): "campaign-\(level)"
        case .endless: "endless"
        }
    }
}
