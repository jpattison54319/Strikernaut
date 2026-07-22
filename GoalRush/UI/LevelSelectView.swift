import SwiftUI

struct LevelSelectView: View {
    @Environment(GameStore.self) private var store
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    worldPicker
                    worldReward
                    Text("\(selectedWorld.name) Levels")
                        .font(.title2.bold())

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(GameContent.levels(in: store.selectedWorld)) { level in
                            levelButton(level)
                        }
                    }
                }
                .padding()
            }
            .background(background)
            .navigationTitle("Campaign")
            .toolbar { toolbar }
            .onAppear {
                if !GameContent.isWorldUnlocked(store.selectedWorld, progress: store.progress) {
                    store.selectedWorld = .earth
                }
            }
            .sensoryFeedback(trigger: store.selectedWorld) { _, _ in
                store.settings.hapticsEnabled ? .selection : nil
            }
        }
    }

    private var worldPicker: some View {
        let world = selectedWorld
        let unlocked = GameContent.isWorldUnlocked(world.id, progress: store.progress)
        let completed = GameContent.levels(in: world.id).filter { store.progress.levelRecords[$0.number]?.completed == true }.count
        return VStack(spacing: 12) {
            HStack(spacing: 10) {
                ForEach(GameContent.worlds) { option in
                    let optionUnlocked = GameContent.isWorldUnlocked(option.id, progress: store.progress)
                    Button {
                        store.selectWorld(option.id)
                    } label: {
                        Label(option.name, systemImage: optionUnlocked ? option.id.icon : "lock.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(store.selectedWorld == option.id ? GoalRushTheme.navy : (optionUnlocked ? .white : .secondary))
                            .background(store.selectedWorld == option.id ? option.id.accentColor : .white.opacity(0.07), in: .capsule)
                            .overlay { Capsule().stroke(store.selectedWorld == option.id ? .white.opacity(0.28) : .white.opacity(0.12)) }
                    }
                    .buttonStyle(.plain)
                    .contentShape(.capsule)
                    .disabled(!optionUnlocked)
                    .accessibilityLabel("\(option.name) world, \(optionUnlocked ? "unlocked" : "locked")")
                    .accessibilityIdentifier("world-\(option.id.rawValue)")
                }
            }
            .zIndex(1)

            WorldCampaignCard(
                world: world,
                unlocked: unlocked,
                completedCount: completed
            )
        }
    }

    private var worldReward: some View {
        let earned = store.progress.unlockedGear.isSuperset(of: Set(selectedWorld.gearRewards))
        return HStack(spacing: 10) {
            Image(systemName: earned ? "checkmark.seal.fill" : "tshirt.fill")
                .font(.headline)
                .foregroundStyle(earned ? GoalRushTheme.positive : GoalRushTheme.gold)
                .frame(width: 36, height: 36)
                .background((earned ? GoalRushTheme.positive : GoalRushTheme.gold).opacity(0.12), in: .rect(cornerRadius: 11))
            Text(earned ? "\(selectedWorld.gearSetName) unlocked" : "Clear \(selectedWorld.name) • Earn \(selectedWorld.gearSetName)")
                .font(.subheadline.bold())
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.12)) }
        .accessibilityElement(children: .combine)
    }

    private func levelButton(_ level: LevelDefinition) -> some View {
        let unlocked = level.number <= store.progress.highestUnlockedLevel
        let record = store.progress.levelRecords[level.number]
        return Button {
            store.start(level: level.number)
        } label: {
            LevelCardView(level: level, unlocked: unlocked, record: record)
        }
        .buttonStyle(LevelCardButtonStyle())
        .disabled(!unlocked)
        .accessibilityLabel(levelAccessibilityLabel(level, unlocked: unlocked, record: record))
        .accessibilityHint(unlocked ? "Starts challenge \(level.worldLevel)" : "Clear the previous challenge to unlock")
        .accessibilityIdentifier("level-\(level.number)")
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Home", systemImage: "chevron.left") { store.route = .home }
        }
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 5) {
                Image(systemName: "hexagon.fill")
                Text("\(store.progress.trainingTokens)").monospacedDigit()
            }
                .font(.subheadline.bold())
                .foregroundStyle(GoalRushTheme.gold)
                .accessibilityLabel("\(store.progress.trainingTokens) Training Tokens")
        }
    }

    private var selectedWorld: WorldDefinition { GameContent.world(store.selectedWorld) }

    private var background: some View {
        LinearGradient(
            colors: [GoalRushTheme.navy, store.selectedWorld.secondaryColor.opacity(0.34), GoalRushTheme.navy],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func levelAccessibilityLabel(_ level: LevelDefinition, unlocked: Bool, record: LevelRecord?) -> String {
        if !unlocked { return "Challenge \(level.worldLevel), \(level.name), locked" }
        if record?.completed == true {
            let stars = StarRating.stars(staminaFraction: min(1, (record?.bestStamina ?? 0) / PlayerStats(progress: store.progress).maxStamina))
            return "Challenge \(level.worldLevel), \(level.name), completed, \(stars) of 3 stars, best \(record?.bestTokens ?? 0) tokens"
        }
        return "Challenge \(level.worldLevel), \(level.name), ready"
    }
}

private struct WorldCampaignCard: View {
    let world: WorldDefinition
    let unlocked: Bool
    let completedCount: Int

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                Image(world.heroAsset)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.82)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 3) {
                    Text(world.chapter)
                        .font(.caption2.bold())
                        .tracking(1)
                        .foregroundStyle(world.id.accentColor)
                    Text("\(world.name): \(world.subtitle)")
                        .font(.title3.bold())
                    Label(unlocked ? "\(completedCount) / 10" : "Locked", systemImage: unlocked ? "flag.checkered" : "lock.fill")
                        .font(.caption.bold())
                        .foregroundStyle(unlocked ? .white.opacity(0.80) : GoalRushTheme.gold)
                    if unlocked {
                        ProgressView(value: Double(completedCount), total: 10)
                            .tint(world.id.accentColor)
                            .scaleEffect(y: 1.4)
                            .padding(.top, 4)
                    }
                }
                .padding(16)
            }
        }
        .frame(height: 156)
        .clipShape(.rect(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(world.id.accentColor, lineWidth: 2) }
        .saturation(unlocked ? 1 : 0.18)
        .opacity(unlocked ? 1 : 0.62)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(world.name), \(unlocked ? "unlocked" : "locked"), \(completedCount) of 10 challenges cleared")
    }
}

