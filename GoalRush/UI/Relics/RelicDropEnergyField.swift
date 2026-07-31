import SwiftUI

struct RelicDropEnergyField: View {
    let color: Color
    let stage: RelicDropRevealStage
    let isTurning: Bool
    let flashesAllowed: Bool

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height) * 0.82

            ZStack {
                radialStreaks(diameter: diameter)
                impactRings(diameter: diameter)
                rarityShards(diameter: diameter)

                if flashesAllowed {
                    Circle()
                        .fill(.white)
                        .frame(width: diameter * 0.46, height: diameter * 0.46)
                        .blur(radius: 18)
                        .scaleEffect(stage == .impact ? 1.35 : 0.12)
                        .opacity(stage == .impact ? 0.92 : 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
    }

    private func radialStreaks(diameter: CGFloat) -> some View {
        ZStack {
            ForEach(0..<24, id: \.self) { index in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.clear, color.opacity(0.86), .white],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(
                        width: index.isMultiple(of: 3) ? 3 : 1.5,
                        height: 46 + CGFloat(index % 5) * 12
                    )
                    .offset(y: -diameter * 0.44)
                    .rotationEffect(.degrees(Double(index) * 15))
            }
        }
        .frame(width: diameter, height: diameter)
        .rotationEffect(.degrees(isTurning ? 360 : 0))
        .scaleEffect(stage == .incoming ? 1 : 0.72)
        .opacity(stage == .revealed ? 0.18 : 0.72)
    }

    private func impactRings(diameter: CGFloat) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        index.isMultiple(of: 2) ? color : .white,
                        style: StrokeStyle(
                            lineWidth: CGFloat(5 - index),
                            dash: index == 1 ? [8, 9] : []
                        )
                    )
                    .frame(
                        width: diameter * (0.28 + CGFloat(index) * 0.11),
                        height: diameter * (0.28 + CGFloat(index) * 0.11)
                    )
                    .scaleEffect(stage == .incoming ? 0.42 : 1.72)
                    .opacity(stage == .impact ? 0.86 : (stage == .revealed ? 0.12 : 0.36))
            }
        }
    }

    private func rarityShards(diameter: CGFloat) -> some View {
        ZStack {
            ForEach(0..<16, id: \.self) { index in
                Image(systemName: index.isMultiple(of: 2) ? "diamond.fill" : "sparkle")
                    .font(.system(size: CGFloat(8 + index % 4), weight: .black))
                    .foregroundStyle(index.isMultiple(of: 3) ? .white : color)
                    .offset(
                        y: stage == .incoming
                            ? -diameter * 0.12
                            : -diameter * (0.28 + CGFloat(index % 3) * 0.05)
                    )
                    .rotationEffect(.degrees(Double(index) * 22.5))
                    .opacity(stage == .impact ? 1 : 0)
            }
        }
        .frame(width: diameter, height: diameter)
    }
}
