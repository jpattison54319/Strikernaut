import SwiftUI

struct HomeAccessibilityAction: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let badge: String?
    let accent: Color
    let action: () -> Void

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        badge: String? = nil,
        accent: Color,
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
            VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.compactSpacing) {
                Label {
                    Text(title)
                        .foregroundStyle(.white)
                } icon: {
                    Image(systemName: systemImage)
                        .foregroundStyle(accent)
                }
                .font(GoalRushTheme.Typography.headline)

                Text(subtitle)
                    .font(GoalRushTheme.Typography.subheadline)
                    .foregroundStyle(.white.opacity(0.72))

                if let badge {
                    GameStatusBadge(text: badge, tone: .attention)
                }
            }
            .multilineTextAlignment(.leading)
            .foregroundStyle(.white)
            .padding(GoalRushTheme.Metrics.standardSpacing)
            .frame(maxWidth: .infinity, minHeight: GoalRushTheme.Metrics.minimumTapTarget)
            .gameSurface(.panel)
        }
        .buttonStyle(.plain)
    }
}
