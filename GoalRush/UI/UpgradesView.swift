import SwiftUI

struct UpgradesView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showingInfo = false

    var body: some View {
        AtmosphericGameScreen(backgroundImage: "UpgradeBay") {
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
                        UpgradeTrackStage()
                    }
                    .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
                    .padding(.vertical, GoalRushTheme.Metrics.sectionSpacing)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .sheet(isPresented: $showingInfo) {
            UpgradeInfoView()
                .presentationDetents([.medium])
        }
        .onAppear { store.uiAudio.play(.whoosh, volume: 0.35, feedback: nil) }
    }

    private var tokenSummary: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing))
            : AnyLayout(HStackLayout(alignment: .center, spacing: GoalRushTheme.Metrics.standardSpacing))

        return layout {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(GoalRushTheme.navy)
                .frame(width: GoalRushTheme.Metrics.minimumTapTarget, height: GoalRushTheme.Metrics.minimumTapTarget)
                .background(
                    GoalRushTheme.gold,
                    in: ComicPanelShape(cut: GoalRushTheme.Metrics.smallRadius)
                )
                .overlay {
                    ComicPanelShape(cut: GoalRushTheme.Metrics.smallRadius)
                        .stroke(GoalRushTheme.ink, lineWidth: 2)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("WORKSHOP RESERVES")
                    .font(GoalRushTheme.Typography.captionEmphasized)
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.72))
                Text("Training Tokens")
                    .font(GoalRushTheme.Typography.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                TrainingTokenIcon(size: 28)
                Text(store.progress.trainingTokens.formatted())
                    .font(GoalRushTheme.Typography.metric(size: 24, relativeTo: .title2))
            }
            .foregroundStyle(.white)
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .background {
            ZStack {
                GoalRushTheme.surfaceRaised.opacity(0.97)
                ComicInkTexture(opacity: 0.09)
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 88))
                    .foregroundStyle(.white.opacity(0.025))
                    .offset(x: 92)
            }
            .clipShape(ComicPanelShape(cut: GoalRushTheme.Metrics.controlRadius))
        }
        .background {
            ComicPanelShape(cut: GoalRushTheme.Metrics.controlRadius)
                .fill(GoalRushTheme.ink)
                .offset(x: 4, y: 5)
        }
        .overlay {
            ComicPanelShape(cut: GoalRushTheme.Metrics.controlRadius)
                .stroke(GoalRushTheme.gold.opacity(0.48), lineWidth: GoalRushTheme.Metrics.strokeWidth)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(store.progress.trainingTokens) Training Tokens")
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
                Label("Levels are permanent and continue after Diamond", systemImage: "infinity")
                Label("Prestige at Levels 10, 20, 50, 100, and 200", systemImage: "medal.fill")
                Label("Levels cost up to \(UpgradeRules.sustainedCost.formatted()) tokens", systemImage: "hexagon.fill")
                Label("Prestige costs \(UpgradePrestigeRules.prestigeCost.formatted()) tokens", systemImage: "medal.fill")
            }
            .font(GoalRushTheme.Typography.headline)
            .foregroundStyle(.white)
            .padding(GoalRushTheme.Metrics.standardSpacing)
            .gameSurface(.panel)
        }
    }
}
