import SwiftUI

private enum HomeSheet: String, Identifiable {
    case dailyReward
    case missions

    var id: String { rawValue }
}

struct HomeView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var activeSheet: HomeSheet?

    var body: some View {
        AtmosphericGameScreen(backgroundImage: "MenuHero") {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    accessibilityStage
                } else {
                    commandStage
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home-root")
        }
        .onAppear { store.refreshMissionsIfNeeded() }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .dailyReward:
                GameSheetScaffold(
                    title: "Daily Reward",
                    subtitle: store.isDailyRewardClaimable
                        ? "Preview today's reward, then collect when you're ready."
                        : "Today's reward is safely in your locker."
                ) {
                    DailyRewardCard()
                }
                .presentationDetents([.medium, .large])

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

    private var commandStage: some View {
        VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            topHUD
            brand

            Spacer(minLength: GoalRushTheme.Metrics.compactSpacing)

            HStack(alignment: .center, spacing: GoalRushTheme.Metrics.standardSpacing) {
                VStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
                    dailySatellite
                    missionsSatellite
                }

                Spacer(minLength: 72)

                VStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
                    campaignSatellite
                    endlessSatellite
                }
            }

            Spacer(minLength: GoalRushTheme.Metrics.compactSpacing)

            continueHero
            clubhouseDock
        }
        .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
        .padding(.vertical, GoalRushTheme.Metrics.compactSpacing)
    }

    private var accessibilityStage: some View {
        ScrollView {
            VStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
                topHUD
                brand
                continueHero

                VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                    accessibilityAction(
                        title: "Daily",
                        subtitle: dailySubtitle,
                        systemImage: "gift.fill",
                        badge: store.isDailyRewardClaimable ? "+\(store.nextDailyReward)" : nil,
                        accent: GoalRushTheme.gold
                    ) { activeSheet = .dailyReward }
                    .accessibilityIdentifier("daily-chest")

                    accessibilityAction(
                        title: "Missions",
                        subtitle: missionsSubtitle,
                        systemImage: "target",
                        badge: missionBadge,
                        accent: GoalRushTheme.cyan
                    ) { activeSheet = .missions }
                    .accessibilityIdentifier("missions")
                }

                VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                    accessibilityAction(
                        title: "Campaign",
                        subtitle: campaignStatus,
                        systemImage: "map.fill",
                        accent: GoalRushTheme.cyan
                    ) { openCampaign() }
                    .accessibilityIdentifier("play")

                    accessibilityAction(
                        title: "Endless",
                        subtitle: endlessStatus,
                        systemImage: "infinity",
                        accent: GoalRushTheme.orange
                    ) { openEndless() }
                    .accessibilityIdentifier("endless")
                }

                clubhouseDock
            }
            .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
            .padding(.vertical, GoalRushTheme.Metrics.standardSpacing)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var topHUD: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                    tokenHUD
                        .frame(maxWidth: .infinity, alignment: .leading)
                    settingsHUD
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                    tokenHUD
                    Spacer(minLength: GoalRushTheme.Metrics.compactSpacing)
                    settingsHUD
                }
            }
        }
    }

    private var tokenHUD: some View {
        Label("\(store.progress.trainingTokens)", systemImage: "hexagon.fill")
            .font(.headline.bold().monospacedDigit())
            .foregroundStyle(GoalRushTheme.gold)
            .padding(.horizontal, GoalRushTheme.Metrics.standardSpacing)
            .frame(minHeight: GoalRushTheme.Metrics.minimumTapTarget)
            .gameSurface(.hud)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("\(store.progress.trainingTokens) Training Tokens")
    }

    private var settingsHUD: some View {
        Button {
            store.uiAudio.play(.tap)
            store.route = .settings
        } label: {
            Label("Settings", systemImage: "gearshape.fill")
                .font(.subheadline.bold())
                .padding(.horizontal, GoalRushTheme.Metrics.standardSpacing)
                .frame(minHeight: GoalRushTheme.Metrics.minimumTapTarget)
                .gameSurface(.hud)
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityIdentifier("settings")
    }

    private var brand: some View {
        VStack(spacing: 1) {
            Text("GOAL RUSH")
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .tracking(1.6)
                .foregroundStyle(.white)
                .shadow(color: GoalRushTheme.blue.opacity(0.8), radius: 10)
            Text("STADIUM COMMAND")
                .font(.caption2.weight(.heavy))
                .tracking(2)
                .foregroundStyle(GoalRushTheme.cyan)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private var dailySatellite: some View {
        FloatingGameActionButton(
            title: "Daily",
            subtitle: dailySubtitle,
            systemImage: "gift.fill",
            badge: store.isDailyRewardClaimable ? "+\(store.nextDailyReward)" : nil,
            accent: GoalRushTheme.gold
        ) {
            store.uiAudio.play(.tap)
            activeSheet = .dailyReward
        }
        .accessibilityIdentifier("daily-chest")
    }

    private var missionsSatellite: some View {
        FloatingGameActionButton(
            title: "Missions",
            subtitle: missionsSubtitle,
            systemImage: "target",
            badge: missionBadge,
            accent: GoalRushTheme.cyan
        ) {
            store.uiAudio.play(.tap)
            activeSheet = .missions
        }
        .accessibilityIdentifier("missions")
    }

    private var campaignSatellite: some View {
        FloatingGameActionButton(
            title: "Campaign",
            subtitle: campaignStatus,
            systemImage: "map.fill",
            accent: GoalRushTheme.cyan
        ) { openCampaign() }
        .accessibilityIdentifier("play")
    }

    private var endlessSatellite: some View {
        FloatingGameActionButton(
            title: "Endless",
            subtitle: endlessStatus,
            systemImage: "infinity",
            accent: GoalRushTheme.orange
        ) { openEndless() }
        .accessibilityIdentifier("endless")
    }

    private var continueHero: some View {
        Button(action: performPrimaryAction) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.compactSpacing) {
                        Label(primaryEyebrow, systemImage: "play.fill")
                            .font(.headline.weight(.heavy))
                        Text(primaryTitle)
                            .font(.title3.weight(.heavy))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                        Image(systemName: "play.fill")
                            .font(.title2.bold())
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.88), in: .circle)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(primaryEyebrow)
                                .font(.caption.weight(.heavy))
                                .tracking(1.1)
                            Text(primaryTitle)
                                .font(.headline.weight(.heavy))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: GoalRushTheme.Metrics.compactSpacing)
                        Image(systemName: "chevron.right")
                            .font(.headline.bold())
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .buttonStyle(GameLaunchButtonStyle())
        .accessibilityIdentifier("continue-hero")
    }

    private var clubhouseDock: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                    clubhouseButtons
                }
            } else {
                HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                    clubhouseButtons
                }
            }
        }
        .padding(GoalRushTheme.Metrics.compactSpacing)
        .gameSurface(.hud)
    }

    @ViewBuilder
    private var clubhouseButtons: some View {
        dockButton(title: "Locker", systemImage: "tshirt.fill", identifier: "gear") {
            store.route = .gear
        }
        dockButton(title: "Upgrades", systemImage: "arrow.up.circle.fill", identifier: "upgrades") {
            store.route = .upgrades
        }
        dockButton(title: "Progress", systemImage: "trophy.fill", identifier: "trophies") {
            store.route = .trophies
        }
    }

    private func dockButton(
        title: String,
        systemImage: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            store.uiAudio.play(.tap)
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.headline.bold())
                Text(title)
                    .font(.caption.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: GoalRushTheme.Metrics.minimumTapTarget)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityIdentifier(identifier)
    }

    private func accessibilityAction(
        title: String,
        subtitle: String,
        systemImage: String,
        badge: String? = nil,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            store.uiAudio.play(.tap)
            action()
        } label: {
            VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.compactSpacing) {
                Label {
                    Text(title)
                        .foregroundStyle(.white)
                } icon: {
                    Image(systemName: systemImage)
                        .foregroundStyle(accent)
                }
                .font(.headline.bold())

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))

                if let badge {
                    GameStatusBadge(text: badge, tone: .attention)
                }
            }
            .multilineTextAlignment(.leading)
            .foregroundStyle(.white)
            .padding(GoalRushTheme.Metrics.standardSpacing)
            .frame(maxWidth: .infinity, minHeight: GoalRushTheme.Metrics.minimumTapTarget)
            .gameSurface(.panel)
        }
        .buttonStyle(.plain)
    }

    private var primaryAction: HomePrimaryAction {
        HomePresentation.primaryAction(progress: store.progress)
    }

    private var primaryEyebrow: String {
        switch primaryAction {
        case .campaign: "NEXT MATCH"
        case .endless: "CAMPAIGN COMPLETE"
        }
    }

    private var primaryTitle: String {
        switch primaryAction {
        case .campaign(let levelNumber):
            guard let level = GameContent.levels.first(where: { $0.number == levelNumber }) else {
                return "Continue Campaign"
            }
            return "Level \(level.number): \(level.name)"
        case .endless:
            return "Chase Your Endless Best"
        }
    }

    private var dailySubtitle: String {
        store.isDailyRewardClaimable ? "Reward ready" : "Claimed today"
    }

    private var missionsSubtitle: String {
        let count = HomePresentation.completedMissionCount(store.progress.missions)
        return count > 0 ? "\(count) ready to claim" : "View objectives"
    }

    private var missionBadge: String? {
        let count = HomePresentation.completedMissionCount(store.progress.missions)
        return count > 0 ? "\(count)" : nil
    }

    private var campaignStatus: String {
        let completed = store.progress.levelRecords.values.filter(\.completed).count
        return "\(completed)/\(GameContent.levels.count) cleared"
    }

    private var endlessStatus: String {
        let record = store.progress.endlessRecords.values.max(by: { $0.bestWave < $1.bestWave }) ?? .empty
        return record.bestWave > 0 ? "Best wave \(record.bestWave)" : "New run ready"
    }

    private func performPrimaryAction() {
        store.uiAudio.play(.tap)
        switch primaryAction {
        case .campaign(let level): store.start(level: level)
        case .endless: store.route = .endless
        }
    }

    private func openCampaign() {
        store.uiAudio.play(.tap)
        store.route = .levels
    }

    private func openEndless() {
        store.uiAudio.play(.tap)
        store.route = .endless
    }
}
