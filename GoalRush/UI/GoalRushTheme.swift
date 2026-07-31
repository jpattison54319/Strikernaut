import SwiftUI

enum GoalRushTheme {
    // Inked interplanetary sports-comic palette. Keep these semantic rather
    // than sampling individual illustrations so UI and gameplay stay coherent.
    static let ink = Color(red: 0.018, green: 0.024, blue: 0.035)
    static let paper = Color(red: 0.91, green: 0.87, blue: 0.76)
    static let navy = Color(red: 0.025, green: 0.055, blue: 0.10)
    static let blue = Color(red: 0.035, green: 0.30, blue: 0.69)
    static let cyan = Color(red: 0.10, green: 0.72, blue: 0.88)
    static let grass = Color(red: 0.30, green: 0.59, blue: 0.16)
    static let gold = Color(red: 0.96, green: 0.58, blue: 0.06)
    static let orange = Color(red: 0.88, green: 0.20, blue: 0.075)
    static let cream = paper
    static let surface = Color(red: 0.035, green: 0.055, blue: 0.075)
    static let surfaceRaised = Color(red: 0.065, green: 0.11, blue: 0.16)
    static let positive = Color(red: 0.20, green: 0.82, blue: 0.36)
    static let marsRust = Color(red: 0.72, green: 0.18, blue: 0.11)
    static let marsViolet = Color(red: 0.42, green: 0.14, blue: 0.55)

    enum Metrics {
        static let compactSpacing: CGFloat = 8
        static let standardSpacing: CGFloat = 12
        static let sectionSpacing: CGFloat = 20
        static let smallRadius: CGFloat = 5
        static let controlRadius: CGFloat = 7
        static let panelRadius: CGFloat = 10
        static let minimumTapTarget: CGFloat = 44
        static let floatingControlSize: CGFloat = 52
        static let horizontalPadding: CGFloat = 20
        static let shadowRadius: CGFloat = 2
        static let strokeWidth: CGFloat = 2
        static let inkStrokeWidth: CGFloat = 3
        static let registrationOffset: CGFloat = 4
    }

    enum Motion {
        static let press = Animation.snappy(duration: 0.16)
        static let transition = Animation.snappy(duration: 0.24)
    }

    enum Typography {
        static let display = Font.custom(
            "BarlowCondensed-BlackItalic",
            size: 38,
            relativeTo: .largeTitle
        )
        static let title = Font.custom(
            "BarlowCondensed-BlackItalic",
            size: 32,
            relativeTo: .title
        )
        static let title2 = Font.custom(
            "BarlowCondensed-Bold",
            size: 24,
            relativeTo: .title2
        )
        static let title3 = Font.custom(
            "BarlowCondensed-Bold",
            size: 20,
            relativeTo: .title3
        )
        static let headline = Font.custom(
            "BarlowSemiCondensed-SemiBold",
            size: 18,
            relativeTo: .headline
        )
        static let body = Font.custom(
            "BarlowSemiCondensed-Medium",
            size: 17,
            relativeTo: .body
        )
        static let subheadline = Font.custom(
            "BarlowSemiCondensed-Medium",
            size: 15,
            relativeTo: .subheadline
        )
        static let subheadlineEmphasized = Font.custom(
            "BarlowSemiCondensed-SemiBold",
            size: 15,
            relativeTo: .subheadline
        )
        static let caption = Font.custom(
            "BarlowSemiCondensed-Medium",
            size: 12,
            relativeTo: .caption
        )
        static let captionEmphasized = Font.custom(
            "BarlowSemiCondensed-SemiBold",
            size: 12,
            relativeTo: .caption
        )
        static let caption2 = Font.custom(
            "BarlowSemiCondensed-SemiBold",
            size: 11,
            relativeTo: .caption2
        )

        static func display(size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
            .custom("BarlowCondensed-BlackItalic", size: size, relativeTo: style)
        }

        static func metric(size: CGFloat, relativeTo style: Font.TextStyle = .headline) -> Font {
            .custom("BarlowCondensed-Bold", size: size, relativeTo: style).monospacedDigit()
        }
    }

    static let surfaceStroke = paper.opacity(0.34)
    static let emphasizedSurfaceStroke = paper.opacity(0.62)
    static let surfaceShadow = ink.opacity(0.92)

    static let topScrim = LinearGradient(
        colors: [ink.opacity(0.88), ink.opacity(0.42), .clear],
        startPoint: .top,
        endPoint: .bottom
    )

    static let bottomScrim = LinearGradient(
        colors: [.clear, ink.opacity(0.52), navy.opacity(0.96)],
        startPoint: .top,
        endPoint: .bottom
    )
}

