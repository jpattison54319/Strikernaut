import SwiftUI

struct ResultView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var appeared = false

    let result: RunResult

    var body: some View {
        AtmosphericGameScreen(backgroundImage: backgroundImage) {
            ZStack {
                result.world.secondaryColor.opacity(0.12)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                if celebrationEffectsAllowed && isNotableRun && result.relicEarned == nil {
                    ResultBurst(accent: result.world.accentColor)
                        .scaleEffect(appeared ? 1 : 0.35)
                        .opacity(appeared ? 1 : 0)
                        .animation(
                            .spring(duration: 0.75, bounce: 0.26),
                            value: appeared
                        )
                        .accessibilityHidden(true)
                    ConfettiBurst(accent: result.world.accentColor)
                }

                ScrollView {
                    LazyVStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                        Spacer(minLength: GoalRushTheme.Metrics.compactSpacing)

                        ResultHeroCard(
                            icon: heroIcon,
                            iconColor: heroColor,
                            title: heroTitle,
                            accessibilityTitle: heroAccessibilityTitle,
                            subtitle: heroSubtitle,
                            isNewBest: result.newBestWave || result.newBestScore,
                            starCount: starCount,
                            appeared: appeared
                        )

                        ResultStatsCard(result: result)

                        if result.mode.isEndless {
                            if let relic = result.relicEarned {
                                EndlessRelicRewardCard(relic: relic)
                            } else if EndlessRelicRules.rewardMilestone(
                                forWaveReached: result.wave
                            ) == nil {
                                EndlessRelicProgressHint()
                            }
                        }

                        if result.characterEarned != nil {
                            characterReward
                        }

                        actions
                        Spacer(minLength: GoalRushTheme.Metrics.sectionSpacing)
                    }
                    .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .onAppear {
            appeared = true
            guard result.relicEarned == nil else { return }
            if isNotableRun {
                store.uiAudio.play(.fanfare, feedback: nil)
            } else {
                store.uiAudio.play(.locked, volume: 0.4, feedback: nil)
            }
        }
        .sensoryFeedback(trigger: appeared) { _, isVisible in
            guard isVisible,
                  result.relicEarned == nil,
                  store.settings.hapticsEnabled else {
                return nil
            }
            return isNotableRun ? .success : .warning
        }
    }

    private var characterReward: some View {
        let character = result.characterEarned.map(CharacterCatalog.character)
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(
                VStackLayout(
                    alignment: .leading,
                    spacing: GoalRushTheme.Metrics.standardSpacing
                )
            )
            : AnyLayout(
                HStackLayout(
                    alignment: .center,
                    spacing: GoalRushTheme.Metrics.standardSpacing
                )
            )

        return layout {
            if let character {
                Image(character.assetStem + "Roster")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 76, height: 84)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Label("New hero", systemImage: "sparkles")
                    .font(GoalRushTheme.Typography.captionEmphasized)
                    .foregroundStyle(GoalRushTheme.gold)
                Text(character?.name ?? "New Hero")
                    .font(GoalRushTheme.Typography.title2)
                Text(character?.abilityName ?? "Unique ability")
                    .font(GoalRushTheme.Typography.subheadline)
                    .foregroundStyle(.white.opacity(0.62))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .gameSurface(.panel)
        .accessibilityElement(children: .contain)
    }

    private var actions: some View {
        let destinationLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(
                VStackLayout(spacing: GoalRushTheme.Metrics.standardSpacing)
            )
            : AnyLayout(
                HStackLayout(
                    alignment: .top,
                    spacing: GoalRushTheme.Metrics.standardSpacing
                )
            )

        return VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            Button(primaryTitle, systemImage: "play.fill", action: primaryAction)
                .buttonStyle(GameLaunchButtonStyle())
                .accessibilityIdentifier("result-primary")

            destinationLayout {
                resultDestination(
                    title: result.mode.isEndless ? "Relics" : "Upgrades",
                    systemImage: result.mode.isEndless ? "diamond.fill" : "arrow.up",
                    accent: GoalRushTheme.cyan,
                    identifier: result.mode.isEndless
                        ? "result-more-relics"
                        : "result-more-upgrades",
                    action: result.mode.isEndless ? openRelics : openUpgrades
                )
                resultDestination(
                    title: result.mode.isEndless ? "Endless" : "Map",
                    systemImage: "map.fill",
                    accent: result.world.accentColor,
                    identifier: "result-more-map",
                    action: openModeSelection
                )
                resultDestination(
                    title: "Home",
                    systemImage: "house.fill",
                    accent: GoalRushTheme.cyan,
                    identifier: "result-more-home",
                    action: openHome
                )
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func resultDestination(
        title: String,
        systemImage: String,
        accent: Color,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(GoalRushTheme.Typography.title3)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(.black.opacity(0.56), in: .circle)
                    .overlay {
                        Circle().stroke(accent.opacity(0.82), lineWidth: 2)
                    }
                    .shadow(color: accent.opacity(0.30), radius: 8, y: 4)

                Text(title)
                    .font(GoalRushTheme.Typography.captionEmphasized)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }

    private var isNotableRun: Bool {
        result.didWin || result.newBestWave || result.newBestScore
    }

    private var celebrationEffectsAllowed: Bool {
        !reduceMotion && !store.settings.reducedFlashes
    }

    private var backgroundImage: String {
        GameContent.world(result.world).heroAsset
    }

    private var heroIcon: String {
        if result.isFirstClear { return "star.circle.fill" }
        if result.mode.isEndless { return "infinity.circle.fill" }
        return result.didWin
            ? "trophy.fill"
            : "arrow.counterclockwise.circle.fill"
    }

    private var heroColor: Color {
        if result.mode.isEndless { return result.world.accentColor }
        return result.didWin ? GoalRushTheme.gold : GoalRushTheme.orange
    }

    private var heroTitle: String {
        if result.isFirstClear { return "FIRST CLEAR!" }
        if result.mode.isEndless {
            return "WAVE \(GameNumberFormatter.compact(result.wave))"
        }
        return result.didWin ? "LEVEL CLEAR" : "GAME OVER"
    }

    private var heroSubtitle: String {
        switch result.mode {
        case .endless:
            "\(GameContent.world(result.world).name) • Powers reset"
        case .campaign(let level):
            result.didWin
                ? GameContent.level(level).name
                : "Tokens kept • Upgrade and retry"
        }
    }

    private var heroAccessibilityTitle: String {
        if result.mode.isEndless {
            return "Wave \(GameNumberFormatter.exact(result.wave))"
        }
        return heroTitle
    }

    private var starCount: Int? {
        guard result.didWin, !result.mode.isEndless else { return nil }
        return StarRating.stars(staminaFraction: result.staminaFraction)
    }

    private var primaryTitle: String {
        if !result.didWin { return "Retry" }

        return switch result.mode {
        case .endless:
            "Run It Back"
        case .campaign(let level):
            level < GameContent.levels.count ? "Play Next Level" : "Play Again"
        }
    }

    private func primaryAction() {
        store.uiAudio.play(.tap)
        store.continueAfterResult(result)
    }

    private func openUpgrades() {
        store.uiAudio.play(.tap)
        store.route = .upgrades
    }

    private func openHome() {
        store.uiAudio.play(.tap)
        store.route = .home
    }

    private func openRelics() {
        store.uiAudio.play(.tap)
        store.route = .relics
    }

    private func openModeSelection() {
        store.uiAudio.play(.tap)
        switch result.mode {
        case .endless:
            store.route = .endless
        case .campaign(let level):
            store.openWorldMap(result.world, focusLevel: level)
        }
    }
}

private struct ResultBurst: View {
    let accent: Color

    var body: some View {
        ZStack {
            ForEach(0..<18, id: \.self) { index in
                Capsule()
                    .fill(index.isMultiple(of: 2) ? GoalRushTheme.gold : accent)
                    .frame(
                        width: 5,
                        height: index.isMultiple(of: 3) ? 34 : 22
                    )
                    .offset(y: -130)
                    .rotationEffect(.degrees(Double(index) * 20))
            }

            Circle()
                .stroke(accent.opacity(0.32), lineWidth: 2)
                .frame(width: 230, height: 230)
        }
        .offset(y: -180)
    }
}
