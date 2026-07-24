import SwiftUI

struct AbilityDraftView: View {
    let abilities: [AbilityKind]
    let session: GameSessionModel

    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            RadialGradient(
                colors: [GoalRushTheme.blue.opacity(0.24), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 430
            )
            .ignoresSafeArea()
            .accessibilityHidden(true)

            ScrollView {
                VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                    header
                    ForEach(Array(abilities.enumerated()), id: \.element) { index, ability in
                        abilityButton(ability)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 26)
                            .animation(
                                reduceMotion ? nil : .snappy(duration: 0.34).delay(Double(index) * 0.09),
                                value: appeared
                            )
                    }
                }
                .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
                .padding(.vertical, GoalRushTheme.Metrics.sectionSpacing)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear { appeared = true; store.uiAudio.play(.draft, volume: 0.6) }
    }

    private var header: some View {
        VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
            Image(systemName: session.mode.isEndless ? "infinity" : "sparkles")
                .font(.title.bold())
                .foregroundStyle(GoalRushTheme.gold)
                .frame(width: 56, height: 56)
                .background(GoalRushTheme.gold.opacity(0.13), in: .circle)
                .overlay { Circle().stroke(GoalRushTheme.gold.opacity(0.38)) }
                .shadow(color: GoalRushTheme.gold.opacity(0.30), radius: 15)
            Text(headerTitle)
                .font(.title2.bold())
            Label(headerSubtitle, systemImage: "timer")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .frame(maxWidth: .infinity)
        .gameSurface(.modal)
        .accessibilityElement(children: .combine)
    }

    private func abilityButton(_ ability: AbilityKind) -> some View {
        let currentRank = session.simulation.abilityRank(ability)
        let presentation = AbilityPresentation.effect(
            for: ability,
            currentRank: currentRank,
            isEndless: session.mode.isEndless,
            baseKickInterval: session.simulation.kickInterval(atAbilityRank: 0)
        )

        return Button {
            session.choose(ability)
        } label: {
            VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
                HStack(alignment: .top, spacing: GoalRushTheme.Metrics.standardSpacing) {
                    Image(systemName: AbilityPresentation.icon(ability))
                        .font(.title2.bold())
                        .foregroundStyle(GoalRushTheme.navy)
                        .frame(width: 48, height: 48)
                        .background(
                            LinearGradient(
                                colors: [presentation.accent, presentation.accent.opacity(0.66)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: .rect(cornerRadius: 14)
                        )
                    VStack(alignment: .leading, spacing: 6) {
                        Text(AbilityPresentation.title(ability))
                            .font(.headline)
                        Text(AbilityPresentation.benefit(ability))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    AbilityRankPips(currentRank: currentRank, isEndless: session.mode.isEndless)
                }

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(presentation.metric.uppercased())
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        HStack(spacing: 7) {
                            Text(presentation.current)
                                .foregroundStyle(.secondary)
                            Image(systemName: "arrow.right")
                                .font(.caption.bold())
                                .foregroundStyle(presentation.accent)
                            Text(presentation.next)
                                .bold()
                                .foregroundStyle(.white)
                        }
                        .font(.subheadline)
                    }
                    Spacer(minLength: 8)
                    Label("Choose", systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.bold())
                        .foregroundStyle(presentation.accent)
                }
                .padding(GoalRushTheme.Metrics.standardSpacing)
                .background(.black.opacity(0.22), in: .rect(cornerRadius: 14))
            }
            .padding(GoalRushTheme.Metrics.standardSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .gameSurface(.panel)
            .overlay {
                if session.mode.isEndless && currentRank >= 5 {
                    RoundedRectangle(cornerRadius: GoalRushTheme.Metrics.controlRadius)
                        .stroke(GoalRushTheme.gold.opacity(0.75), lineWidth: 2)
                }
            }
        }
        .buttonStyle(AbilityChoiceButtonStyle(accent: presentation.accent))
        .shimmer(active: session.mode.isEndless && currentRank >= 5 && !reduceMotion && !store.settings.reducedFlashes)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(AbilityPresentation.title(ability)), \(presentation.current) to \(presentation.next)")
        .accessibilityHint(session.mode.isEndless ? "Applies for the rest of this endless run" : "Applies for the rest of this level")
        .accessibilityIdentifier("ability-\(ability.rawValue)")
    }

    private var headerTitle: String {
        if session.isStarterDraft { return "Choose Your First Power" }
        if session.mode.isEndless { return "Wave \(session.snapshot.wave) Upgrade" }
        return "Upgrade for Wave \(session.snapshot.wave) of \(session.snapshot.waveCount)"
    }

    private var headerSubtitle: String {
        session.mode.isEndless
            ? "Run only • no rank cap"
            : "Choose one power for the rest of this level"
    }
}