extension WorldID {
    var accentColor: Color {
        switch self {
        case .earth: GoalRushTheme.cyan
        case .moon: Color(red: 0.70, green: 0.78, blue: 1)
        case .mars: GoalRushTheme.marsRust
        case .jupiter: Color(red: 0.92, green: 0.57, blue: 0.20)
        case .saturn: Color(red: 0.88, green: 0.76, blue: 0.38)
        case .uranus: Color(red: 0.38, green: 0.86, blue: 0.78)
        case .neptune: Color(red: 0.12, green: 0.58, blue: 0.88)
        }
    }

    var secondaryColor: Color {
        switch self {
        case .earth: GoalRushTheme.grass
        case .moon: Color(red: 0.34, green: 0.24, blue: 0.62)
        case .mars: GoalRushTheme.marsViolet
        case .jupiter: Color(red: 0.24, green: 0.18, blue: 0.46)
        case .saturn: Color(red: 0.28, green: 0.20, blue: 0.42)
        case .uranus: Color(red: 0.38, green: 0.18, blue: 0.58)
        case .neptune: Color(red: 0.04, green: 0.16, blue: 0.42)
        }
    }

    var icon: String {
        switch self {
        case .earth: "globe.americas.fill"
        case .moon: "moon.stars.fill"
        case .mars: "circle.grid.cross.fill"
        case .jupiter: "hurricane"
        case .saturn: "circle.hexagongrid.circle.fill"
        case .uranus: "snowflake.circle.fill"
        case .neptune: "water.waves"
        }
    }
}

struct GameCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background {
                GoalRushTheme.surfaceRaised.opacity(0.97)
                    .clipShape(ComicPanelShape(cut: 12))
            }
            .background {
                ComicPanelShape(cut: 12)
                    .fill(GoalRushTheme.ink)
                    .offset(x: 6, y: 7)
            }
            .overlay { ComicInkTexture().clipShape(ComicPanelShape(cut: 12)) }
            .overlay {
                ComicPanelShape(cut: 12)
                    .stroke(GoalRushTheme.ink, lineWidth: GoalRushTheme.Metrics.inkStrokeWidth)
            }
    }
}

struct PrimaryGameButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(GoalRushTheme.Typography.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(GoalRushTheme.navy)
            .background {
                (isEnabled ? GoalRushTheme.gold : Color.gray.opacity(0.58))
                    .clipShape(ComicPanelShape(cut: 9))
            }
            .background {
                ComicPanelShape(cut: 9)
                    .fill(GoalRushTheme.ink)
                    .offset(x: 4, y: 5)
            }
            .overlay { ComicInkTexture().clipShape(ComicPanelShape(cut: 9)) }
            .overlay { ComicPanelShape(cut: 9).stroke(GoalRushTheme.ink, lineWidth: 3) }
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .opacity(isEnabled ? 1 : 0.68)
            .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: configuration.isPressed)
    }
}

struct CompactGameButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(GoalRushTheme.Typography.subheadlineEmphasized)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .foregroundStyle(.white)
            .background(
                GoalRushTheme.blue.opacity(configuration.isPressed ? 0.70 : 0.98),
                in: ComicPanelShape(cut: 7)
            )
            .background {
                ComicPanelShape(cut: 7)
                    .fill(GoalRushTheme.ink)
                    .offset(x: 3, y: 3)
            }
            .overlay { ComicPanelShape(cut: 7).stroke(GoalRushTheme.ink, lineWidth: 2.5) }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(isEnabled ? 1 : 0.55)
            .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: configuration.isPressed)
    }
}

struct SecondaryGameButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(GoalRushTheme.Typography.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(.white)
            .background {
                GoalRushTheme.surfaceRaised
                    .clipShape(ComicPanelShape(cut: 8))
            }
            .background {
                ComicPanelShape(cut: 8)
                    .fill(GoalRushTheme.ink)
                    .offset(x: 4, y: 4)
            }
            .overlay {
                ComicPanelShape(cut: 8)
                    .stroke(configuration.isPressed ? GoalRushTheme.cyan.opacity(0.7) : .white.opacity(0.16), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.55)
            .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: configuration.isPressed)
    }
}

nonisolated struct ComicPanelShape: InsettableShape {
    var cut: CGFloat = 10
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let cut = min(cut, min(rect.width, rect.height) * 0.24)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> ComicPanelShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

struct ComicInkTexture: View {
    var opacity: Double = 0.11

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 18
            var hatch = Path()
            var x = -size.height
            while x < size.width + size.height {
                hatch.move(to: CGPoint(x: x, y: 0))
                hatch.addLine(to: CGPoint(x: x + size.height, y: size.height))
                x += spacing
            }
            context.stroke(
                hatch,
                with: .color(GoalRushTheme.paper.opacity(opacity)),
                style: StrokeStyle(lineWidth: 0.8, lineCap: .square)
            )

            var registration = Path()
            registration.move(to: CGPoint(x: 0, y: size.height * 0.72))
            registration.addLine(to: CGPoint(x: size.width, y: size.height * 0.58))
            context.stroke(
                registration,
                with: .color(GoalRushTheme.cyan.opacity(opacity * 0.8)),
                lineWidth: 1.5
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
