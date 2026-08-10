import SwiftUI

struct ProgressLifetimeMetricCell: View {
    let metric: LifetimeMetricKind
    let stats: LifetimeStats

    var body: some View {
        HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
            Image(systemName: metric.icon)
                .font(GoalRushTheme.Typography.subheadlineEmphasized)
                .foregroundStyle(GoalRushTheme.cyan)
                .frame(
                    width: GoalRushTheme.Metrics.minimumTapTarget,
                    height: GoalRushTheme.Metrics.minimumTapTarget
                )
                .background(
                    GoalRushTheme.cyan.opacity(0.12),
                    in: Circle()
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(metric.title)
                    .font(GoalRushTheme.Typography.captionEmphasized)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(metric.value(from: stats))
                    .font(
                        GoalRushTheme.Typography.metric(
                            size: 18,
                            relativeTo: .headline
                        )
                    )
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)
        }
        .padding(GoalRushTheme.Metrics.compactSpacing)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .background(
            GoalRushTheme.surfaceRaised.opacity(0.72),
            in: ComicPanelShape(cut: GoalRushTheme.Metrics.smallRadius)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(metric.title), \(metric.accessibilityValue(from: stats))"
        )
        .accessibilityIdentifier("progress-lifetime-\(metric.rawValue)")
    }
}