private struct LevelCardView: View {
    @Environment(GameStore.self) private var store
    let level: LevelDefinition
    let unlocked: Bool
    let record: LevelRecord?

    private var completed: Bool { record?.completed == true }

    var body: some View {
        GameCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text("\(level.worldLevel)")
                        .font(.title.bold())
                        .foregroundStyle(unlocked ? .white : .secondary)
                    Spacer()
                    statusBadge
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(level.name)
                        .font(.headline)
                        .foregroundStyle(unlocked ? .white : .secondary)
                    Text(level.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(minHeight: 46, alignment: .topLeading)
                Divider().overlay(.white.opacity(0.10))
                HStack(spacing: 5) {
                    if !unlocked {
                        Image(systemName: "lock.fill")
                        Text("Clear previous")
                    } else if completed {
                        Image(systemName: "hexagon.fill")
                        Text("Best \(record?.bestTokens ?? 0)")
                    } else {
                        Image(systemName: "gift.fill")
                        Text("+\(level.firstClearBonus)")
                    }
                    Spacer(minLength: 2)
                    if unlocked { Image(systemName: "play.fill").foregroundStyle(GoalRushTheme.gold) }
                }
                .font(.caption.bold())
                .foregroundStyle(unlocked ? GoalRushTheme.gold : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .shimmer(active: unlocked && !completed)
        .opacity(unlocked ? 1 : 0.56)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if completed {
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < StarRating.stars(staminaFraction: min(1, (record?.bestStamina ?? 0) / PlayerStats(progress: store.progress).maxStamina)) ? "star.fill" : "star")
                        .font(.caption.bold())
                        .foregroundStyle(GoalRushTheme.gold)
                }
            }
            .accessibilityHidden(true)
        } else if unlocked {
            Text("READY")
                .foregroundStyle(GoalRushTheme.cyan)
                .font(.caption2.bold())
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(GoalRushTheme.cyan.opacity(0.12), in: .capsule)
        } else {
            Image(systemName: "lock.fill").foregroundStyle(.secondary)
        }
    }
}

private struct LevelCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? 0.06 : 0)
            .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: configuration.isPressed)
    }
}
