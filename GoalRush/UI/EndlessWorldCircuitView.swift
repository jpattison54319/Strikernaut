import SwiftUI

struct EndlessWorldCircuitView: View {
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                ForEach(GameContent.worlds.indices, id: \.self) { index in
                    let world = GameContent.worlds[index]
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.white.opacity(0.58))
                            .accessibilityHidden(true)
                    }

                    VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                        WorldEnemyEmblem(world: world.id, isBoss: false)
                            .frame(width: 52, height: 52)

                        Text(world.name)
                            .font(GoalRushTheme.Typography.headline)
                            .foregroundStyle(.white)

                        Text(worldRange(for: index))
                            .font(GoalRushTheme.Typography.captionEmphasized)
                            .foregroundStyle(world.id.accentColor)
                    }
                    .padding(GoalRushTheme.Metrics.standardSpacing)
                    .frame(minWidth: 112)
                    .background(.black.opacity(0.44), in: ComicPanelShape(cut: 7))
                    .overlay {
                        ComicPanelShape(cut: 7)
                            .stroke(world.id.accentColor.opacity(0.58), lineWidth: 2)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "\(world.name), waves \(worldRange(for: index).replacing("Waves ", with: ""))"
                    )
                }

                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                    .font(GoalRushTheme.Typography.title2)
                    .foregroundStyle(GoalRushTheme.gold)
                    .padding(.horizontal, GoalRushTheme.Metrics.compactSpacing)
                    .accessibilityLabel("Then repeat")
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("endless-world-circuit")
    }

    private func worldRange(for index: Int) -> String {
        let first = index * EndlessRules.wavesPerWorld + 1
        let last = first + EndlessRules.wavesPerWorld - 1
        return "Waves \(first)–\(last)"
    }
}
