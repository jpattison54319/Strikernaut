import SwiftUI

struct TrophiesView: View {
    @Environment(GameStore.self) private var store
    @State private var showingTrophyList = false
    @State private var showingOverview = false

    var body: some View {
        AtmosphericGameScreen(backgroundImage: "MenuHero") {
            VStack(spacing: 0) {
                GameDestinationBar(
                    title: "Progress",
                    trailingText: "Overview",
                    onHome: goHome,
                    onInfo: showOverview
                )

                ScrollView {
                    LazyVStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
                        ProgressTrophyWidget(
                            playerProgress: store.progress,
                            showAll: showTrophyList
                        )
                        ProgressLifetimeWidget(
                            stats: store.progress.lifetimeStats
                        )
                    }
                    .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
                    .padding(.vertical, GoalRushTheme.Metrics.sectionSpacing)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .sheet(isPresented: $showingTrophyList) {
            TrophyListSheet()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showingOverview) {
            GameSheetScaffold(
                title: "Progress",
                subtitle: "Your complete Strikernaut record."
            ) {
                VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
                    Label(
                        "The three closest trophies stay on this page.",
                        systemImage: "trophy.fill"
                    )
                    Label(
                        "Open the trophy list for every achievement.",
                        systemImage: "chevron.right.circle.fill"
                    )
                    Label(
                        "Lifetime totals update when a run ends.",
                        systemImage: "chart.bar.fill"
                    )
                }
                .font(GoalRushTheme.Typography.headline)
                .foregroundStyle(.white)
                .padding(GoalRushTheme.Metrics.standardSpacing)
                .gameSurface(.panel)
            }
            .presentationDetents([.medium])
        }
    }

    private func goHome() {
        store.uiAudio.play(.tap)
        store.route = .home
    }

    private func showTrophyList() {
        store.uiAudio.play(.tap)
        showingTrophyList = true
    }

    private func showOverview() {
        store.uiAudio.play(.tap)
        showingOverview = true
    }
}
