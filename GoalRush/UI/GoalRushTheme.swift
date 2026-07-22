import SwiftUI

enum GoalRushTheme {
    static let navy = Color(red: 0.035, green: 0.09, blue: 0.18)
    static let blue = Color(red: 0.04, green: 0.42, blue: 0.95)
    static let cyan = Color(red: 0.08, green: 0.82, blue: 0.88)
    static let grass = Color(red: 0.18, green: 0.68, blue: 0.22)
    static let gold = Color(red: 1.0, green: 0.72, blue: 0.12)
    static let orange = Color(red: 1.0, green: 0.38, blue: 0.08)
    static let cream = Color(red: 0.97, green: 0.95, blue: 0.86)
    static let surface = Color(red: 0.06, green: 0.13, blue: 0.23)
    static let surfaceRaised = Color(red: 0.09, green: 0.19, blue: 0.31)
    static let positive = Color(red: 0.20, green: 0.92, blue: 0.55)

    enum Metrics {
        static let compactSpacing: CGFloat = 8
        static let standardSpacing: CGFloat = 12
        static let sectionSpacing: CGFloat = 20
        static let smallRadius: CGFloat = 14
        static let controlRadius: CGFloat = 18
        static let panelRadius: CGFloat = 24
        static let minimumTapTarget: CGFloat = 44
        static let floatingControlSize: CGFloat = 52
        static let horizontalPadding: CGFloat = 20
        static let shadowRadius: CGFloat = 12
        static let strokeWidth: CGFloat = 1
    }

    enum Motion {
        static let press = Animation.snappy(duration: 0.16)
        static let transition = Animation.snappy(duration: 0.24)
    }

    static let surfaceStroke = Color.white.opacity(0.16)
    static let emphasizedSurfaceStroke = Color.white.opacity(0.28)
    static let surfaceShadow = Color.black.opacity(0.24)

    static let topScrim = LinearGradient(
        colors: [.black.opacity(0.72), .black.opacity(0.30), .clear],
        startPoint: .top,
        endPoint: .bottom
    )

    static let bottomScrim = LinearGradient(
        colors: [.clear, .black.opacity(0.40), navy.opacity(0.92)],
        startPoint: .top,
        endPoint: .bottom
    )
}

extension WorldID {
    var accentColor: Color {
        switch self {
        case .earth: GoalRushTheme.cyan
        case .mars: Color(red: 0.92, green: 0.30, blue: 0.22)
        }
    }

    var secondaryColor: Color {
        switch self {
        case .earth: GoalRushTheme.grass
        case .mars: Color(red: 0.66, green: 0.24, blue: 0.86)
        }
    }

    var icon: String {
        switch self {
        case .earth: "globe.americas.fill"
        case .mars: "circle.grid.cross.fill"
        }
    }
}

struct GameCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background {
                LinearGradient(
                    colors: [GoalRushTheme.surfaceRaised.opacity(0.96), GoalRushTheme.surface.opacity(0.96)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(.rect(cornerRadius: 22))
            }
            .overlay { RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.13)) }
            .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
    }
}

struct PrimaryGameButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(GoalRushTheme.navy)
            .background {
                LinearGradient(
                    colors: isEnabled ? [GoalRushTheme.gold, Color(red: 1, green: 0.52, blue: 0.08)] : [.gray.opacity(0.55), .gray.opacity(0.38)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(.rect(cornerRadius: 18))
            }
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(isEnabled ? 0.32 : 0.10)) }
            .shadow(color: isEnabled ? GoalRushTheme.gold.opacity(configuration.isPressed ? 0.15 : 0.30) : .clear, radius: 10, y: 5)
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
            .font(.subheadline.bold())
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .foregroundStyle(.white)
            .background(GoalRushTheme.blue.opacity(configuration.isPressed ? 0.65 : 0.92), in: .capsule)
            .overlay { Capsule().stroke(.white.opacity(0.22)) }
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
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(.white)
            .background {
                LinearGradient(
                    colors: [GoalRushTheme.surfaceRaised, GoalRushTheme.surface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(.rect(cornerRadius: 17))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 17)
                    .stroke(configuration.isPressed ? GoalRushTheme.cyan.opacity(0.7) : .white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.55)
            .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: configuration.isPressed)
    }
}
