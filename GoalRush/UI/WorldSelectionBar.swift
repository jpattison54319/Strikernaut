import SwiftUI

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
            .font(.subheadline.bold())
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity, minHeight: GoalRushTheme.Metrics.minimumTapTarget)
            .padding(.horizontal, GoalRushTheme.Metrics.standardSpacing)
            .background(backgroundStyle, in: .rect(cornerRadius: GoalRushTheme.Metrics.smallRadius))
            .overlay {
                RoundedRectangle(cornerRadius: GoalRushTheme.Metrics.smallRadius)
                    .stroke(borderColor, lineWidth: selected ? 2 : GoalRushTheme.Metrics.strokeWidth)
            }
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(unlocked ? "Selects the \(world.name) world" : unlockCondition)
    }

    private var foregroundColor: Color {
        if selected { return GoalRushTheme.navy }
        return unlocked ? .white : .white.opacity(0.58)
    }

    private var backgroundStyle: AnyShapeStyle {
        selected
            ? AnyShapeStyle(world.id.accentColor)
            : AnyShapeStyle(GoalRushTheme.navy.opacity(0.76))
    }

    private var borderColor: Color {
        selected ? .white.opacity(0.34) : GoalRushTheme.surfaceStroke
    }

    private var accessibilityLabel: String {
        if !unlocked {
            return "\(world.name) world, locked, \(unlockCondition)"
        }
        return "\(world.name) world, \(selected ? "selected" : "unlocked")"
    }

    private var unlockCondition: String {
        switch world.id {
        case .earth:
            "Available now"
        case .mars:
            "Clear Earth challenge 10 to unlock"
        }
    }
}
