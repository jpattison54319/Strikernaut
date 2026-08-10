import SwiftUI

struct WaveObjectiveHUD: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let world: WorldID
    let wave: Int
    let waveCount: Int
    let remainingEnemies: Int
    let isEndless: Bool
    let isBossWave: Bool

    var body: some View {
        HStack(spacing: 0) {
            AnimatedObjectiveCounter(
                text: waveText,
                value: wave,
                color: waveColor,
                fontSize: 20,
                width: isEndless ? 38 : 52,
                alignment: .center,
                punchScale: 1.16,
                travel: 5
            )
                .padding(.leading, 6)

            WaveObjectiveDivider()
                .stroke(
                    .white.opacity(0.26),
                    style: StrokeStyle(lineWidth: 1.25, lineCap: .square)
                )
                .frame(width: 10, height: 28)
                .padding(.horizontal, 4)

            WorldEnemyEmblem(world: world, isBoss: isBossWave)
                .frame(width: 30, height: 30)
                .id("\(world.rawValue)-\(isBossWave)")
                .transition(
                    reduceMotion
                        ? .opacity
                        : .scale(scale: 0.68).combined(with: .opacity)
                )

            AnimatedObjectiveCounter(
                text: GameNumberFormatter.compact(remainingEnemies),
                value: remainingEnemies,
                color: isBossWave ? GoalRushTheme.orange : .white,
                fontSize: 21,
                width: 44,
                alignment: .leading,
                punchScale: 1.11,
                travel: 3
            )
                .padding(.leading, 3)
                .padding(.trailing, 7)
        }
        .frame(height: 38)
        .background {
            WaveObjectivePlate()
                .fill(
                    LinearGradient(
                        colors: [
                            GoalRushTheme.ink.opacity(0.98),
                            GoalRushTheme.navy.opacity(0.96),
                            world.secondaryColor.opacity(0.68)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .overlay {
            WaveObjectivePlate()
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.34),
                            world.accentColor.opacity(0.78)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.25
                )
        }
        .shadow(color: GoalRushTheme.ink.opacity(0.52), radius: 2, y: 2)
        .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: world)
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: isBossWave)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("wave-objective")
    }

    private var waveText: String {
        isEndless ? GameNumberFormatter.compact(wave) : "\(wave)/\(waveCount)"
    }

    private var waveColor: Color {
        isBossWave ? GoalRushTheme.gold : world.accentColor
    }

    private var accessibilityLabel: String {
        let waveDescription = isEndless
            ? "Wave \(GameNumberFormatter.exact(wave))"
            : "Wave \(wave) of \(waveCount)"
        let enemyDescription = remainingEnemies == 1
            ? "1 enemy remaining"
            : "\(GameNumberFormatter.exact(remainingEnemies)) enemies remaining"
        return "\(waveDescription), \(isBossWave ? "boss objective, " : "")\(enemyDescription)"
    }
}

struct WorldEnemyEmblem: View {
    let world: WorldID
    let isBoss: Bool

    var body: some View {
        Image(world.factionSigilAsset(isBoss: isBoss))
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

private struct WaveObjectivePlate: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 9, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - 9, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct WaveObjectiveDivider: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

#Preview("Campaign objective") {
    ZStack {
        GoalRushTheme.navy.ignoresSafeArea()
        WaveObjectiveHUD(
            world: .earth,
            wave: 2,
            waveCount: 5,
            remainingEnemies: 31,
            isEndless: false,
            isBossWave: false
        )
        .padding()
    }
}

#Preview("Faction sigils") {
    ZStack {
        GoalRushTheme.ink.ignoresSafeArea()
        VStack(spacing: 18) {
            ForEach(WorldID.allCases) { world in
                HStack(spacing: 24) {
                    WorldEnemyEmblem(world: world, isBoss: false)
                    WorldEnemyEmblem(world: world, isBoss: true)
                }
                .frame(height: 72)
            }
        }
        .padding()
    }
}
