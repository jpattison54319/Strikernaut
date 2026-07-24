import SwiftUI

struct HomeView: View {
    @Environment(GameStore.self) private var store
    @State private var activeSheet: HomeSheet?

    var body: some View {
        AtmosphericGameScreen(backgroundImage: "MenuHero") {
            HomeStage(
                onDaily: openDailyReward,
                onMissions: openMissions
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home-root")
        }
        .onAppear(perform: refreshMissions)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .dailyReward:
                GameSheetScaffold(
                    title: "Daily Reward",
                    subtitle: store.isDailyRewardClaimable
                        ? "Collect today and work toward the Day 7 prize."
                        : "Today's reward is collected. Come back tomorrow."
                ) {
                    DailyRewardCard()
                }
                .presentationDetents([.large])

            case .missions:
                GameSheetScaffold(
                    title: "Daily Missions",
                    subtitle: "Complete match objectives and claim their token rewards."
                ) {
                    MissionsStrip()
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("missions-sheet")
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func refreshMissions() {
        store.refreshMissionsIfNeeded()
    }

    private func openDailyReward() {
        store.uiAudio.play(.tap)
        activeSheet = .dailyReward
    }

    private func openMissions() {
        store.uiAudio.play(.tap)
        activeSheet = .missions
    }
}
