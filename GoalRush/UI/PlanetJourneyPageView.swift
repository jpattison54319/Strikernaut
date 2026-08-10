import SwiftUI

struct PlanetJourneyPageView: View {
    let pageIndex: Int
    let destinations: [WorldJourneyDestination]
    let progress: PlayerProgress
    let onSelect: (WorldJourneyDestination) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                StarField(pageIndex: pageIndex)
                PlanetJourneyPath(destinationCount: destinations.count)
                    .stroke(
                        .white.opacity(0.52),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [2, 12])
                    )
                    .shadow(color: GoalRushTheme.cyan.opacity(0.38), radius: 6)

                ForEach(Array(destinations.enumerated()), id: \.element.id) { index, destination in
                    PlanetDestinationNode(
                        destination: destination,
                        progress: progress,
                        onSelect: { onSelect(destination) }
                    )
                    .position(position(for: index, in: geometry.size))
                }
            }
            .clipped()
            .overlay(alignment: .top) {
                Text(pageIndex == 0 ? "THE JOURNEY CONTINUES" : "DEEP SPACE")
                    .font(GoalRushTheme.Typography.captionEmphasized)
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.60))
                    .padding(.top, 14)
            }
        }
    }

    private func position(for index: Int, in size: CGSize) -> CGPoint {
        let points: [CGPoint] = [
            .init(x: 0.32, y: 0.76),
            .init(x: 0.68, y: 0.48),
            .init(x: 0.34, y: 0.20)
        ]
        let point = points[min(index, points.count - 1)]
        return CGPoint(x: size.width * point.x, y: size.height * point.y)
    }
}

private nonisolated struct PlanetJourneyPath: Shape {
    let destinationCount: Int

    func path(in rect: CGRect) -> Path {
        let points: [CGPoint] = [
            .init(x: rect.width * 0.32, y: rect.height * 0.76),
            .init(x: rect.width * 0.68, y: rect.height * 0.48),
            .init(x: rect.width * 0.34, y: rect.height * 0.20)
        ]
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.52, y: rect.height + 34))
        for point in points.prefix(max(1, destinationCount)) {
            path.addCurve(
                to: point,
                control1: CGPoint(x: path.currentPoint?.x ?? rect.midX, y: point.y + rect.height * 0.12),
                control2: CGPoint(x: point.x, y: point.y + rect.height * 0.08)
            )
        }
        if let last = points.prefix(max(1, destinationCount)).last {
            path.addCurve(
                to: CGPoint(x: rect.width * 0.58, y: -42),
                control1: CGPoint(x: last.x, y: last.y - rect.height * 0.12),
                control2: CGPoint(x: rect.width * 0.58, y: rect.height * 0.05)
            )
        }
        return path
    }
}

private struct StarField: View {
    let pageIndex: Int

    var body: some View {
        Canvas { context, size in
            for index in 0..<52 {
                let x = CGFloat((index * 47 + pageIndex * 31) % 101) / 100 * size.width
                let y = CGFloat((index * 73 + pageIndex * 19) % 103) / 102 * size.height
                let radius: CGFloat = index.isMultiple(of: 7) ? 1.8 : 0.9
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)),
                    with: .color(index.isMultiple(of: 5) ? GoalRushTheme.cyan.opacity(0.66) : .white.opacity(0.52))
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
