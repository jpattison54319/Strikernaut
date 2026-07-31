import SwiftUI

struct RelicAffixList: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let affixes: [EndlessRelicAffix]
    var compact = false

    var body: some View {
        let rowLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(
                VStackLayout(
                    alignment: .leading,
                    spacing: GoalRushTheme.Metrics.compactSpacing
                )
            )
            : AnyLayout(
                HStackLayout(
                    alignment: .center,
                    spacing: GoalRushTheme.Metrics.compactSpacing
                )
            )

        VStack(spacing: compact ? 5 : GoalRushTheme.Metrics.compactSpacing) {
            ForEach(affixes) { affix in
                rowLayout {
                    Label {
                        Text(affix.stat.shortTitle)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: affix.stat.systemImage)
                            .frame(width: 20)
                    }
                    .font(
                        compact
                            ? GoalRushTheme.Typography.captionEmphasized
                            : GoalRushTheme.Typography.subheadline
                    )
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(valueText(for: affix))
                        .font(
                            compact
                                ? GoalRushTheme.Typography.captionEmphasized
                                : GoalRushTheme.Typography.subheadlineEmphasized
                        )
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(affix.stat.title), \(accessibilityValue(for: affix))"
                )
            }
        }
    }

    private func valueText(for affix: EndlessRelicAffix) -> String {
        let suffix = affix.stat == .criticalChance ? " pp" : "%"
        return String(format: "+%.1f%@", affix.percent, suffix)
    }

    private func accessibilityValue(for affix: EndlessRelicAffix) -> String {
        String(
            format: "plus %.1f %@",
            affix.percent,
            affix.stat.unitDescription
        )
    }
}
