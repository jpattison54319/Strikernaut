import SpriteKit
import SwiftUI

struct GearView: View {
    @Environment(GameStore.self) private var store
    @State private var selectedSlot: GearSlot = .torso
    @State private var showingInfo = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    lockerStage
                    selectedGearCard
                    setProgress
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .background(GoalRushTheme.navy.ignoresSafeArea())
            .navigationTitle("Locker")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Home", systemImage: "chevron.left") { store.route = .home }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("About gear", systemImage: "info.circle") {
                        showingInfo = true
                    }
                    .labelStyle(.iconOnly)
                    HStack(spacing: 5) {
                        Image(systemName: "tshirt.fill")
                        Text("\(store.progress.equippedGear.count)/5").monospacedDigit()
                    }
                        .font(.subheadline.bold())
                        .foregroundStyle(GoalRushTheme.cyan)
                        .accessibilityLabel("\(store.progress.equippedGear.count) of 5 gear slots equipped")
                }
            }
            .sheet(isPresented: $showingInfo) {
                GearInfoView()
                    .presentationDetents([.medium])
            }
            .sensoryFeedback(trigger: store.progress.equippedGear) { _, _ in
                store.settings.hapticsEnabled ? .selection : nil
            }
        }
    }

    private var lockerStage: some View {
        GeometryReader { geometry in
            ZStack {
                Image("LockerRoom")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .accessibilityHidden(true)
                LinearGradient(colors: [.black.opacity(0.08), .clear, .black.opacity(0.34)], startPoint: .top, endPoint: .bottom)
                LockerAvatarView(loadout: store.progress.loadout)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                ForEach(Array(GearSlot.allCases.enumerated()), id: \.element) { index, slot in
                    GearCycleRow(
                        slot: slot,
                        canCycle: !GearCatalog.items(for: slot, unlocked: store.progress.unlockedGear).isEmpty,
                        selected: selectedSlot == slot,
                        previous: { cycle(slot, direction: -1) },
                        next: { cycle(slot, direction: 1) }
                    )
                    .position(x: geometry.size.width / 2, y: [128, 220, 286, 346, 400][index])
                }

            }
            .clipShape(.rect(cornerRadius: 26))
            .overlay { RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.18)) }
            .shadow(color: .black.opacity(0.30), radius: 18, y: 9)
        }
        .frame(height: 454)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Character gear preview")
    }

    private var selectedGearCard: some View {
        let equippedID = store.progress.equippedGear[selectedSlot]
        let item = equippedID.map(GearCatalog.item)
        return GameCard {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: selectedSlot.icon)
                    .font(.title2)
                    .foregroundStyle(item?.world.accentColor ?? .secondary)
                    .frame(width: 48, height: 48)
                    .background((item?.world.accentColor ?? .white).opacity(0.11), in: .rect(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 5) {
                    Text(selectedSlot.title.uppercased())
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Text(item?.name ?? "No \(selectedSlot.title) Gear")
                        .font(.headline)
                    Text(item?.effect ?? emptySlotMessage)
                        .font(.subheadline)
                        .foregroundStyle(item == nil ? .secondary : GoalRushTheme.positive)
                        .fixedSize(horizontal: false, vertical: true)
                    if let item {
                        Label("\(GameContent.world(item.world).name) • Permanent", systemImage: "checkmark.shield.fill")
                            .font(.caption.bold())
                            .foregroundStyle(item.world.accentColor)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var setProgress: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SET BONUSES")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            ForEach(GameContent.worlds) { world in
                let earned = world.gearRewards.filter { store.progress.unlockedGear.contains($0) }.count
                let equipped = world.gearRewards.filter { store.progress.equippedGear.values.contains($0) }.count
                HStack(spacing: 12) {
                    Image(systemName: world.id.icon)
                        .font(.title3)
                        .foregroundStyle(world.id.accentColor)
                        .frame(width: 42, height: 42)
                        .background(world.id.accentColor.opacity(0.11), in: .circle)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(world.gearSetName).font(.subheadline.bold())
                            Spacer()
                            Text("\(equipped) / 5 equipped")
                                .font(.caption2.bold())
                                .foregroundStyle(equipped == 5 ? GoalRushTheme.positive : .secondary)
                        }
                        Text(GearCatalog.setBonus(for: world.id))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(earned == 5 ? "Set earned" : "\(earned) / 5 earned • clear \(world.name)")
                            .font(.caption2.bold())
                            .foregroundStyle(earned == 5 ? world.id.accentColor : GoalRushTheme.gold)
                    }
                }
                .padding(13)
                .background(.white.opacity(0.055), in: .rect(cornerRadius: 17))
                .overlay { RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.10)) }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var emptySlotMessage: String {
        if GearCatalog.items(for: selectedSlot, unlocked: store.progress.unlockedGear).isEmpty {
            return "Clear worlds to earn gear."
        }
        return "No gear equipped."
    }

    private func cycle(_ slot: GearSlot, direction: Int) {
        selectedSlot = slot
        store.cycleGear(in: slot, direction: direction)
    }
}

private struct GearInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Label("Clear worlds to earn gear", systemImage: "flag.checkered")
                Label("Item effects apply in every mode", systemImage: "checkmark.shield.fill")
                Label("Equip all 5 pieces for a set bonus", systemImage: "sparkles")
            }
            .navigationTitle("Gear")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct LockerAvatarView: View {
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

private struct GearCycleRow: View {
    let slot: GearSlot
    let canCycle: Bool
    let selected: Bool
    let previous: () -> Void
    let next: () -> Void

    var body: some View {
        HStack {
            Button("Previous \(slot.title) gear", systemImage: "chevron.left", action: previous)
                .labelStyle(.iconOnly)
                .gearArrowStyle(enabled: canCycle, selected: selected)
                .accessibilityIdentifier("gear-\(slot.rawValue)-previous")
            Spacer()
            Button("Next \(slot.title) gear", systemImage: "chevron.right", action: next)
                .labelStyle(.iconOnly)
                .gearArrowStyle(enabled: canCycle, selected: selected)
                .accessibilityIdentifier("gear-\(slot.rawValue)-next")
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .disabled(!canCycle)
    }
}

private extension View {
    func gearArrowStyle(enabled: Bool, selected: Bool) -> some View {
        self
            .font(.headline.bold())
            .foregroundStyle(enabled ? .white : .white.opacity(0.30))
            .frame(width: 44, height: 44)
            .background(.black.opacity(selected ? 0.58 : 0.42), in: .circle)
            .overlay { Circle().stroke(selected ? GoalRushTheme.cyan.opacity(0.72) : .white.opacity(0.15)) }
            .contentShape(.circle)
    }
}
