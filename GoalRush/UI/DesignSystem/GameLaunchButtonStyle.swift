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
                .font(GoalRushTheme.Typography.title3)
                .frame(width: 56, height: 56)
                .foregroundStyle(GoalRushTheme.navy)
                .background(launchGradient, in: .circle)
                .background {
                    Circle()
                        .fill(GoalRushTheme.ink)
                        .offset(x: 4, y: 4)
                }
                .overlay {
                    Circle()
                        .stroke(
                            GoalRushTheme.ink.opacity(isEnabled ? 1 : 0.52),
                            lineWidth: GoalRushTheme.Metrics.inkStrokeWidth
                        )
                }
                .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.97)
                .opacity(isEnabled ? (configuration.isPressed ? 0.90 : 1) : 0.58)
                .animation(reduceMotion ? nil : GoalRushTheme.Motion.press, value: configuration.isPressed)
        } else {
            configuration.label
                .font(GoalRushTheme.Typography.headline)
                .frame(maxWidth: .infinity, minHeight: 56)
                .padding(.horizontal, GoalRushTheme.Metrics.standardSpacing)
                .foregroundStyle(GoalRushTheme.navy)
                .background {
                    launchGradient
                        .clipShape(ComicPanelShape(cut: 9))
                }
                .background {
                    ComicPanelShape(cut: 9)
                        .fill(GoalRushTheme.ink)
                        .offset(x: 4, y: 5)
                }
                .overlay {
                    ComicInkTexture(opacity: 0.13)
                        .clipShape(ComicPanelShape(cut: 9))
                }
                .overlay {
                    ComicPanelShape(cut: 9)
                        .stroke(
                            GoalRushTheme.ink.opacity(isEnabled ? 1 : 0.52),
                            lineWidth: GoalRushTheme.Metrics.inkStrokeWidth
                        )
                }
                .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.97)
                .opacity(isEnabled ? (configuration.isPressed ? 0.90 : 1) : 0.58)
                .animation(reduceMotion ? nil : GoalRushTheme.Motion.press, value: configuration.isPressed)
        }
    }

    private var launchGradient: Color {
        launchColors.first ?? .gray
    }

    private var launchColors: [Color] {
        isEnabled ? [GoalRushTheme.gold] : [.gray.opacity(0.52)]
    }
}
