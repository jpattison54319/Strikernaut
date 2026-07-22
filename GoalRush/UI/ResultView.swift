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

            if result.didWin || result.mode.isEndless {
                ResultBurst(accent: result.mode.world.accentColor)
                    .scaleEffect(appeared ? 1 : 0.35)
                    .opacity(appeared ? 1 : 0)
                    .animation(reduceMotion ? nil : .spring(duration: 0.75, bounce: 0.26), value: appeared)
                    .accessibilityHidden(true)
            }

            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 38)
                    hero
                    resultStats
                    if !result.gearEarned.isEmpty { gearReward }
                    actions
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 22)
            }
        }
        .onAppear { appeared = true }
        .sensoryFeedback(trigger: appeared) { _, isVisible in
            guard isVisible, store.settings.hapticsEnabled else { return nil }
            return result.didWin || result.mode.isEndless ? .success : .warning
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
                    Text("+\(result.tokensEarned)")
                        .font(.title2.bold())
                        .foregroundStyle(GoalRushTheme.gold)
                        .monospacedDigit()
                }
                Divider().overlay(.white.opacity(0.12))
                if result.mode.isEndless {
                    statRow(label: "Wave reached", value: "\(result.wave)", icon: "flag.checkered")
                    statRow(label: "Final score", value: result.score.formatted(), icon: "trophy.fill")
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
        HStack {
            Label(label, systemImage: icon).foregroundStyle(.secondary)
            Spacer()
            Text(value).bold().monospacedDigit()
        }
    }

    private var backgroundColors: [Color] {
        if result.mode.isEndless {
            return [GoalRushTheme.navy, result.mode.world.secondaryColor.opacity(0.46), GoalRushTheme.navy]
        }
        return [GoalRushTheme.navy, result.didWin ? Color(red: 0.06, green: 0.24, blue: 0.24) : Color(red: 0.22, green: 0.08, blue: 0.09)]
    }

    private var heroIcon: String {
        if result.mode.isEndless { return "infinity.circle.fill" }
        return result.didWin ? "trophy.fill" : "arrow.counterclockwise.circle.fill"
    }

    private var heroColor: Color {
        if result.mode.isEndless { return result.mode.world.accentColor }
        return result.didWin ? GoalRushTheme.gold : GoalRushTheme.orange
    }

    private var heroTitle: String {
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
