import SwiftUI

struct DeathSaveCountdownView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let secondsRemaining: Int

    var body: some View {
        Color.black.opacity(0.36)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                    Text("TAKE CONTROL IN")
                        .font(GoalRushTheme.Typography.title2)
                        .foregroundStyle(.white)

                    Text(secondsRemaining, format: .number)
                        .font(
                            GoalRushTheme.Typography.display(
                                size: 96,
                                relativeTo: .largeTitle
                            )
                        )
                        .monospacedDigit()
                        .foregroundStyle(GoalRushTheme.cyan)
                        .contentTransition(.numericText(countsDown: true))
                        .shadow(
                            color: GoalRushTheme.ink,
                            radius: GoalRushTheme.Metrics.shadowRadius,
                            x: GoalRushTheme.Metrics.registrationOffset,
                            y: GoalRushTheme.Metrics.registrationOffset
                        )

                    Label(
                        "3-second safety shield follows",
                        systemImage: "shield.fill"
                    )
                    .font(GoalRushTheme.Typography.headline)
                    .foregroundStyle(GoalRushTheme.positive)
                }
                .multilineTextAlignment(.center)
                .padding(GoalRushTheme.Metrics.sectionSpacing)
                .gameSurface(.modal)
                .padding(GoalRushTheme.Metrics.horizontalPadding)
            }
            .animation(
                reduceMotion ? .easeOut(duration: 0.12) : .snappy(duration: 0.22),
                value: secondsRemaining
            )
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Resuming in \(secondsRemaining)")
            .accessibilityValue("Three seconds of damage protection follows")
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityIdentifier("death-save-countdown")
    }
}

#Preview {
    ZStack {
        GoalRushTheme.navy.ignoresSafeArea()
        DeathSaveCountdownView(secondsRemaining: 3)
    }
}
