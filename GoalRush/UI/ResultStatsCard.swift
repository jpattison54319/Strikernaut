import SwiftUI

struct ResultStatsCard: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let result: RunResult

    var body: some View {
        VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
            tokenHeader

            Divider()
                .overlay(.white.opacity(0.12))

            metrics
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .gameSurface(.panel)
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityLabel("Result stats")
                .accessibilityIdentifier("result-stats")
        }
    }

    @ViewBuilder
    private var tokenHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.compactSpacing) {
                tokenAmount
                RewardedTokenBonusCard(result: result)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        } else {
            HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                tokenAmount
                Spacer(minLength: GoalRushTheme.Metrics.compactSpacing)
                RewardedTokenBonusCard(result: result)
            }
        }
    }

    private var tokenAmount: some View {
        HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
            TrainingTokenIcon(size: 25)

            VStack(alignment: .leading, spacing: 0) {
                Text("Training Tokens")
                    .font(GoalRushTheme.Typography.captionEmphasized)
                    .foregroundStyle(GoalRushTheme.gold.opacity(0.84))

                HStack(spacing: 2) {
                    Text("+")
                        .font(GoalRushTheme.Typography.metric(size: 25))
                    CountUpText(
                        value: result.tokensEarned,
                        font: GoalRushTheme.Typography.metric(size: 25),
                        color: GoalRushTheme.gold
                    )
                }
                .foregroundStyle(GoalRushTheme.gold)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(result.tokensEarned.formatted()) Training Tokens earned"
        )
        .accessibilityIdentifier("result-tokens")
    }

    @ViewBuilder
    private var metrics: some View {
        if result.mode.isEndless {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(
                    VStackLayout(spacing: GoalRushTheme.Metrics.compactSpacing)
                )
                : AnyLayout(
                    HStackLayout(spacing: GoalRushTheme.Metrics.compactSpacing)
                )

            layout {
                ResultMetricCell(
                    title: "Wave",
                    value: GameNumberFormatter.compact(result.wave),
                    accessibilityValue: GameNumberFormatter.exact(result.wave),
                    systemImage: "flag.checkered",
                    identifier: "result-wave"
                )
                ResultMetricCell(
                    title: "Score",
                    value: GameNumberFormatter.compact(result.score),
                    accessibilityValue: GameNumberFormatter.exact(result.score),
                    systemImage: "trophy.fill",
                    identifier: "result-score"
                )
                ResultMetricCell(
                    title: "Best",
                    value: "W\(GameNumberFormatter.compact(store.progress.endlessRecord.bestWave))",
                    accessibilityValue:
                        "Wave \(GameNumberFormatter.exact(store.progress.endlessRecord.bestWave))",
                    systemImage: "crown.fill",
                    identifier: "result-best"
                )
            }
        } else {
            ResultMetricCell(
                title: "Stamina",
                value: GameNumberFormatter.compact(Int(result.remainingStamina)),
                accessibilityValue:
                    GameNumberFormatter.exact(Int(result.remainingStamina)),
                systemImage: "heart.fill",
                identifier: "result-stamina"
            )
        }
    }
}

private struct ResultMetricCell: View {
    let title: String
    let value: String
    let accessibilityValue: String
    let systemImage: String
    let identifier: String

    var body: some View {
        VStack(spacing: 3) {
            Label(title, systemImage: systemImage)
                .font(GoalRushTheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(1)

            Text(value)
                .font(GoalRushTheme.Typography.metric(size: 20))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.64)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(
            GoalRushTheme.ink.opacity(0.36),
            in: ComicPanelShape(cut: 5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(accessibilityValue)")
        .accessibilityIdentifier(identifier)
    }
}
