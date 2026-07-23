import SpriteKit
import SwiftUI

struct LockerAvatarView: View {
    let loadout: GearLoadout
    @State private var scene: LockerPreviewScene

    init(loadout: GearLoadout) {
        self.loadout = loadout
        _scene = State(initialValue: LockerPreviewScene(loadout: loadout))
    }

    var body: some View {
        SpriteView(scene: scene, preferredFramesPerSecond: 30, options: [.allowsTransparency])
            .onChange(of: loadout) { _, newValue in
                scene.update(loadout: newValue)
            }
    }
}

struct GearCycleRow: View {
    let slot: GearSlot
    let itemName: String
    let canCycle: Bool
    let selected: Bool
    let showsNewBadge: Bool
    let previous: () -> Void
    let next: () -> Void

    var body: some View {
        HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
            Button("Previous \(slot.title) gear", systemImage: "chevron.left", action: previous)
                .labelStyle(.iconOnly)
                .gearArrowStyle(enabled: canCycle, selected: selected)
                .accessibilityIdentifier("gear-\(slot.rawValue)-previous")

            Spacer(minLength: 4)

            VStack(spacing: 2) {
                Label(slot.title, systemImage: slot.icon)
                    .font(.caption.bold())
                Text(itemName)
                    .font(.caption2)
                    .lineLimit(1)
                if showsNewBadge {
                    GameStatusBadge(text: "NEW", tone: .attention)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .accessibilityElement(children: .combine)

            Spacer(minLength: 4)

            Button("Next \(slot.title) gear", systemImage: "chevron.right", action: next)
                .labelStyle(.iconOnly)
                .gearArrowStyle(enabled: canCycle, selected: selected)
                .accessibilityIdentifier("gear-\(slot.rawValue)-next")
        }
        .padding(.horizontal, GoalRushTheme.Metrics.standardSpacing)
        .frame(maxWidth: .infinity, minHeight: GoalRushTheme.Metrics.minimumTapTarget)
        .disabled(!canCycle)
    }
}

private extension View {
    func gearArrowStyle(enabled: Bool, selected: Bool) -> some View {
        self
            .font(.headline.bold())
            .foregroundStyle(enabled ? .white : .white.opacity(0.30))
            .frame(width: GoalRushTheme.Metrics.minimumTapTarget, height: GoalRushTheme.Metrics.minimumTapTarget)
            .background(.black.opacity(selected ? 0.58 : 0.42), in: .circle)
            .overlay {
                Circle().stroke(selected ? GoalRushTheme.cyan.opacity(0.72) : .white.opacity(0.15))
            }
            .contentShape(.circle)
    }
}
