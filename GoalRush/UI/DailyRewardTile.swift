import SwiftUI

struct DailyRewardTile: View {
    let day: Int
    let reward: Int
    let isCollected: Bool
    let isCurrent: Bool
    let isGrandPrize: Bool
    let onCollect: (() -> Void)?

    var body: some View {
        if let onCollect {
            Button(action: onCollect) {
                tileContent
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Collect Day \(day), \(reward) Training Tokens")
            .accessibilityHint("Claims today's daily reward")
            .accessibilityInputLabels(["Day \(day)", "Collect reward"])
            .accessibilityIdentifier("daily-reward-day-\(day)")
        } else {
            tileContent
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityText)
                .accessibilityIdentifier("daily-reward-day-\(day)")
        }
    }

    private var tileContent: some View {
        Group {
            if isGrandPrize {
                grandPrizeContent
            } else {
                standardContent
            }
        }
        .foregroundStyle(.white)
        .background(background, in: ComicPanelShape(cut: GoalRushTheme.Metrics.smallRadius))
        .overlay {
            ComicPanelShape(cut: GoalRushTheme.Metrics.smallRadius)
                .stroke(borderColor, lineWidth: isCurrent ? 2 : 1)
        }
        .opacity(isCollected || isCurrent ? 1 : 0.66)
    }

    private var grandPrizeContent: some View {
        HStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            Image("DailyChest")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .clipShape(ComicPanelShape(cut: GoalRushTheme.Metrics.smallRadius))
                .accessibilityHidden(true)
            rewardDetails
            Spacer(minLength: GoalRushTheme.Metrics.compactSpacing)
            statusIcon
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .frame(maxWidth: .infinity, minHeight: 92)
    }

    private var standardContent: some View {
        VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
            HStack {
                Text("DAY \(day)")
                    .font(GoalRushTheme.Typography.captionEmphasized)
                Spacer(minLength: 2)
                statusIcon
            }
            Label(reward.formatted(), systemImage: "hexagon.fill")
                .font(GoalRushTheme.Typography.metric(size: 18))
                .foregroundStyle(GoalRushTheme.gold)
        }
        .padding(GoalRushTheme.Metrics.compactSpacing)
        .frame(maxWidth: .infinity, minHeight: 86)
    }

    private var rewardDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DAY 7")
                .font(GoalRushTheme.Typography.headline)
            Label(reward.formatted(), systemImage: "hexagon.fill")
                .font(GoalRushTheme.Typography.metric(size: 24, relativeTo: .title2))
                .foregroundStyle(GoalRushTheme.gold)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        if isCollected {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(GoalRushTheme.positive)
                .accessibilityHidden(true)
        } else if isCurrent {
            Image(systemName: "gift.fill")
                .foregroundStyle(GoalRushTheme.gold)
                .accessibilityHidden(true)
        }
    }

    private var background: some ShapeStyle {
        if isCurrent {
            AnyShapeStyle(GoalRushTheme.gold.opacity(0.16))
        } else if isCollected {
            AnyShapeStyle(GoalRushTheme.positive.opacity(0.12))
        } else {
            AnyShapeStyle(.white.opacity(0.07))
        }
    }

    private var borderColor: Color {
        if isCurrent {
            GoalRushTheme.gold
        } else if isCollected {
            GoalRushTheme.positive.opacity(0.54)
        } else {
            .white.opacity(0.14)
        }
    }

    private var accessibilityText: String {
        let status = isCollected ? "collected" : (isCurrent ? "ready to collect" : "upcoming")
        return "Day \(day), \(reward) Training Tokens, \(status)"
    }
}
