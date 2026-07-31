import SwiftUI

struct EndlessRunStatCard: View {
    let title: String
    let systemImage: String
    let accent: Color
    let wave: Int?
    let score: Int?
    let accessibilityIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
            Label(title, systemImage: systemImage)
                .font(GoalRushTheme.Typography.headline)
                .foregroundStyle(accent)

            Divider()
                .overlay(GoalRushTheme.emphasizedSurfaceStroke)

            metric(label: "Wave", value: wave.map(GameNumberFormatter.compact) ?? "—")
            metric(label: "Score", value: score.map(GameNumberFormatter.compact) ?? "—")
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GoalRushTheme.surface.opacity(0.98),
            in: ComicPanelShape(cut: GoalRushTheme.Metrics.controlRadius)
        )
        .overlay {
            ComicPanelShape(cut: GoalRushTheme.Metrics.controlRadius)
                .stroke(GoalRushTheme.emphasizedSurfaceStroke, lineWidth: 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(
            "Wave \(wave.map(GameNumberFormatter.exact) ?? "not set"), score \(score.map(GameNumberFormatter.exact) ?? "not set")"
        )
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func metric(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: GoalRushTheme.Metrics.compactSpacing) {
            Text(label.uppercased())
                .font(GoalRushTheme.Typography.captionEmphasized)
                .foregroundStyle(.white)

            Spacer(minLength: GoalRushTheme.Metrics.compactSpacing)

            Text(value)
                .font(GoalRushTheme.Typography.metric(size: 24, relativeTo: .title2))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }
}
