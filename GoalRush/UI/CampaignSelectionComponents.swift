import SwiftUI

struct CampaignSelectionStage: View {
    let world: WorldDefinition
    let progress: PlayerProgress
    let onSelectWorld: (WorldID) -> Void
    let onSelectLevel: (LevelDefinition) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.sectionSpacing) {
            WorldSelectionBar(
                identifierPrefix: "world-",
                selectedWorld: world.id,
                progress: progress,
                onSelect: onSelectWorld
            )

            CampaignWorldSummary(world: world, progress: progress)

            VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
                Text("\(world.name) Levels")
                    .font(GoalRushTheme.Typography.title2)
                    .foregroundStyle(.white)

                CampaignLevelGrid(
                    levels: GameContent.levels(in: world.id),
                    progress: progress,
                    onSelect: onSelectLevel
                )
            }
        }
    }
}

struct CampaignLevelPreview: View {
    let level: LevelDefinition
    let record: LevelRecord?
    let maximumStamina: Double
    let onPlay: () -> Void

    var body: some View {
        GameSheetScaffold(
            title: "Challenge \(level.worldLevel): \(level.name)",
            subtitle: GameContent.world(level.world).name
        ) {
            VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.sectionSpacing) {
                previewStatus
                objectivePanel
                rewardPanel
                starPanel
                playButton
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("level-preview")
        }
    }

    private var previewStatus: some View {
        Label(
            record?.completed == true ? "Challenge cleared" : "Ready to play",
            systemImage: record?.completed == true ? "checkmark.seal.fill" : "flag.checkered"
        )
        .font(GoalRushTheme.Typography.headline)
        .foregroundStyle(record?.completed == true ? GoalRushTheme.positive : GoalRushTheme.cyan)
    }

    private var objectivePanel: some View {
        PreviewFact(
            icon: level.hasBoss ? "crown.fill" : "scope",
            title: "Objective",
            value: level.subtitle
        )
    }

    private var rewardPanel: some View {
        PreviewFact(
            icon: "hexagon.fill",
            title: record?.completed == true ? "Replay Reward" : "First-Clear Reward",
            value: "+\(record?.completed == true ? level.replayBonus : level.firstClearBonus) Training Tokens"
        )
    }

    private var starPanel: some View {
        VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.compactSpacing) {
            Text("Best Result")
                .font(GoalRushTheme.Typography.captionEmphasized)
                .foregroundStyle(.white.opacity(0.68))

            HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: index < stars ? "star.fill" : "star")
                            .foregroundStyle(GoalRushTheme.gold)
                    }
                }
                .accessibilityHidden(true)

                Text(record?.completed == true ? "\(stars) of 3 stars • \(record?.bestTokens ?? 0) tokens" : "No result yet")
                    .font(GoalRushTheme.Typography.subheadlineEmphasized)
                    .foregroundStyle(.white)
            }
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gameSurface(.panel)
        .accessibilityElement(children: .combine)
    }

    private var playButton: some View {
        Button(action: onPlay) {
            Label("Play Challenge \(level.worldLevel)", systemImage: "play.fill")
        }
        .buttonStyle(GameLaunchButtonStyle())
        .accessibilityIdentifier("level-preview-play")
    }

    private var stars: Int {
        guard record?.completed == true, maximumStamina > 0 else { return 0 }
        return StarRating.stars(
            staminaFraction: min(1, (record?.bestStamina ?? 0) / maximumStamina)
        )
    }
}

struct CampaignInfoSheet: View {
    let world: WorldDefinition

    var body: some View {
        GameSheetScaffold(
            title: "Campaign Guide",
            subtitle: "Choose a world, inspect a challenge, then play when you are ready."
        ) {
            VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
                PreviewFact(
                    icon: "lock.open.fill",
                    title: "Unlocking",
                    value: "Clear each challenge to unlock the next. Clear Earth challenge 10 to reach Mars."
                )
                PreviewFact(
                    icon: "person.crop.circle.badge.plus",
                    title: "\(world.name) Reward",
                    value: rewardDescription
                )
            }
        }
    }

    private var rewardDescription: String {
        let level = world.finalLevel
        if let character = CharacterCatalog.characters.first(where: { $0.unlockLevel == level }) {
            return "Clear \(world.name) to unlock \(character.name) and \(character.abilityName)."
        }
        return "Clear \(world.name) to unlock the next arena."
    }
}

private struct CampaignWorldSummary: View {
    let world: WorldDefinition
    let progress: PlayerProgress

