import SwiftUI

struct PlanetDestinationNode: View {
    let destination: WorldJourneyDestination
    let progress: PlayerProgress
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                ZStack {
                    PlanetArtwork(destinationID: destination.id)
                        .frame(width: artworkSize, height: artworkSize)
                        .saturation(isUnlocked ? 1 : 0.12)
                        .opacity(isUnlocked ? 1 : 0.70)
                    if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(GoalRushTheme.Typography.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.72), in: .circle)
                            .overlay { Circle().stroke(.white.opacity(0.50), lineWidth: 2) }
                    }
                }

                VStack(spacing: 2) {
                    Text(destination.name)
                        .font(GoalRushTheme.Typography.headline)
                        .foregroundStyle(.white)
                    Text(statusText)
                        .font(GoalRushTheme.Typography.captionEmphasized)
                        .foregroundStyle(isUnlocked ? GoalRushTheme.gold : .white.opacity(0.68))
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.62), in: ComicPanelShape(cut: 6))
            }
            .frame(minWidth: 150, minHeight: 160)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("planet-\(destination.id)")
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    private var isUnlocked: Bool {
        switch destination.action {
        case .world(let world):
            GameContent.isWorldUnlocked(world, progress: progress)
        case .newGamePlus:
            progress.canBeginNextCampaignCycle
        }
    }

    private var artworkSize: CGFloat {
        switch destination.id {
        case "jupiter", "saturn", "uranus", "neptune", "new-game-plus": 126
        default: 104
        }
    }

    private var statusText: String {
        guard case .world(let world) = destination.action else {
            return progress.canBeginNextCampaignCycle
                ? "START NG+\(progress.campaignCycle + 1)"
                : progress.campaignCycle == 0
                    ? "CLEAR NEPTUNE"
                    : "CLEAR NG+\(progress.campaignCycle)"
        }
        guard isUnlocked else {
            return switch world {
            case .earth: "AVAILABLE"
            case .moon: "CLEAR EARTH"
            case .mars: "CLEAR MOON"
            case .jupiter: "CLEAR MARS"
            case .saturn: "CLEAR JUPITER"
            case .uranus: "CLEAR SATURN"
            case .neptune: "CLEAR URANUS"
            }
        }
        let levels = GameContent.levels(in: world)
        let completed = levels.count {
            progress.hasClearedCurrentCampaignLevel($0.number)
        }
        return "\(completed)/\(levels.count) CLEARED"
    }

    private var accessibilityLabel: String {
        "\(destination.name), \(isUnlocked ? "unlocked" : "locked"), \(statusText)"
    }

    private var accessibilityHint: String {
        guard isUnlocked else { return statusText }
        return switch destination.action {
        case .world:
            "Opens the \(destination.name) landmark map"
        case .newGamePlus:
            "Explains the permanent New Game Plus reset before asking for confirmation"
        }
    }
}

struct PlanetDestinationRow: View {
    let destination: WorldJourneyDestination
    let progress: PlayerProgress
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                PlanetArtwork(destinationID: destination.id)
                    .frame(width: 72, height: 72)
                    .saturation(isUnlocked ? 1 : 0.1)
                VStack(alignment: .leading, spacing: 3) {
                    Text(destination.name)
                        .font(GoalRushTheme.Typography.headline)
                    Text(destination.subtitle)
                        .font(GoalRushTheme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                    Text(statusText)
                        .font(GoalRushTheme.Typography.captionEmphasized)
                        .foregroundStyle(
                            isUnlocked ? GoalRushTheme.gold : .secondary
                        )
                }
                Spacer()
                Image(systemName: isUnlocked ? "chevron.right" : "lock.fill")
            }
            .padding(GoalRushTheme.Metrics.standardSpacing)
            .frame(maxWidth: .infinity, minHeight: 88)
            .gameSurface(.hud)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(destination.name), \(isUnlocked ? "unlocked" : "locked"), \(statusText)"
        )
        .accessibilityHint(accessibilityHint)
    }

    private var isUnlocked: Bool {
        switch destination.action {
        case .world(let world):
            GameContent.isWorldUnlocked(world, progress: progress)
        case .newGamePlus:
            progress.canBeginNextCampaignCycle
        }
    }

    private var statusText: String {
        switch destination.action {
        case .world(let world):
            guard isUnlocked else { return "Complete the previous world" }
            let levels = GameContent.levels(in: world)
            let completed = levels.count {
                progress.hasClearedCurrentCampaignLevel($0.number)
            }
            return "\(completed) of \(levels.count) cleared"
        case .newGamePlus:
            if progress.canBeginNextCampaignCycle {
                return "Start NG+\(progress.campaignCycle + 1)"
            }
            return progress.campaignCycle == 0
                ? "Clear Neptune"
                : "Clear NG+\(progress.campaignCycle)"
        }
    }

    private var accessibilityHint: String {
        guard isUnlocked else { return statusText }
        return switch destination.action {
        case .world:
            "Opens the landmark map"
        case .newGamePlus:
            "Explains the permanent New Game Plus reset before asking for confirmation"
        }
    }
}

private struct PlanetArtwork: View {
    let destinationID: String

    @ViewBuilder
    var body: some View {
        if destinationID == "new-game-plus" {
            NewGamePlusGlyph()
                .shadow(color: glowColor.opacity(0.65), radius: 16)
                .accessibilityHidden(true)
        } else {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .shadow(color: glowColor.opacity(0.55), radius: 16)
                .accessibilityHidden(true)
        }
    }

    private var assetName: String {
        switch destinationID {
        case "earth": "PlanetEarth"
        case "moon": "PlanetMoon"
        case "mars": "PlanetMars"
        case "saturn": "PlanetSaturn"
        case "uranus": "PlanetUranus"
        case "neptune": "PlanetNeptune"
        default: "PlanetJupiter"
        }
    }

    private var glowColor: Color {
        switch destinationID {
        case "earth": GoalRushTheme.cyan
        case "moon": Color(red: 0.68, green: 0.74, blue: 1)
        case "mars": GoalRushTheme.marsRust
        case "jupiter": Color(red: 1, green: 0.60, blue: 0.18)
        case "saturn": Color(red: 1, green: 0.82, blue: 0.40)
        case "uranus": Color(red: 0.30, green: 0.94, blue: 1)
        case "neptune": Color(red: 0.18, green: 0.46, blue: 1)
        case "new-game-plus": Color(red: 0.76, green: 0.42, blue: 1)
        default: GoalRushTheme.gold
        }
    }
}

private struct NewGamePlusGlyph: View {
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Ellipse()
                    .stroke(
                        index == 0 ? Color.white : Color.purple.opacity(0.82),
                        lineWidth: CGFloat(5 - index)
                    )
                    .frame(
                        width: CGFloat(112 - index * 22),
                        height: CGFloat(38 - index * 6)
                    )
                    .rotationEffect(.degrees(-22))
            }
            Circle()
                .fill(.white)
                .frame(width: 16, height: 16)
                .shadow(color: .purple, radius: 12)

            Image(systemName: "plus")
                .font(GoalRushTheme.Typography.title2)
                .foregroundStyle(GoalRushTheme.navy)
                .accessibilityHidden(true)
        }
    }
}
