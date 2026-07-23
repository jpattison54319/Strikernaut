import SwiftUI

struct ResultView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var showingMoreActions = false
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
                        missionProgress
                        if !result.gearEarned.isEmpty {
                            gearReward
                        }
                        actions
                        Spacer(minLength: GoalRushTheme.Metrics.sectionSpacing)
                    }
                    .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .sheet(isPresented: $showingMoreActions) {
            ResultMoreActionsSheet(result: result)
        }
        .onAppear {
            appeared = true
            if isNotableRun {
                store.uiAudio.play(.fanfare)
            } else {
                store.uiAudio.play(.locked, volume: 0.4)
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
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text(heroSubtitle)
                    .font(.headline)
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
                        .font(.title.bold())
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
                Label("Training Tokens", systemImage: "hexagon.fill")
                    .foregroundStyle(GoalRushTheme.gold)
                Spacer()
                HStack(spacing: 4) {
                    Text("+")
                        .font(.title2.bold())
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
            Label("Progress and rewards saved", systemImage: "checkmark.circle.fill")
                .font(.footnote.bold())
                .foregroundStyle(GoalRushTheme.positive)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .gameSurface(.panel)
    }

    @ViewBuilder
    private var missionProgress: some View {
        let progressed = store.progress.missions.filter { $0.progress > 0 }
        if !progressed.isEmpty {
            VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.compactSpacing) {
                Label("Mission progress", systemImage: "target")
                    .font(.subheadline.bold())
                ForEach(progressed) { mission in
                    HStack {
                        Text(MissionCatalog.title(for: mission.kind))
                            .font(.caption)
                        Spacer()
                        if mission.isComplete && !mission.claimed {
                            Text("COMPLETE • claim on Home")
                                .font(.caption.bold())
                                .foregroundStyle(GoalRushTheme.positive)
                        } else {
                            Text("\(min(mission.progress, mission.goal))/\(mission.goal)")
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(GoalRushTheme.Metrics.standardSpacing)
            .gameSurface(.panel)
        }
    }

    private var gearReward: some View {
        VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            Label("WORLD REWARD EARNED", systemImage: "sparkles")
                .font(.caption.bold())
                .tracking(1.1)
                .foregroundStyle(GoalRushTheme.gold)
            Text("\(GameContent.world(result.mode.world).gearSetName) Set")
                .font(.title2.bold())
            Text("Unlocked in your Locker.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                ForEach(result.gearEarned, id: \.self) { id in
                    let item = GearCatalog.item(id)
                    VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                        Image(systemName: item.slot.icon)
                            .font(.headline)
                            .frame(width: 42, height: 42)
                            .background(result.mode.world.accentColor.opacity(0.16), in: .circle)
                        Text(item.slot.title)
                            .font(.caption.bold())
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(GoalRushTheme.Metrics.sectionSpacing)
        .gameSurface(.modal)
        .overlay {
            RoundedRectangle(cornerRadius: GoalRushTheme.Metrics.panelRadius)
                .stroke(GoalRushTheme.gold.opacity(0.38))
        }
        .accessibilityElement(children: .contain)
    }

    private var actions: some View {
        VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            Button(primaryTitle, systemImage: "play.fill", action: primaryAction)
                .buttonStyle(GameLaunchButtonStyle())
                .accessibilityIdentifier("result-primary")

            Button("More Actions", systemImage: "ellipsis.circle") {
                showingMoreActions = true
            }
            .buttonStyle(SecondaryGameButton())
            .accessibilityIdentifier("result-more")
        }
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
        result.mode.world == .mars ? "MarsArena" : "GameplayArena"
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
        return result.didWin ? "LEVEL CLEAR" : "RUN ENDED"
    }

    private var heroSubtitle: String {
        switch result.mode {
        case .endless(let world): "\(GameContent.world(world).name) • Powers reset"
        case .campaign(let level): result.didWin ? GameContent.level(level).name : "Tokens kept • Upgrade and retry"
        }
    }

    private var primaryTitle: String {
        switch result.mode {
        case .endless: "Run It Back"
        case .campaign(let level): result.didWin && level < GameContent.levels.count ? "Play Next Level" : "Play Again"
        }
    }

    private func primaryAction() {
        switch result.mode {
        case .endless(let world): store.startEndless(world: world)
        case .campaign(let level):
            store.start(level: result.didWin ? min(level + 1, GameContent.levels.count) : level)
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
