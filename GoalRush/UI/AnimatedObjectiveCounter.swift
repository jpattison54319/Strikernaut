import SwiftUI

struct AnimatedObjectiveCounter: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let text: String
    let value: Int
    let color: Color
    let fontSize: Double
    let width: Double
    let alignment: Alignment
    let punchScale: Double
    let travel: Double

    @State private var scale = 1.0
    @State private var verticalOffset = 0.0
    @State private var glowOpacity = 0.0
    @State private var changeSerial = 0

    var body: some View {
        ZStack(alignment: alignment) {
            Text(text)
                .foregroundStyle(color)
                .blur(radius: 7)
                .opacity(glowOpacity)

            Text(text)
                .foregroundStyle(color)
                .contentTransition(
                    reduceMotion
                        ? .opacity
                        : .numericText(value: Double(value))
                )
        }
        .font(GoalRushTheme.Typography.display(size: fontSize, relativeTo: .title2))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.58)
        .frame(width: width, alignment: alignment)
        .scaleEffect(scale)
        .offset(y: verticalOffset)
        .animation(
            reduceMotion ? .easeOut(duration: 0.12) : .snappy(duration: 0.24),
            value: value
        )
        .onChange(of: value, animateChange)
        .accessibilityHidden(true)
    }

    private func animateChange(oldValue: Int, newValue: Int) {
        guard oldValue != newValue, !reduceMotion else { return }
        changeSerial += 1
        let serial = changeSerial
        verticalOffset = newValue < oldValue ? -travel : travel

        withAnimation(.spring(duration: 0.16, bounce: 0.46)) {
            scale = punchScale
            verticalOffset = 0
            glowOpacity = 0.92
        } completion: {
            guard serial == changeSerial else { return }
            withAnimation(.smooth(duration: 0.22)) {
                scale = 1
                glowOpacity = 0
            }
        }
    }
}
