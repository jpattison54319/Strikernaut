import SwiftUI

struct UpgradeIntroCard: View {
    let tokens: Int

    var body: some View {
        GameCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Image(systemName: "arrow.up.forward.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(GoalRushTheme.gold)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Permanent Training").font(.title3.bold())
                        Text("These unlimited upgrades stay active in every level. Prices rise through rank 5, then remain steady while your power keeps growing.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Divider().overlay(.white.opacity(0.12))
                Label("\(tokens) Training Tokens available", systemImage: "hexagon.fill")
                    .font(.headline)
                    .foregroundStyle(GoalRushTheme.gold)
            }
        }
    }
}
