import SwiftUI

struct FloatingComboView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false
    @State private var reducedMotionOpacity = 1.0
    let combo: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: -4) {
            Text("\(combo)×")
                .font(GoalRushTheme.Typography.metric(size: 42, relativeTo: .largeTitle))
                .italic()
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("COMBO")
                .font(GoalRushTheme.Typography.captionEmphasized)
                .tracking(1.4)
        }
        .foregroundStyle(comboColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            ComicPanelShape(cut: 8)
                .fill(GoalRushTheme.navy.opacity(0.88))
                .overlay {
                    ComicInkTexture(opacity: 0.08)
                        .clipShape(ComicPanelShape(cut: 8))
                }
        }
        .overlay {
            ComicPanelShape(cut: 8)
                .stroke(comboColor.opacity(0.78), lineWidth: 2)
        }
        .shadow(color: comboColor.opacity(0.42), radius: 10, y: 4)
        .scaleEffect(isPulsing && !reduceMotion ? 1.32 : 1, anchor: .topTrailing)
        .opacity(reducedMotionOpacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Combo times \(combo)")
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
        default: GoalRushTheme.cyan
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
