import SwiftUI

struct AbilityCardPrintTexture: View {
    var body: some View {
        Canvas { context, size in
            var hatch = Path()
            var x = -size.height
            while x < size.width + size.height {
                hatch.move(to: CGPoint(x: x, y: 0))
                hatch.addLine(to: CGPoint(x: x + size.height, y: size.height))
                x += 17
            }
            context.stroke(
                hatch,
                with: .color(GoalRushTheme.ink.opacity(0.055)),
                style: StrokeStyle(lineWidth: 0.8, lineCap: .square)
            )

            var registration = Path()
            registration.move(to: CGPoint(x: size.width * 0.08, y: size.height * 0.69))
            registration.addLine(to: CGPoint(x: size.width * 0.94, y: size.height * 0.61))
            context.stroke(
                registration,
                with: .color(GoalRushTheme.cyan.opacity(0.10)),
                lineWidth: 1.4
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
