import SwiftUI

struct ResultView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    let result: RunResult

    var body: some View {
        ZStack {
            LinearGradient(colors: backgroundColors, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            if result.didWin || result.newBestWave || result.newBestScore {
                ResultBurst(accent: result.mode.world.accentColor)
                    .scaleEffect(appeared ? 1 : 0.35)
                    .opacity(appeared ? 1 : 0)
                    .animation(reduceMotion ? nil : .spring(duration: 0.75, bounce: 0.26), value: appeared)
                    .accessibilityHidden(true)
                ConfettiBurst(accent: result.mode.world.accentColor)
            }

            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 38)
                    hero
                    if result.newBestWave || result.newBestScore {
                        Text("NEW BEST!")
                            .font(.headline.bold())
                            .foregroundStyle(GoalRushTheme.navy)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(GoalRushTheme.gold, in: .capsule)
                            .shadow(color: GoalRushTheme.gold.opacity(0.5), radius: 14)
                            .scaleEffect(appeared ? 1 : 0.4)
                            .animation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.5).delay(0.35), value: appeared)
                            .accessibilityIdentifier("result-new-best")
                    }
                    if result.didWin && !result.mode.isEndless {
                        HStack(spacing: 10) {
                            ForEach(0..<3, id: \.self) { index in
                                Image(systemName: index < StarRating.stars(staminaFraction: result.staminaFraction) ? "star.fill" : "star")
                                    .font(.title.bold())
                                    .foregroundStyle(GoalRushTheme.gold)
                                    .scaleEffect(appeared ? 1 : 0.2)
                                    .animation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.55).delay(0.25 + Double(index) * 0.14), value: appeared)
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(StarRating.stars(staminaFraction: result.staminaFraction)) of 3 stars")
                        .accessibilityIdentifier("result-stars")
                    }
                    resultStats
                    let progressed = store.progress.missions.filter { $0.progress > 0 }
                    if !progressed.isEmpty {
                        GameCard {
                            VStack(alignment: .leading, spacing: 10) {
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
                        }
                    }
                    if !result.gearEarned.isEmpty { gearReward }
                    if let track = nextUpgradeTrack {
                        let rank = store.progress.rank(for: track)
                        let cost = UpgradeRules.cost(forNextRank: rank)
                        let affordable = store.progress.trainingTokens >= cost
                        Button { store.route = .upgrades } label: {
                            VStack(spacing: 8) {
                                HStack {
                                    Label("Next upgrade", systemImage: "arrow.up.circle.fill")
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text(affordable ? "READY" : "\(store.progress.trainingTokens)/\(cost)")
                                        .font(.caption.bold().monospacedDigit())
                                        .foregroundStyle(affordable ? GoalRushTheme.positive : .secondary)
                                }
                                Text("\(UpgradeRules.title(for: track)) rank \(rank + 1)")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                ProgressView(value: min(1, Double(store.progress.trainingTokens) / Double(cost)))
                                    .tint(affordable ? GoalRushTheme.positive : GoalRushTheme.gold)
                            }
                            .padding(14)
                            .background(.white.opacity(0.06), in: .rect(cornerRadius: 18))
                            .overlay { RoundedRectangle(cornerRadius: 18).stroke(affordable ? GoalRushTheme.positive.opacity(0.6) : .white.opacity(0.12)) }
                        }
                        .buttonStyle(.plain)
                        .pulseGlow(affordable, color: GoalRushTheme.positive)
                        .accessibilityIdentifier("result-next-upgrade")
                    }
                    actions
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 22)
            }
        }
        .onAppear {
            appeared = true
            if result.didWin || result.newBestWave || result.newBestScore {
                store.uiAudio.play(.fanfare)
            } else {
                store.uiAudio.play(.locked, volume: 0.4)
            }
        }
        .sensoryFeedback(trigger: appeared) { _, isVisible in
            guard isVisible, store.settings.hapticsEnabled else { return nil }
            return result.didWin || result.newBestWave || result.newBestScore ? .success : .warning
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            Image(systemName: heroIcon)
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(heroColor)
                .symbolEffect(.bounce, value: appeared)
                .shadow(color: heroColor.opacity(0.40), radius: 18)
                .accessibilityHidden(true)
            VStack(spacing: 5) {
                Text(heroTitle)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text(heroSubtitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var resultStats: some View {
        GameCard {
            VStack(spacing: 14) {
                HStack {
                    Label("Training Tokens", systemImage: "hexagon.fill")
                        .foregroundStyle(GoalRushTheme.gold)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("+").font(.title2.bold()).foregroundStyle(GoalRushTheme.gold)
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
        }
    }

    private var gearReward: some View {
        VStack(spacing: 14) {
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
            HStack(spacing: 9) {
                ForEach(result.gearEarned, id: \.self) { id in
                    let item = GearCatalog.item(id)
                    VStack(spacing: 5) {
                        Image(systemName: item.slot.icon)
                            .font(.headline)
                            .frame(width: 42, height: 42)
                            .background(result.mode.world.accentColor.opacity(0.16), in: .circle)
                        Text(item.slot.title)
                            .font(.caption2.bold())
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Button("Open Locker", systemImage: "tshirt.fill") { store.route = .gear }
                .buttonStyle(SecondaryGameButton())
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [GoalRushTheme.gold.opacity(0.16), result.mode.world.accentColor.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 23)
        )
        .overlay { RoundedRectangle(cornerRadius: 23).stroke(GoalRushTheme.gold.opacity(0.38)) }
        .shadow(color: GoalRushTheme.gold.opacity(0.16), radius: 16)
        .accessibilityElement(children: .contain)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if result.isFirstClear {
                Button("Spend your tokens", systemImage: "arrow.up.circle.fill") { store.route = .upgrades }
                    .buttonStyle(SecondaryGameButton())
            }

            Button(primaryTitle, systemImage: "play.fill", action: primaryAction)
                .buttonStyle(PrimaryGameButton())
                .accessibilityIdentifier("result-primary")

            HStack(spacing: 12) {
                Button("Upgrades", systemImage: "arrow.up.circle.fill") { store.route = .upgrades }
                    .buttonStyle(SecondaryGameButton())
                Button("Locker", systemImage: "tshirt.fill") { store.route = .gear }
                    .buttonStyle(SecondaryGameButton())
            }

            Button(result.mode.isEndless ? "Choose Arena" : "Campaign Map", systemImage: "map.fill") {
                store.route = result.mode.isEndless ? .endless : .levels
            }
            .font(.subheadline.bold())
            .frame(minHeight: 44)
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

    private var nextUpgradeTrack: UpgradeTrack? {
        UpgradeTrack.allCases
            .filter { store.progress.rank(for: $0) < UpgradeRules.maxRank }
            .min { UpgradeRules.cost(forNextRank: store.progress.rank(for: $0)) < UpgradeRules.cost(forNextRank: store.progress.rank(for: $1)) }
    }

    private var backgroundColors: [Color] {
        if result.mode.isEndless {
            return [GoalRushTheme.navy, result.mode.world.secondaryColor.opacity(0.46), GoalRushTheme.navy]
        }
        return [GoalRushTheme.navy, result.didWin ? Color(red: 0.06, green: 0.24, blue: 0.24) : Color(red: 0.22, green: 0.08, blue: 0.09)]
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
