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
                        Text("These upgrades stay active in every level. Each card shows the exact stat you have now and what the next rank changes.")
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
