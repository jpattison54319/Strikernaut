import SwiftUI

struct FloatingComboView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false
    @State private var reducedMotionOpacity = 1.0
    let combo: Int

    var body: some View {
        Text("\(GameNumberFormatter.compact(combo))x")
            .font(GoalRushTheme.Typography.metric(size: 28, relativeTo: .title2))
            .italic()
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(combo)))
            .foregroundStyle(comboColor)
            .scaleEffect(isPulsing && !reduceMotion ? 1.15 : 1, anchor: .topTrailing)
            .opacity(reducedMotionOpacity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Combo times \(GameNumberFormatter.exact(combo))")
            .accessibilityIdentifier("combo-meter")
            .onChange(of: combo, initial: true) { previous, current in
                guard current > 0, current >= previous else { return }
                animateIncrement()
            }
    }

    private var comboColor: Color {
        switch combo {
        case 25...: GoalRushTheme.orange
        case 10...: GoalRushTheme.gold
        default: .white
        }
    }

    private func animateIncrement() {
        if reduceMotion {
            reducedMotionOpacity = 0.70
            withAnimation(.easeOut(duration: 0.18)) {
                reducedMotionOpacity = 1
            }
            return
        }

        withAnimation(.spring(duration: 0.16, bounce: 0.42)) {
            isPulsing = true
        } completion: {
            withAnimation(.spring(duration: 0.24, bounce: 0.18)) {
                isPulsing = false
            }
        }
    }
}