    var body: some View {
        HStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            Image(systemName: world.id.icon)
                .font(GoalRushTheme.Typography.title2)
                .foregroundStyle(world.id.accentColor)
                .frame(width: GoalRushTheme.Metrics.minimumTapTarget)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(world.chapter) • \(world.subtitle)")
                    .font(GoalRushTheme.Typography.captionEmphasized)
                    .foregroundStyle(world.id.accentColor)
                Text("\(completedCount) of \(levelCount) challenges cleared")
                    .font(GoalRushTheme.Typography.headline)
                    .foregroundStyle(.white)
                Text(rewardText)
                    .font(GoalRushTheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer(minLength: 0)
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .gameSurface(.hud)
        .accessibilityElement(children: .combine)
    }

    private var levels: [LevelDefinition] {
        GameContent.levels(in: world.id)
    }

    private var completedCount: Int {
        levels.filter { progress.levelRecords[$0.number]?.completed == true }.count
    }

    private var levelCount: Int {
        levels.count
    }

    private var rewardText: String {
        let character = CharacterCatalog.characters.first { $0.unlockLevel == world.finalLevel }
        let earned = character.map { progress.unlockedCharacters.contains($0.id) } ?? false
        return earned
            ? "\(character?.name ?? "Hero") unlocked"
            : "World reward: \(character?.name ?? "New hero")"
    }
}

private struct CampaignLevelGrid: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let levels: [LevelDefinition]
    let progress: PlayerProgress
    let onSelect: (LevelDefinition) -> Void

    var body: some View {
        LazyVGrid(columns: columns, spacing: GoalRushTheme.Metrics.compactSpacing) {
            ForEach(levels) { level in
                let unlocked = level.number <= progress.highestUnlockedLevel
                CampaignLevelNode(
                    level: level,
                    record: progress.levelRecords[level.number],
                    maximumStamina: PlayerStats(progress: progress).maxStamina,
                    unlocked: unlocked,
                    onSelect: { onSelect(level) }
                )
            }
        }
    }

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: GoalRushTheme.Metrics.compactSpacing), count: count)
    }
}

private struct CampaignLevelNode: View {
    let level: LevelDefinition
    let record: LevelRecord?
    let maximumStamina: Double
    let unlocked: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                Text("\(level.worldLevel)")
                    .font(GoalRushTheme.Typography.metric(size: 24, relativeTo: .title2))
                    .foregroundStyle(unlocked ? level.world.accentColor : .white.opacity(0.44))
                    .frame(minWidth: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(level.name)
                        .font(GoalRushTheme.Typography.subheadlineEmphasized)
                        .foregroundStyle(unlocked ? .white : .white.opacity(0.54))
                        .lineLimit(2)
                    statusLabel
                }

                Spacer(minLength: 0)
            }
            .padding(GoalRushTheme.Metrics.standardSpacing)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .gameSurface(.hud)
        }
        .buttonStyle(CampaignLevelNodeButtonStyle())
        .disabled(!unlocked)
        .opacity(unlocked ? 1 : 0.70)
        .accessibilityIdentifier("level-\(level.number)")
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(unlocked ? "Opens the challenge preview" : unlockCondition)
    }

    @ViewBuilder
    private var statusLabel: some View {
        if !unlocked {
            Label("Locked", systemImage: "lock.fill")
                .foregroundStyle(.white.opacity(0.54))
        } else if record?.completed == true {
            Label("\(stars) stars", systemImage: "star.fill")
                .foregroundStyle(GoalRushTheme.gold)
        } else {
            Label("Ready", systemImage: "flag.fill")
                .foregroundStyle(GoalRushTheme.cyan)
        }
    }

    private var stars: Int {
        guard record?.completed == true, maximumStamina > 0 else { return 0 }
        return StarRating.stars(
            staminaFraction: min(1, (record?.bestStamina ?? 0) / maximumStamina)
        )
    }

    private var accessibilityLabel: String {
        if !unlocked {
            return "Challenge \(level.worldLevel), \(level.name), locked, \(unlockCondition)"
        }
        if record?.completed == true {
            return "Challenge \(level.worldLevel), \(level.name), completed, \(stars) of 3 stars, best \(record?.bestTokens ?? 0) tokens"
        }
        return "Challenge \(level.worldLevel), \(level.name), ready"
    }

    private var unlockCondition: String {
        if level.worldLevel > 1 {
            return "Clear \(GameContent.world(level.world).name) challenge \(level.worldLevel - 1) to unlock"
        }

        switch level.world {
        case .earth:
            return "Available now"
        case .mars:
            return "Clear Earth challenge 10 to unlock"
        }
    }
}

private struct CampaignLevelNodeButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.98)
            .animation(reduceMotion ? nil : GoalRushTheme.Motion.press, value: configuration.isPressed)
    }
}

private struct PreviewFact: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: GoalRushTheme.Metrics.standardSpacing) {
            Image(systemName: icon)
                .font(GoalRushTheme.Typography.headline)
                .foregroundStyle(GoalRushTheme.gold)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(GoalRushTheme.Typography.captionEmphasized)
                    .foregroundStyle(.white.opacity(0.68))
                Text(value)
                    .font(GoalRushTheme.Typography.headline)
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 0)
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .gameSurface(.panel)
        .accessibilityElement(children: .combine)
    }
}
