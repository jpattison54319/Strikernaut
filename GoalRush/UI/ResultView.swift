import SwiftUI

struct ResultView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    let result: RunResult

    var body: some View {
        AtmosphericGameScreen(backgroundImage: backgroundImage) {
            ZStack {
                result.mode.world.secondaryColor.opacity(0.12)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                if celebrationEffectsAllowed && isNotableRun {
                    ResultBurst(accent: result.mode.world.accentColor)
                        .scaleEffect(appeared ? 1 : 0.35)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(duration: 0.75, bounce: 0.26), value: appeared)
                        .accessibilityHidden(true)
                    ConfettiBurst(accent: result.mode.world.accentColor)
                }

                ScrollView {
                    VStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
                        Spacer(minLength: GoalRushTheme.Metrics.sectionSpacing)
                        hero
                        newBestStatus
                        stars
                        resultStats
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
            if isNotableRun {
                store.uiAudio.play(.fanfare, feedback: nil)
            } else {
                store.uiAudio.play(.locked, volume: 0.4, feedback: nil)
            }
        }
        .sensoryFeedback(trigger: appeared) { _, isVisible in
            guard isVisible, store.settings.hapticsEnabled else { return nil }
            return isNotableRun ? .success : .warning
        }
    }

    private var hero: some View {
        VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            Image(systemName: heroIcon)
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(heroColor)
                .symbolEffect(.bounce, value: appeared && !reduceMotion)
                .shadow(color: heroColor.opacity(0.40), radius: 18)
                .accessibilityHidden(true)
            VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                Text(heroTitle)
                    .font(GoalRushTheme.Typography.display)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("result-title")
                Text(heroSubtitle)
                    .font(GoalRushTheme.Typography.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(GoalRushTheme.Metrics.sectionSpacing)
        .frame(maxWidth: .infinity)
        .gameSurface(.modal)
    }

    @ViewBuilder
    private var newBestStatus: some View {
        if result.newBestWave || result.newBestScore {
            GameStatusBadge(text: "NEW BEST!", tone: .attention)
                .scaleEffect(appeared ? 1 : 0.4)
                .animation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.5).delay(0.35), value: appeared)
                .accessibilityIdentifier("result-new-best")
        }
    }

    @ViewBuilder
    private var stars: some View {
        if result.didWin && !result.mode.isEndless {
            HStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < StarRating.stars(staminaFraction: result.staminaFraction) ? "star.fill" : "star")
                        .font(GoalRushTheme.Typography.title)
                        .foregroundStyle(GoalRushTheme.gold)
                        .scaleEffect(appeared ? 1 : 0.2)
                        .animation(
                            reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.55).delay(0.25 + Double(index) * 0.14),
                            value: appeared
                        )
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(StarRating.stars(staminaFraction: result.staminaFraction)) of 3 stars")
            .accessibilityIdentifier("result-stars")
        }
    }

    private var resultStats: some View {
        VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            HStack {
                HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                    TrainingTokenIcon(size: 23)
                    Text("Training Tokens")
                }
                    .foregroundStyle(GoalRushTheme.gold)
                Spacer()
                HStack(spacing: 4) {
                    Text("+")
                        .font(GoalRushTheme.Typography.title2)
                        .foregroundStyle(GoalRushTheme.gold)
                    CountUpText(value: result.tokensEarned, color: GoalRushTheme.gold)
                }
            }
            Divider().overlay(.white.opacity(0.12))
            if result.mode.isEndless {
                statRow(label: "Wave reached", value: "\(result.wave)", icon: "flag.checkered")
                statRow(label: "Final score", icon: "trophy.fill") {
                    CountUpText(value: result.score, font: .body.bold(), color: .primary)
                }
                let best = store.progress.endlessRecord(for: result.mode.world)
                statRow(label: "Personal best", value: "Wave \(best.bestWave)", icon: "crown.fill")
            } else {
                LabeledContent("Stamina remaining", value: "\(Int(result.remainingStamina))")
            }
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .gameSurface(.panel)
    }

    private var characterReward: some View {
        let character = result.characterEarned.map(CharacterCatalog.character)
        return VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            Label("NEW CHARACTER UNLOCKED", systemImage: "sparkles")
                .font(GoalRushTheme.Typography.captionEmphasized)
                .tracking(1.1)
                .foregroundStyle(GoalRushTheme.gold)
            if let character {
                Image(character.assetStem + "Roster")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 180)
                    .accessibilityHidden(true)
            }
            Text(character?.name ?? "New Hero")
                .font(GoalRushTheme.Typography.title2)
            Text(character?.abilityName ?? "Unique ability unlocked")
                .font(GoalRushTheme.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(GoalRushTheme.Metrics.sectionSpacing)
        .gameSurface(.modal)
        .overlay {
            ComicPanelShape(cut: GoalRushTheme.Metrics.panelRadius)
                .stroke(GoalRushTheme.gold.opacity(0.38))
        }
        .accessibilityElement(children: .contain)
    }

    private var actions: some View {
        VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            Button(primaryTitle, systemImage: "play.fill", action: primaryAction)
                .buttonStyle(GameLaunchButtonStyle())
                .accessibilityIdentifier("result-primary")

            HStack(alignment: .top, spacing: GoalRushTheme.Metrics.sectionSpacing) {
                resultDestination(
                    title: "Upgrades",
                    systemImage: "arrow.up",
                    accent: GoalRushTheme.cyan,
                    identifier: "result-more-upgrades",
                    action: openUpgrades
                )
                resultDestination(
                    title: result.mode.isEndless ? "Arenas" : "Map",
                    systemImage: "map.fill",
                    accent: result.mode.world.accentColor,
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
            VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                Image(systemName: systemImage)
                    .font(GoalRushTheme.Typography.title2)
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(.black.opacity(0.56), in: .circle)
                    .overlay {
                        Circle().stroke(accent.opacity(0.82), lineWidth: 2)
                    }
                    .shadow(color: accent.opacity(0.34), radius: 12, y: 5)

                Text(title)
                    .font(GoalRushTheme.Typography.captionEmphasized)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }

    private func statRow(label: String, value: String, icon: String) -> some View {
        statRow(label: label, icon: icon) { Text(value).bold().monospacedDigit() }
    }

    private func statRow<Value: View>(label: String, icon: String, @ViewBuilder value: () -> Value) -> some View {
        HStack {
            Label(label, systemImage: icon).foregroundStyle(.secondary)
            Spacer()
            value()
        }
    }

    private var isNotableRun: Bool {
        result.didWin || result.newBestWave || result.newBestScore
    }

    private var celebrationEffectsAllowed: Bool {
        !reduceMotion && !store.settings.reducedFlashes
    }

    private var backgroundImage: String {
        GameContent.world(result.mode.world).heroAsset
    }

    private var heroIcon: String {
        if result.isFirstClear { return "star.circle.fill" }
        if result.mode.isEndless { return "infinity.circle.fill" }
        return result.didWin ? "trophy.fill" : "arrow.counterclockwise.circle.fill"
    }

    private var heroColor: Color {
        if result.mode.isEndless { return result.mode.world.accentColor }
        return result.didWin ? GoalRushTheme.gold : GoalRushTheme.orange
    }

    private var heroTitle: String {
        if result.isFirstClear { return "FIRST CLEAR!" }
        if result.mode.isEndless { return "WAVE \(result.wave)" }
        return result.didWin ? "LEVEL CLEAR" : "GAME OVER"
    }

    private var heroSubtitle: String {
        switch result.mode {
        case .endless(let world): "\(GameContent.world(world).name) • Powers reset"
        case .campaign(let level): result.didWin ? GameContent.level(level).name : "Tokens kept • Upgrade and retry"
        }
    }

    private var primaryTitle: String {
        if !result.didWin { return "Retry" }

        return switch result.mode {
        case .endless: "Run It Back"
        case .campaign(let level): level < GameContent.levels.count ? "Play Next Level" : "Play Again"
        }
    }

    private func primaryAction() {
        store.uiAudio.play(.tap)
        switch result.mode {
        case .endless(let world): store.startEndless(world: world)
        case .campaign(let level):
            store.start(level: result.didWin ? min(level + 1, GameContent.levels.count) : level)
        }
    }

    private func openUpgrades() {
        store.uiAudio.play(.tap)
        store.route = .upgrades
    }

    private func openHome() {
        store.uiAudio.play(.tap)
        store.route = .home
    }

    private func openModeSelection() {
        store.uiAudio.play(.tap)
        switch result.mode {
        case .endless:
            store.route = .endless
        case .campaign(let level):
            store.openWorldMap(result.mode.world, focusLevel: level)
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
                    .frame(width: 5, height: index.isMultiple(of: 3) ? 34 : 22)
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
