import SwiftUI

struct GameSurface {
    enum Style {
        case hud
        case panel
        case modal
    }
}

extension View {
    func gameSurface(_ style: GameSurface.Style) -> some View {
        modifier(GameSurfaceModifier(style: style))
    }
}

private struct GameSurfaceModifier: ViewModifier {
    let style: GameSurface.Style

    func body(content: Content) -> some View {
        content
            .background(fill, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(stroke, lineWidth: GoalRushTheme.Metrics.strokeWidth)
            }
            .shadow(
                color: shadowColor,
                radius: GoalRushTheme.Metrics.shadowRadius,
                y: shadowOffset
            )
    }

    private var fill: AnyShapeStyle {
        switch style {
        case .hud:
            AnyShapeStyle(GoalRushTheme.navy.opacity(0.78))
        case .panel:
            AnyShapeStyle(
                LinearGradient(
                    colors: [GoalRushTheme.surfaceRaised.opacity(0.96), GoalRushTheme.surface.opacity(0.94)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .modal:
            AnyShapeStyle(GoalRushTheme.surface.opacity(0.98))
        }
    }

    private var cornerRadius: CGFloat {
        switch style {
        case .hud:
            GoalRushTheme.Metrics.smallRadius
        case .panel:
            GoalRushTheme.Metrics.controlRadius
        case .modal:
            GoalRushTheme.Metrics.panelRadius
        }
    }

    private var stroke: Color {
        switch style {
        case .hud, .panel:
            GoalRushTheme.surfaceStroke
        case .modal:
            GoalRushTheme.emphasizedSurfaceStroke
        }
    }

    private var shadowColor: Color {
        style == .hud ? .clear : GoalRushTheme.surfaceShadow
    }

    private var shadowOffset: CGFloat {
        style == .modal ? 8 : 5
    }
}
