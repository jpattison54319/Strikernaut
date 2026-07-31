import SwiftUI

struct RelicInventoryTile: View {
    let relic: EndlessRelic
    var isEquipped = false
    var isSelected = false
    var selectionEnabled = false

    var body: some View {
        VStack(spacing: 3) {
            Text(relic.name)
                .font(GoalRushTheme.Typography.captionEmphasized)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.68)
                .padding(.horizontal, showsStatusAccessory ? 12 : 0)
                .frame(maxWidth: .infinity, minHeight: 27)

            RelicMedallionView(relic: relic)
                .frame(height: 47)

            RelicCompactEffectGrid(affixes: relic.affixes)
                .frame(maxHeight: 28)
        }
        .padding(7)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(GoalRushTheme.surfaceRaised.opacity(0.96), in: ComicPanelShape(cut: 8))
        .overlay {
            ComicPanelShape(cut: 8)
                .stroke(
                    isSelected ? GoalRushTheme.gold : relic.rarity.color,
                    lineWidth: isSelected ? 3.5 : 2.5
                )
        }
        .shadow(color: relic.rarity.color.opacity(0.22), radius: 5)
        .overlay(alignment: .topTrailing) {
            statusAccessory
                .offset(y: -10)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(relic.rarity.title) \(relic.name) relic. "
                + relic.affixes.map(\.accessibilityText).joined(separator: ", ")
        )
        .accessibilityValue(
            isSelected ? "Selected" : (isEquipped ? "Equipped" : "Not equipped")
        )
    }

    private var showsStatusAccessory: Bool {
        selectionEnabled || isEquipped
    }

    @ViewBuilder
    private var statusAccessory: some View {
        if selectionEnabled {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(
                    isSelected ? GoalRushTheme.gold : .white.opacity(0.72)
                )
                .frame(width: 20, height: 20)
                .background(GoalRushTheme.ink, in: .circle)
                .overlay {
                    Circle()
                        .stroke(
                            isSelected ? GoalRushTheme.gold : .white.opacity(0.54),
                            lineWidth: 1.5
                        )
                }
                .accessibilityHidden(true)
        } else if isEquipped {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(GoalRushTheme.gold)
                .frame(width: 20, height: 20)
                .background(GoalRushTheme.ink, in: .circle)
                .overlay {
                    Circle()
                        .stroke(GoalRushTheme.gold, lineWidth: 1.5)
                }
                .accessibilityHidden(true)
        }
    }
}
