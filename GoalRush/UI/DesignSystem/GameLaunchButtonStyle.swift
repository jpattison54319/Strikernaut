import SwiftUI

struct GameLaunchButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let circular: Bool

    init(circular: Bool = false) {
        self.circular = circular
    }

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        if circular {
            configuration.label
                .font(.title3.weight(.heavy))
                .frame(width: 56, height: 56)
                .foregroundStyle(GoalRushTheme.navy)
                .background(launchGradient, in: .circle)
                .overlay {
                    Circle()
                        .stroke(
                            Color.white.opacity(isEnabled ? 0.36 : 0.12),
                            lineWidth: GoalRushTheme.Metrics.strokeWidth
                        )
                }
                .shadow(
                    color: isEnabled ? GoalRushTheme.orange.opacity(configuration.isPressed ? 0.18 : 0.34) : .clear,
                    radius: GoalRushTheme.Metrics.shadowRadius,
                    y: 6
                )
                .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.97)
                .opacity(isEnabled ? (configuration.isPressed ? 0.90 : 1) : 0.58)
                .animation(reduceMotion ? nil : GoalRushTheme.Motion.press, value: configuration.isPressed)
        } else {
            configuration.label
                .font(.headline.weight(.heavy))
                .frame(maxWidth: .infinity, minHeight: 56)
                .padding(.horizontal, GoalRushTheme.Metrics.standardSpacing)
                .foregroundStyle(GoalRushTheme.navy)
                .background {
                    launchGradient
                        .clipShape(.rect(cornerRadius: GoalRushTheme.Metrics.controlRadius))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: GoalRushTheme.Metrics.controlRadius)
                        .stroke(
                            Color.white.opacity(isEnabled ? 0.36 : 0.12),
                            lineWidth: GoalRushTheme.Metrics.strokeWidth
                        )
                }
                .shadow(
                    color: isEnabled ? GoalRushTheme.orange.opacity(configuration.isPressed ? 0.18 : 0.34) : .clear,
                    radius: GoalRushTheme.Metrics.shadowRadius,
                    y: 6
                )
                .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.97)
                .opacity(isEnabled ? (configuration.isPressed ? 0.90 : 1) : 0.58)
                .animation(reduceMotion ? nil : GoalRushTheme.Motion.press, value: configuration.isPressed)
        }
    }

    private var launchGradient: LinearGradient {
        LinearGradient(colors: launchColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var launchColors: [Color] {
        isEnabled
            ? [GoalRushTheme.gold, GoalRushTheme.orange]
            : [.gray.opacity(0.56), .gray.opacity(0.38)]
    }
}
