import SwiftUI

/// Compact arena picker retained for Endless mode. Campaign navigation uses
/// the full-screen planet journey instead.
struct WorldSelectionBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let identifierPrefix: String
    let selectedWorld: WorldID
    let progress: PlayerProgress
    let onSelect: (WorldID) -> Void

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: GoalRushTheme.Metrics.compactSpacing))
            : AnyLayout(HStackLayout(spacing: GoalRushTheme.Metrics.compactSpacing))

        layout {
            ForEach(GameContent.worlds) { world in
                WorldSelectionButton(
                    identifier: "\(identifierPrefix)\(world.id.rawValue)",
                    world: world,
                    selected: selectedWorld == world.id,
                    unlocked: GameContent.isWorldUnlocked(world.id, progress: progress),
                    onSelect: { onSelect(world.id) }
                )
            }
        }
    }
}

private struct WorldSelectionButton: View {
    let identifier: String
    let world: WorldDefinition
    let selected: Bool
    let unlocked: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                Image(systemName: unlocked ? world.id.icon : "lock.fill")
                    .accessibilityHidden(true)
                Text(world.name)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(GoalRushTheme.Typography.subheadlineEmphasized)
            .foregroundStyle(selected ? GoalRushTheme.navy : .white.opacity(unlocked ? 1 : 0.58))
            .frame(maxWidth: .infinity, minHeight: GoalRushTheme.Metrics.minimumTapTarget)
            .padding(.horizontal, GoalRushTheme.Metrics.standardSpacing)
            .background(
                selected ? AnyShapeStyle(world.id.accentColor) : AnyShapeStyle(GoalRushTheme.navy.opacity(0.76)),
                in: ComicPanelShape(cut: GoalRushTheme.Metrics.smallRadius)
            )
            .overlay {
                ComicPanelShape(cut: GoalRushTheme.Metrics.smallRadius)
                    .stroke(
                        selected ? .white.opacity(0.34) : GoalRushTheme.surfaceStroke,
                        lineWidth: selected ? 2 : GoalRushTheme.Metrics.strokeWidth
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(unlocked ? "Selects the \(world.name) arena" : unlockCondition)
    }

    private var accessibilityLabel: String {
        unlocked
            ? "\(world.name) arena, \(selected ? "selected" : "unlocked")"
            : "\(world.name) arena, locked, \(unlockCondition)"
    }

    private var unlockCondition: String {
        switch world.id {
        case .earth:
            "Available now"
        case .moon:
            "Clear Earth challenge 10 to unlock"
        case .mars:
            "Clear Moon challenge 10 to unlock"
        }
    }
}
