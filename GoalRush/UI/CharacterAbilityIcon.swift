import SwiftUI

struct CharacterAbilityIcon: View {
    let ability: CharacterAbility
    let isReady: Bool

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 36
            context.scaleBy(x: scale, y: scale)
            let color = isReady ? GoalRushTheme.gold : .white.opacity(0.78)
            let softColor = color.opacity(0.42)

            switch ability {
            case .pinballBlitz:
                drawPinballBlitz(in: &context, color: color, softColor: softColor)
            case .timeBreak:
                drawTimeBreak(in: &context, color: color, softColor: softColor)
            case .meteorVolley:
                drawMeteorVolley(in: &context, color: color, softColor: softColor)
            case .lastStand:
                drawLastStand(in: &context, color: color, softColor: softColor)
            case .stormbreak:
                drawPinballBlitz(in: &context, color: color, softColor: softColor)
            case .ringRelay:
                drawOrbitalCrown(in: &context, color: color, softColor: softColor)
            case .poleShift:
                drawPolarLockdown(in: &context, color: color, softColor: softColor)
            case .tidalBreak:
                drawTidalBreak(in: &context, color: color, softColor: softColor)
            }
        }
        .frame(width: 38, height: 38)
        .accessibilityHidden(true)
    }

    private func drawOrbitalCrown(
        in context: inout GraphicsContext,
        color: Color,
        softColor: Color
    ) {
        let orbit = CGRect(x: 4, y: 8, width: 28, height: 20)
        context.stroke(
            Path(ellipseIn: orbit),
            with: .color(softColor),
            lineWidth: 2
        )
        for index in 0..<8 {
            let angle = Double(index) / 8 * Double.pi * 2
            let center = CGPoint(
                x: 18 + cos(angle) * 14,
                y: 18 + sin(angle) * 10
            )
            context.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - 2.7,
                    y: center.y - 2.7,
                    width: 5.4,
                    height: 5.4
                )),
                with: .color(color)
            )
        }
    }

    private func drawPolarLockdown(
        in context: inout GraphicsContext,
        color: Color,
        softColor: Color
    ) {
        context.fill(
            Path(ellipseIn: CGRect(x: 5, y: 20, width: 26, height: 10)),
            with: .color(softColor)
        )
        var spikes = Path()
        for x in stride(from: 8.0, through: 28.0, by: 5.0) {
            spikes.move(to: CGPoint(x: x - 2, y: 24))
            spikes.addLine(to: CGPoint(x: x, y: 8))
            spikes.addLine(to: CGPoint(x: x + 2, y: 24))
        }
        context.fill(spikes, with: .color(color))
    }

    private func drawTidalBreak(
        in context: inout GraphicsContext,
        color: Color,
        softColor: Color
    ) {
        for row in 0..<3 {
            var wave = Path()
            let y = 11.0 + Double(row) * 7
            wave.move(to: CGPoint(x: 3, y: y + 2))
            wave.addCurve(
                to: CGPoint(x: 18, y: y),
                control1: CGPoint(x: 8, y: y - 6),
                control2: CGPoint(x: 13, y: y + 6)
            )
            wave.addCurve(
                to: CGPoint(x: 33, y: y + 2),
                control1: CGPoint(x: 23, y: y - 6),
                control2: CGPoint(x: 28, y: y + 6)
            )
            context.stroke(
                wave,
                with: .color(row == 1 ? color : softColor),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
        }
    }

    private func drawPinballBlitz(
        in context: inout GraphicsContext,
        color: Color,
        softColor: Color
    ) {
        var ricochet = Path()
        ricochet.move(to: CGPoint(x: 4, y: 27))
        ricochet.addLine(to: CGPoint(x: 12, y: 12))
        ricochet.addLine(to: CGPoint(x: 22, y: 25))
        ricochet.addLine(to: CGPoint(x: 32, y: 9))
        context.stroke(
            ricochet,
            with: .color(softColor),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        )

        for center in [CGPoint(x: 7, y: 27), CGPoint(x: 19, y: 18), CGPoint(x: 30, y: 9)] {
            let ball = CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)
            context.fill(Path(ellipseIn: ball), with: .color(color))
            context.stroke(Path(ellipseIn: ball), with: .color(.white.opacity(0.78)), lineWidth: 1)
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - 1.7, y: center.y - 1.7, width: 3.4, height: 3.4)),
                with: .color(.black.opacity(0.88))
            )
            for angle in stride(from: 0.0, to: .pi * 2, by: .pi * 2 / 3) {
                let panelCenter = CGPoint(
                    x: center.x + cos(angle) * 3.2,
                    y: center.y + sin(angle) * 3.2
                )
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: panelCenter.x - 0.7,
                        y: panelCenter.y - 0.7,
                        width: 1.4,
                        height: 1.4
                    )),
                    with: .color(.black.opacity(0.78))
                )
            }
        }
    }

    private func drawTimeBreak(
        in context: inout GraphicsContext,
        color: Color,
        softColor: Color
    ) {
        let clock = Path(ellipseIn: CGRect(x: 6, y: 6, width: 24, height: 24))
        context.stroke(clock, with: .color(softColor), lineWidth: 3)

        var hands = Path()
        hands.move(to: CGPoint(x: 18, y: 9))
        hands.addLine(to: CGPoint(x: 18, y: 18))
        hands.addLine(to: CGPoint(x: 25, y: 21))
        context.stroke(
            hands,
            with: .color(color),
            style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round)
        )

        var fracture = Path()
        fracture.move(to: CGPoint(x: 22, y: 3))
        fracture.addLine(to: CGPoint(x: 17, y: 13))
        fracture.addLine(to: CGPoint(x: 22, y: 13))
        fracture.addLine(to: CGPoint(x: 14, y: 33))
        fracture.addLine(to: CGPoint(x: 17, y: 20))
        fracture.addLine(to: CGPoint(x: 12, y: 20))
        context.stroke(
            fracture,
            with: .color(color),
            style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawMeteorVolley(
        in context: inout GraphicsContext,
        color: Color,
        softColor: Color
    ) {
        let meteors: [(CGPoint, CGPoint)] = [
            (CGPoint(x: 5, y: 5), CGPoint(x: 14, y: 18)),
            (CGPoint(x: 15, y: 3), CGPoint(x: 22, y: 15)),
            (CGPoint(x: 26, y: 6), CGPoint(x: 30, y: 18))
        ]
        for (start, end) in meteors {
            var trail = Path()
            trail.move(to: start)
            trail.addLine(to: end)
            context.stroke(
                trail,
                with: .color(softColor),
                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
            )
            context.fill(
                Path(ellipseIn: CGRect(x: end.x - 3.5, y: end.y - 3.5, width: 7, height: 7)),
                with: .color(color)
            )
        }

        var burst = Path()
        let center = CGPoint(x: 20, y: 26)
        for index in 0..<16 {
            let angle = Double(index) * .pi / 8
            let radius = index.isMultiple(of: 2) ? 9.0 : 4.5
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            index == 0 ? burst.move(to: point) : burst.addLine(to: point)
        }
        burst.closeSubpath()
        context.fill(burst, with: .color(color))
    }

    private func drawLastStand(
        in context: inout GraphicsContext,
        color: Color,
        softColor: Color
    ) {
        context.stroke(
            Path(ellipseIn: CGRect(x: 2, y: 9, width: 32, height: 20)),
            with: .color(softColor),
            lineWidth: 2.5
        )

        var shield = Path()
        shield.move(to: CGPoint(x: 18, y: 3))
        shield.addCurve(
            to: CGPoint(x: 30, y: 9),
            control1: CGPoint(x: 22, y: 6),
            control2: CGPoint(x: 27, y: 7)
        )
        shield.addLine(to: CGPoint(x: 28, y: 20))
        shield.addCurve(
            to: CGPoint(x: 18, y: 32),
            control1: CGPoint(x: 27, y: 26),
            control2: CGPoint(x: 21, y: 30)
        )
        shield.addCurve(
            to: CGPoint(x: 8, y: 20),
            control1: CGPoint(x: 15, y: 30),
            control2: CGPoint(x: 9, y: 26)
        )
        shield.addLine(to: CGPoint(x: 6, y: 9))
        shield.addCurve(
            to: CGPoint(x: 18, y: 3),
            control1: CGPoint(x: 11, y: 8),
            control2: CGPoint(x: 15, y: 6)
        )
        shield.closeSubpath()
        context.fill(shield, with: .color(.black.opacity(0.78)))
        context.stroke(
            shield,
            with: .color(color),
            style: StrokeStyle(lineWidth: 2.7, lineCap: .round, lineJoin: .round)
        )

        var centerLine = Path()
        centerLine.move(to: CGPoint(x: 18, y: 8))
        centerLine.addLine(to: CGPoint(x: 18, y: 26))
        context.stroke(centerLine, with: .color(color.opacity(0.72)), lineWidth: 2)
    }
}
