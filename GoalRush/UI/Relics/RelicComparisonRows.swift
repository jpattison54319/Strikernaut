import SwiftUI

struct RelicComparisonRows: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let candidate: EndlessRelic
    let equipped: EndlessRelic?

    var body: some View {
        let valuesLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(
                VStackLayout(
                    alignment: .leading,
                    spacing: GoalRushTheme.Metrics.compactSpacing
                )
            )
            : AnyLayout(HStackLayout(spacing: GoalRushTheme.Metrics.compactSpacing))

        VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
            Text(equipped == nil ? "BONUSES" : "COMPARE TO EQUIPPED")
                .font(GoalRushTheme.Typography.captionEmphasized)
                .tracking(0.9)
                .foregroundStyle(.white.opacity(0.62))

            ForEach(comparedStats) { stat in
                VStack(alignment: .leading, spacing: 5) {
                    Label(stat.title, systemImage: stat.systemImage)
                        .font(GoalRushTheme.Typography.subheadlineEmphasized)
                        .fixedSize(horizontal: false, vertical: true)
                    valuesLayout {
                        valueColumn(
                            title: "THIS RELIC",
                            value: candidate.value(for: stat),
                            stat: stat
                        )
                        if let equipped {
                            valueColumn(
                                title: "EQUIPPED",
                                value: equipped.value(for: stat),
                                stat: stat
                            )
                            deltaColumn(
                                value: candidate.value(for: stat)
                                    - equipped.value(for: stat),
                                stat: stat
                            )
                        }
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("relic-comparison")
    }

    private var comparedStats: [EndlessRelicStat] {
        EndlessRelicStat.allCases.filter { stat in
            candidate.affix(for: stat) != nil || equipped?.affix(for: stat) != nil
        }
    }

    private func valueColumn(
        title: String,
        value: Double,
        stat: EndlessRelicStat
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(GoalRushTheme.Typography.caption2)
                .foregroundStyle(.white.opacity(0.48))
            Text(percent(value, stat: stat))
                .font(GoalRushTheme.Typography.subheadlineEmphasized)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func deltaColumn(
        value: Double,
        stat: EndlessRelicStat
    ) -> some View {
        let tone: Color = value > 0 ? GoalRushTheme.positive
            : value < 0 ? GoalRushTheme.orange
            : .white.opacity(0.62)
        return VStack(alignment: .leading, spacing: 2) {
            Text("CHANGE")
                .font(GoalRushTheme.Typography.caption2)
                .foregroundStyle(.white.opacity(0.48))
            Text(percent(value, stat: stat, includePlus: true))
                .font(GoalRushTheme.Typography.subheadlineEmphasized)
                .monospacedDigit()
                .foregroundStyle(tone)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func percent(
        _ fraction: Double,
        stat: EndlessRelicStat,
        includePlus: Bool = true
    ) -> String {
        let percent = fraction * 100
        let prefix = includePlus && percent > 0 ? "+" : ""
        let suffix = stat == .criticalChance ? " pp" : "%"
        return String(format: "%@%.1f%@", prefix, percent, suffix)
    }
}
