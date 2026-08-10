import SwiftUI

struct EndlessLiveScoreView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let score: Int

    var body: some View {
        VStack(spacing: 0) {
            Text("SCORE")
                .font(GoalRushTheme.Typography.captionEmphasized)
                .foregroundStyle(.secondary)

            Text(GameNumberFormatter.compact(score))
                .font(GoalRushTheme.Typography.subheadlineEmphasized)
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .animation(reduceMotion ? nil : .snappy, value: score)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(GameNumberFormatter.exact(score))")
        .accessibilityIdentifier("endless-live-score")
    }
}

#Preview {
    ZStack {
        GoalRushTheme.ink.ignoresSafeArea()
        EndlessLiveScoreView(score: 128_450)
    }
}
