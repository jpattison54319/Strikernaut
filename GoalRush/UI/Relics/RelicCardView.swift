import SwiftUI

struct RelicCardView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let relic: EndlessRelic
    var isEquipped = false
    var isSelected = false
    var selectionEnabled = false

    var body: some View {
        let headerLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(
                VStackLayout(
                    alignment: .leading,
                    spacing: GoalRushTheme.Metrics.standardSpacing
                )
            )
            : AnyLayout(
                HStackLayout(
                    alignment: .top,
                    spacing: GoalRushTheme.Metrics.standardSpacing
                )
            )

        VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
            headerLayout {
                RelicMedallionView(relic: relic)
                    .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 5) {
                    RelicRarityBadge(rarity: relic.rarity)
                    Text(relic.name)
                        .font(GoalRushTheme.Typography.title3)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                statusAccessory
            }

            RelicAffixList(affixes: relic.affixes, compact: true)
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .background(GoalRushTheme.surfaceRaised.opacity(0.96), in: ComicPanelShape(cut: 9))
        .overlay {
            ComicPanelShape(cut: 9)
                .stroke(
                    isSelected ? GoalRushTheme.gold : relic.rarity.color.opacity(0.62),
                    lineWidth: isSelected ? 3 : 2
                )
        }
        .shadow(color: relic.rarity.color.opacity(0.16), radius: 5)
        .contentShape(.rect)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(relic.name), from cleared wave \(relic.sourceWaveMilestone)"
        )
        .accessibilityValue(isEquipped ? "Equipped" : "")
    }

    @ViewBuilder
    private var statusAccessory: some View {
        if selectionEnabled {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(GoalRushTheme.Typography.title2)
                .foregroundStyle(isSelected ? GoalRushTheme.gold : .white.opacity(0.38))
                .accessibilityHidden(true)
        } else if isEquipped {
            GameStatusBadge(text: "EQUIPPED", tone: .positive)
        }
    }
}
