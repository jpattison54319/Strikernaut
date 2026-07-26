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
                        .frame(width: destination.id == "jupiter" ? 126 : 104, height: destination.id == "jupiter" ? 126 : 104)
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
        .accessibilityHint(isUnlocked ? "Opens the \(destination.name) landmark map" : statusText)
    }

    private var isUnlocked: Bool {
        guard let world = destination.world else { return false }
        return GameContent.isWorldUnlocked(world, progress: progress)
    }

    private var statusText: String {
        guard let world = destination.world else { return "COMING SOON" }
        guard isUnlocked else {
            return world == .moon ? "CLEAR EARTH" : "CLEAR MOON"
        }
        let levels = GameContent.levels(in: world)
        let completed = levels.filter { progress.levelRecords[$0.number]?.completed == true }.count
        return "\(completed)/\(levels.count) CLEARED"
    }

    private var accessibilityLabel: String {
        "\(destination.name), \(isUnlocked ? "unlocked" : "locked"), \(statusText)"
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
                }
                Spacer()
                Image(systemName: isUnlocked ? "chevron.right" : "lock.fill")
            }
            .padding(GoalRushTheme.Metrics.standardSpacing)
            .frame(maxWidth: .infinity, minHeight: 88)
            .gameSurface(.hud)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(destination.name), \(isUnlocked ? "unlocked" : "locked")")
    }

    private var isUnlocked: Bool {
        destination.world.map { GameContent.isWorldUnlocked($0, progress: progress) } ?? false
    }
}

private struct PlanetArtwork: View {
    let destinationID: String

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .shadow(color: glowColor.opacity(0.55), radius: 16)
        .accessibilityHidden(true)
    }

    private var assetName: String {
        switch destinationID {
        case "earth": "PlanetEarth"
        case "moon": "PlanetMoon"
        case "mars": "PlanetMars"
        default: "PlanetJupiter"
        }
    }

    private var glowColor: Color {
        switch destinationID {
        case "earth": GoalRushTheme.cyan
        case "moon": Color(red: 0.68, green: 0.74, blue: 1)
        case "mars": GoalRushTheme.marsRust
        default: GoalRushTheme.gold
        }
    }
}
