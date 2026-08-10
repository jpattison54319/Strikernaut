import SwiftUI

struct UpgradeInfoView: View {
    var body: some View {
        GameSheetScaffold(
            title: "Upgrades",
            subtitle: "Permanent ranks for Campaign and Endless."
        ) {
            VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
                Label(
                    "Every rank permanently improves its stat.",
                    systemImage: "checkmark.shield.fill"
                )
                Label(
                    "The same ranks apply in Campaign and Endless.",
                    systemImage: "gamecontroller.fill"
                )
                Label(
                    "Ranks are uncapped; later ranks use a rising price curve.",
                    systemImage: "infinity"
                )
                Label(
                    prestigeThresholds,
                    systemImage: "medal.fill"
                )
                Label(
                    "Each badge costs \(GameNumberFormatter.compact(UpgradePrestigeRules.prestigeCost)) Training Tokens.",
                    systemImage: "hexagon.fill"
                )
                Label(
                    "Prestige changes the badge only—rank and stat bonuses never reset.",
                    systemImage: "arrow.up.forward.circle.fill"
                )
            }
            .font(GoalRushTheme.Typography.headline)
            .foregroundStyle(.white)
            .padding(GoalRushTheme.Metrics.standardSpacing)
            .gameSurface(.panel)
            .overlay(alignment: .topLeading) {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityLabel("Upgrade rules")
                    .accessibilityIdentifier("upgrade-how-it-works")
            }
        }
    }

    private var prestigeThresholds: String {
        UpgradePrestigeTier.allCases
            .map { "\($0.title) at Rank \($0.threshold)" }
            .joined(separator: " • ")
    }
}