private struct AbilityRankPips: View {
    let currentRank: Int
    let isEndless: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("RANK \(currentRank + 1)")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            if isEndless {
                Label("NO CAP", systemImage: "infinity")
                    .font(.caption2.bold())
                    .foregroundStyle(GoalRushTheme.cyan)
            } else {
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { rank in
                        Circle()
                            .fill(rank <= currentRank ? GoalRushTheme.gold : .white.opacity(0.13))
                            .frame(width: 7, height: 7)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct AbilityChoiceButtonStyle: ButtonStyle {
    let accent: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .shadow(color: configuration.isPressed ? accent.opacity(0.25) : .clear, radius: 14)
            .animation(reduceMotion ? nil : GoalRushTheme.Motion.press, value: configuration.isPressed)
    }
}

struct AbilityEffectPresentation {
    let metric: String
    let current: String
    let next: String
    let accent: Color
}

enum AbilityPresentation {
    static func title(_ ability: AbilityKind) -> String {
        switch ability {
        case .powerDrive: "Power Drive"
        case .quickRelease: "Quick Release"
        case .throughBall: "Through Ball"
        case .curler: "Curler"
        case .oneTwo: "Wide Volley"
        case .cleanSheet: "Clean Sheet"
        case .secondWind: "Second Wind"
        case .gravityBoots: "Gravity Boots"
        case .meteorStrike: "Meteor Strike"
        case .goldenGoal: "Golden Goal"
        }
    }

    static func icon(_ ability: AbilityKind) -> String {
        switch ability {
        case .powerDrive: "bolt.fill"
        case .quickRelease: "hare.fill"
        case .throughBall: "arrow.up.to.line"
        case .curler: "arrow.trianglehead.turn.up.right.circle.fill"
        case .oneTwo: "circle.grid.2x1.fill"
        case .cleanSheet: "shield.fill"
        case .secondWind: "heart.circle.fill"
        case .gravityBoots: "hourglass.circle.fill"
        case .meteorStrike: "flame.fill"
        case .goldenGoal: "hexagon.fill"
        }
    }

    static func benefit(_ ability: AbilityKind) -> String {
        switch ability {
        case .powerDrive: "More ball damage."
        case .quickRelease: "Kick more often."
        case .throughBall: "Hit more targets per ball."
        case .curler: "Shots track nearby targets."
        case .oneTwo: "Cover more lanes."
        case .cleanSheet: "Block one hit."
        case .secondWind: "Heal now and after waves."
        case .gravityBoots: "Slow every threat."
        case .meteorStrike: "Periodic critical power shot."
        case .goldenGoal: "Earn more Training Tokens."
        }
    }

    static func effect(
        for ability: AbilityKind,
        currentRank: Int,
        isEndless: Bool,
        baseKickInterval: Double
    ) -> AbilityEffectPresentation {
        let nextRank = isEndless ? currentRank + 1 : min(3, currentRank + 1)
        switch ability {
        case .powerDrive:
            let base = isEndless ? 1.25 : 1.35
            return .init(
                metric: "Ball damage bonus",
                current: percentBonus(multiplier: pow(base, Double(currentRank))),
                next: percentBonus(multiplier: pow(base, Double(nextRank))),
                accent: GoalRushTheme.orange
            )
        case .quickRelease:
            return .init(
                metric: "Kick interval",
                current: intervalLabel(rank: currentRank, isEndless: isEndless, base: baseKickInterval),
                next: intervalLabel(rank: nextRank, isEndless: isEndless, base: baseKickInterval),
                accent: GoalRushTheme.cyan
            )
        case .throughBall:
            return .init(
                metric: "Targets hit per ball",
                current: "\(currentRank + 1)",
                next: "\(nextRank + 1)",
                accent: GoalRushTheme.positive
            )
        case .curler:
            return .init(
                metric: "Shot tracking",
                current: trackingLabel(rank: currentRank, isEndless: isEndless),
                next: trackingLabel(rank: nextRank, isEndless: isEndless),
                accent: GoalRushTheme.cyan
            )
        case .oneTwo:
            return .init(
                metric: "Kick pattern",
                current: volleyLabel(rank: currentRank),
                next: volleyLabel(rank: nextRank),
                accent: GoalRushTheme.gold
            )
        case .cleanSheet:
            return .init(
                metric: "Blocks earned this run",
                current: "\(currentRank)",
                next: "\(nextRank)",
                accent: GoalRushTheme.blue
            )
        case .secondWind:
            return .init(
                metric: "Stamina now / each wave",
                current: currentRank == 0 ? "None" : "+\(10 + currentRank * 4) / +\(4 + currentRank * 3)",
                next: "+\(10 + nextRank * 4) / +\(4 + nextRank * 3)",
                accent: GoalRushTheme.positive
            )
        case .gravityBoots:
            return .init(
                metric: "Enemy speed reduction",
                current: slowLabel(rank: currentRank),
                next: slowLabel(rank: nextRank),
                accent: GoalRushTheme.cyan
            )
        case .meteorStrike:
            return .init(
                metric: "Meteor kick",
                current: meteorLabel(rank: currentRank),
                next: meteorLabel(rank: nextRank),
                accent: GoalRushTheme.orange
            )
        case .goldenGoal:
            return .init(
                metric: "Token rewards",
                current: "+\(currentRank * 15)%",
                next: "+\(nextRank * 15)%",
                accent: GoalRushTheme.gold
            )
        }
    }

    private static func percentBonus(multiplier: Double) -> String {
        "+\(Int(((multiplier - 1) * 100).rounded()))%"
    }

    private static func intervalLabel(rank: Int, isEndless: Bool, base: Double) -> String {
        let interval: Double
        if isEndless {
            interval = 0.14 + (base - 0.14) * pow(0.88, Double(rank))
        } else {
            interval = max(0.14, base * pow(0.82, Double(rank)))
        }
        return String(format: "%.2f sec", interval)
    }

    private static func trackingLabel(rank: Int, isEndless: Bool) -> String {
        guard rank > 0 else { return "Off" }
        if isEndless { return String(format: "%.2f steering", Double(rank) * 0.55) }
        return ["Off", "Light", "Strong", "Elite"][min(rank, 3)]
    }

    private static func volleyLabel(rank: Int) -> String {
        if rank <= 3 {
            return ["1 straight ball", "2-ball spread", "3-ball spread", "4-ball wide spread"][max(rank, 0)]
        }
        return "4 balls • +\((rank - 3) * 12)% side damage"
    }

    private static func slowLabel(rank: Int) -> String {
        let factor = 0.35 + 0.65 * pow(0.90, Double(rank))
        return "\(Int(((1 - factor) * 100).rounded()))% slower"
    }

    private static func meteorLabel(rank: Int) -> String {
        guard rank > 0 else { return "Off" }
        let interval = max(2, 7 - min(rank, 5))
        return "Every \(interval) kicks • +\(rank * 55)%"
    }
}
