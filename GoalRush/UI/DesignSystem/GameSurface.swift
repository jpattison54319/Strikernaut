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
            .background(fill, in: ComicPanelShape(cut: cornerRadius))
            .background {
                ComicPanelShape(cut: cornerRadius)
                    .fill(shadowColor)
                    .offset(x: shadowOffset, y: shadowOffset)
            }
            .overlay {
                ComicInkTexture(opacity: style == .hud ? 0.07 : 0.12)
                    .clipShape(ComicPanelShape(cut: cornerRadius))
            }
            .overlay {
                ComicPanelShape(cut: cornerRadius)
                    .stroke(stroke, lineWidth: GoalRushTheme.Metrics.strokeWidth)
            }
    }

    private var fill: AnyShapeStyle {
        switch style {
        case .hud:
            AnyShapeStyle(GoalRushTheme.ink.opacity(0.86))
        case .panel:
            AnyShapeStyle(GoalRushTheme.surfaceRaised.opacity(0.97))
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
        style == .hud ? GoalRushTheme.ink.opacity(0.45) : GoalRushTheme.surfaceShadow
    }

    private var shadowOffset: CGFloat {
        style == .modal ? 6 : 4
    }
}
