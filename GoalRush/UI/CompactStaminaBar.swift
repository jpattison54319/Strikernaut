import SwiftUI

struct CompactStaminaBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let stamina: Double
    let maxStamina: Double
    let tint: Color

    private let trackWidth: CGFloat = 92
    private let fillWidth: CGFloat = 88

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(GoalRushTheme.ink.opacity(0.96))
                .stroke(.white.opacity(0.20), lineWidth: 1)
                .frame(width: trackWidth, height: 26)
                .offset(x: 12)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.76), tint],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: fillWidth * fraction, height: 22)
                .offset(x: 14)
                .animation(
                    reduceMotion ? .easeOut(duration: 0.12) : .snappy(duration: 0.22),
                    value: fraction
                )

            Text(Int(stamina).formatted())
                .font(GoalRushTheme.Typography.subheadlineEmphasized)
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(width: fillWidth)
                .offset(x: 14)

            Circle()
                .fill(GoalRushTheme.ink)
                .stroke(.white.opacity(0.26), lineWidth: 1.5)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "heart.fill")
                        .font(GoalRushTheme.Typography.headline)
                        .foregroundStyle(Color(red: 0.96, green: 0.14, blue: 0.10))
                }
        }
        .frame(width: 106, height: 38, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Stamina \(Int(stamina)) of \(Int(maxStamina))"
        )
        .accessibilityIdentifier("stamina-meter")
    }

    private var fraction: CGFloat {
        CGFloat(min(1, max(0, stamina / max(1, maxStamina))))
    }
}

#Preview {
    ZStack {
        GoalRushTheme.navy.ignoresSafeArea()
        VStack(spacing: 18) {
            CompactStaminaBar(stamina: 24, maxStamina: 100, tint: GoalRushTheme.orange)
            CompactStaminaBar(stamina: 40, maxStamina: 100, tint: GoalRushTheme.gold)
            CompactStaminaBar(stamina: 91, maxStamina: 100, tint: GoalRushTheme.positive)
        }
    }
}
