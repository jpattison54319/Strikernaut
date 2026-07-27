import SwiftUI

struct AbilityChoiceButtonStyle: ButtonStyle {
    let accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .offset(y: configuration.isPressed ? 3 : 0)
            .shadow(
                color: configuration.isPressed
                    ? accent.opacity(0.46)
                    : .clear,
                radius: 12
            )
            .animation(
                reduceMotion ? nil : GoalRushTheme.Motion.press,
                value: configuration.isPressed
            )
    }
}
