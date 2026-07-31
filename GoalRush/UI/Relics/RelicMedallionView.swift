import SwiftUI

struct RelicMedallionView: View {
    let systemImage: String
    let rarity: EndlessRelicRarity

    init(relic: EndlessRelic) {
        systemImage = relic.primaryStat.systemImage
        rarity = relic.rarity
    }

    init(systemImage: String, rarity: EndlessRelicRarity = .common) {
        self.systemImage = systemImage
        self.rarity = rarity
    }

    var body: some View {
        ZStack {
            Image("RelicMedallion")
                .resizable()
                .scaledToFit()
                .shadow(color: rarity.color.opacity(0.72), radius: 9)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            rarity.color.opacity(0.34),
                            GoalRushTheme.ink.opacity(0.96),
                        ],
                        center: .center,
                        startRadius: 1,
                        endRadius: 30
                    )
                )
                .frame(width: 45, height: 45)
                .overlay {
                    Circle()
                        .stroke(rarity.color.opacity(0.86), lineWidth: 2)
                }

            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(.white)
                .shadow(color: rarity.color, radius: 5)
        }
        .accessibilityHidden(true)
    }
}
