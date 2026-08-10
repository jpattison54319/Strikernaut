import SwiftUI

struct ResultHeroCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let icon: String
    let iconColor: Color
    let title: String
    let accessibilityTitle: String
    let subtitle: String
    let isNewBest: Bool
    let starCount: Int?
    let appeared: Bool

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(
                VStackLayout(
                    alignment: .leading,
                    spacing: GoalRushTheme.Metrics.standardSpacing
                )
            )
            : AnyLayout(
                HStackLayout(
                    alignment: .center,
                    spacing: GoalRushTheme.Metrics.standardSpacing
                )
            )

        return layout {
            Image(systemName: icon)
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(iconColor)
                .symbolEffect(.bounce, value: appeared && !reduceMotion)
                .shadow(color: iconColor.opacity(0.42), radius: 12)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(GoalRushTheme.Typography.display)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .accessibilityLabel(accessibilityTitle)
                    .accessibilityIdentifier("result-title")

                Text(subtitle)
                    .font(GoalRushTheme.Typography.subheadline)
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            accessory
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .gameSurface(.modal)
    }

    @ViewBuilder
    private var accessory: some View {
        if isNewBest || starCount != nil {
            VStack(
                alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing,
                spacing: 6
            ) {
                if isNewBest {
                    GameStatusBadge(text: "NEW BEST", tone: .attention)
                        .scaleEffect(appeared ? 1 : 0.72)
                        .animation(
                            reduceMotion
                                ? nil
                                : .spring(duration: 0.45, bounce: 0.42).delay(0.24),
                            value: appeared
                        )
                        .accessibilityIdentifier("result-new-best")
                }

                if let starCount {
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: index < starCount ? "star.fill" : "star")
                        }
                    }
                    .font(GoalRushTheme.Typography.subheadlineEmphasized)
                    .foregroundStyle(GoalRushTheme.gold)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(starCount) of 3 stars")
                    .accessibilityIdentifier("result-stars")
                }
            }
        }
    }
}
