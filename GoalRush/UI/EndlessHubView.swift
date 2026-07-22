import SwiftUI

struct EndlessHubView: View {
    @Environment(GameStore.self) private var store
    @State private var showingInfo = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    intro
                    worldCards
                    permanentPower
                }
                .padding()
            }
            .background(background)
            .safeAreaInset(edge: .bottom) {
                Button("Start \(selectedWorld.name) Run", systemImage: "infinity") {
                    store.startEndless(world: store.selectedWorld)
                }
                .buttonStyle(PrimaryGameButton())
                .accessibilityIdentifier("start-endless")
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Endless")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Home", systemImage: "chevron.left") { store.route = .home }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Endless rules", systemImage: "info.circle") {
                        showingInfo = true
                    }
                    .labelStyle(.iconOnly)
                    HStack(spacing: 5) {
                        Image(systemName: "hexagon.fill")
                        Text("\(store.progress.trainingTokens)").monospacedDigit()
                    }
                        .font(.subheadline.bold())
                        .foregroundStyle(GoalRushTheme.gold)
                        .accessibilityLabel("\(store.progress.trainingTokens) Training Tokens")
                }
            }
            .sheet(isPresented: $showingInfo) {
                EndlessInfoView()
                    .presentationDetents([.medium])
            }
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

    private var intro: some View {
        Label("New power after every wave", systemImage: "sparkles")
            .font(.headline)
            .foregroundStyle(GoalRushTheme.cyan)
    }

    private var worldCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Arena")
                .font(.title2.bold())
            ForEach(GameContent.worlds) { world in
                let unlocked = GameContent.isWorldUnlocked(world.id, progress: store.progress)
                let record = store.progress.endlessRecord(for: world.id)
                Button {
                    store.selectWorld(world.id)
                } label: {
                    EndlessWorldCard(
                        world: world,
                        record: record,
                        unlocked: unlocked,
                        selected: store.selectedWorld == world.id
                    )
                }
                .buttonStyle(EndlessWorldButtonStyle())
                .disabled(!unlocked)
                .accessibilityIdentifier("endless-world-\(world.id.rawValue)")
            }
        }
    }

    private var permanentPower: some View {
        let equipped = store.progress.equippedGear.count
        let ranks = store.progress.upgradeRanks.values.reduce(0, +)
        return GameCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Permanent loadout active", systemImage: "checkmark.shield.fill")
                    .font(.headline)
                    .foregroundStyle(GoalRushTheme.positive)
                HStack(spacing: 10) {
                    powerStat(icon: "arrow.up.circle.fill", value: "\(ranks)", label: "Ranks")
                    powerStat(icon: "tshirt.fill", value: "\(equipped) / 5", label: "Gear")
                }
            }
        }
    }

    private func powerStat(icon: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(value, systemImage: icon)
                .font(.headline)
                .foregroundStyle(GoalRushTheme.gold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 14))
    }

    private var selectedWorld: WorldDefinition { GameContent.world(store.selectedWorld) }

    private var background: some View {
        LinearGradient(
            colors: [GoalRushTheme.navy, store.selectedWorld.secondaryColor.opacity(0.30), GoalRushTheme.navy],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct EndlessInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Label("Difficulty keeps scaling", systemImage: "flame.fill")
                Label("Choose a power after every wave", systemImage: "sparkles")
                Label("Boss wave every 5 waves", systemImage: "crown.fill")
                Label("Run powers reset when the run ends", systemImage: "arrow.counterclockwise")
                Label("Gear and Training upgrades always apply", systemImage: "checkmark.shield.fill")
            }
            .navigationTitle("Endless Rules")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct EndlessWorldCard: View {
    let world: WorldDefinition
    let record: EndlessRecord
    let unlocked: Bool
    let selected: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Image(world.heroAsset)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                LinearGradient(colors: [.black.opacity(0.02), .black.opacity(0.90)], startPoint: .top, endPoint: .bottom)
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Label(world.name, systemImage: world.id.icon)
                            .font(.title3.bold())
                        Text(unlocked ? world.subtitle : "Clear Earth to unlock")
                            .font(.caption)
                            .foregroundStyle(unlocked ? .white.opacity(0.72) : GoalRushTheme.gold)
                    }
                    Spacer()
                    if unlocked {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(record.bestWave > 0 ? "WAVE \(record.bestWave)" : "NEW")
                                .font(.headline.bold())
                                .foregroundStyle(world.id.accentColor)
                            Text(record.bestScore > 0 ? "\(record.bestScore.formatted()) pts" : "No record yet")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.68))
                        }
                    } else {
                        Image(systemName: "lock.fill").foregroundStyle(GoalRushTheme.gold)
                    }
                }
                .padding(15)
            }
        }
        .frame(height: 136)
        .clipShape(.rect(cornerRadius: 21))
        .overlay {
            RoundedRectangle(cornerRadius: 21)
                .stroke(selected ? world.id.accentColor : .white.opacity(0.14), lineWidth: selected ? 3 : 1)
        }
        .saturation(unlocked ? 1 : 0.10)
        .opacity(unlocked ? 1 : 0.58)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(world.name), \(unlocked ? "unlocked" : "locked"), best wave \(record.bestWave), best score \(record.bestScore)")
    }
}

private struct EndlessWorldButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .brightness(configuration.isPressed ? 0.06 : 0)
            .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: configuration.isPressed)
    }
}
