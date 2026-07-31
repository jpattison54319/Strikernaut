import SwiftUI

struct ProgressLifetimeWidget: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let stats: LifetimeStats

    var body: some View {
        VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
            Label("Lifetime", systemImage: "chart.bar.fill")
                .font(GoalRushTheme.Typography.title2)
                .foregroundStyle(GoalRushTheme.cyan)

            if dynamicTypeSize.isAccessibilitySize {
                LazyVStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                    metricCells
                }
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(
                            .flexible(),
                            spacing: GoalRushTheme.Metrics.compactSpacing
                        ),
                        GridItem(.flexible()),
                    ],
                    spacing: GoalRushTheme.Metrics.compactSpacing
                ) {
                    metricCells
                }
            }
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .gameSurface(.panel)
        .accessibilityElement(children: .contain)
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityLabel("Lifetime statistics widget")
                .accessibilityIdentifier("progress-lifetime-widget")
        }
    }

    @ViewBuilder
    private var metricCells: some View {
        ForEach(LifetimeMetricKind.allCases) { metric in
            ProgressLifetimeMetricCell(metric: metric, stats: stats)
        }
    }
}
