import SwiftUI

struct RelicRarityBadge: View {
    let rarity: EndlessRelicRarity

    var body: some View {
        HStack(spacing: 5) {
            Text(rarity.title.uppercased())
                .font(GoalRushTheme.Typography.captionEmphasized)
                .tracking(0.8)

            HStack(spacing: 2) {
                ForEach(0..<rarity.diamondCount, id: \.self) { _ in
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 7, weight: .black))
                }
            }
            .accessibilityHidden(true)
        }
        .foregroundStyle(rarity.color)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 9)
        .frame(minHeight: 28)
        .background(rarity.color.opacity(0.12), in: Capsule())
        .overlay {
            Capsule().stroke(rarity.color.opacity(0.72), lineWidth: 1.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(rarity.title), \(rarity.diamondCount) of 5 rarity diamonds"
        )
    }
}
