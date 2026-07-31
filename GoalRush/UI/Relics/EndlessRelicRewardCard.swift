import SwiftUI

struct EndlessRelicRewardCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let relic: EndlessRelic

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: GoalRushTheme.Metrics.standardSpacing))
            : AnyLayout(
                HStackLayout(
                    alignment: .center,
                    spacing: GoalRushTheme.Metrics.standardSpacing
                )
            )

        return layout {
            Label("Relic gained", systemImage: "sparkles")
                .font(GoalRushTheme.Typography.headline)
                .foregroundStyle(relic.rarity.color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("result-relic-found")

            RelicInventoryTile(relic: relic)
                .frame(width: dynamicTypeSize.isAccessibilitySize ? 190 : 118)
                .accessibilityIdentifier("result-relic-summary")
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .gameSurface(.panel)
        .overlay {
            ComicPanelShape(cut: GoalRushTheme.Metrics.controlRadius)
                .stroke(relic.rarity.color.opacity(0.52), lineWidth: 2)
        }
    }
}
