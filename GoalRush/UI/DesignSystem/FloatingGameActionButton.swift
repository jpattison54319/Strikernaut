import SwiftUI

struct FloatingGameActionButton: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let badge: String?
    let accent: Color
    let action: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        badge: String? = nil,
        accent: Color = GoalRushTheme.cyan,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.badge = badge
        self.accent = accent
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: systemImage)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(accent)
                        .frame(
                            width: GoalRushTheme.Metrics.floatingControlSize,
                            height: GoalRushTheme.Metrics.floatingControlSize
                        )
                        .background(GoalRushTheme.navy.opacity(0.88), in: .circle)
                        .overlay {
                            Circle()
                                .stroke(accent.opacity(0.65), lineWidth: GoalRushTheme.Metrics.strokeWidth)
                        }
                        .shadow(
                            color: GoalRushTheme.surfaceShadow,
                            radius: GoalRushTheme.Metrics.shadowRadius,
                            y: 5
                        )

                    if let badge, !badge.isEmpty {
                        GameStatusBadge(text: badge, tone: .attention)
                            .fixedSize()
                            .offset(x: 10, y: -7)
                    }
                }

                VStack(spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.78))
                    }
                }
                .multilineTextAlignment(.center)
            }
            .contentShape(.rect)
            .frame(minWidth: GoalRushTheme.Metrics.minimumTapTarget)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}
