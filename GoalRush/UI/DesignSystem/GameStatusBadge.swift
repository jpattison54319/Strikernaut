import SwiftUI

enum GameStatusTone {
    case neutral
    case info
    case positive
    case attention
}

struct GameStatusBadge: View {
    let text: String
    let tone: GameStatusTone

    var body: some View {
        Text(text)
            .font(GoalRushTheme.Typography.caption2)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, GoalRushTheme.Metrics.compactSpacing)
            .padding(.vertical, 4)
            .background(backgroundColor, in: ComicPanelShape(cut: 5))
            .overlay {
                ComicPanelShape(cut: 5)
                    .stroke(borderColor, lineWidth: GoalRushTheme.Metrics.strokeWidth)
            }
    }

    private var foregroundColor: Color {
        switch tone {
        case .neutral, .info:
            .white
        case .positive, .attention:
            GoalRushTheme.navy
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .neutral:
            GoalRushTheme.surfaceRaised.opacity(0.96)
        case .info:
            GoalRushTheme.blue.opacity(0.94)
        case .positive:
            GoalRushTheme.positive.opacity(0.88)
        case .attention:
            GoalRushTheme.gold
        }
    }

    private var borderColor: Color {
        switch tone {
        case .neutral:
            GoalRushTheme.surfaceStroke
        case .info:
            GoalRushTheme.cyan.opacity(0.72)
        case .positive:
            Color.white.opacity(0.28)
        case .attention:
            Color.white.opacity(0.42)
        }
    }
}
