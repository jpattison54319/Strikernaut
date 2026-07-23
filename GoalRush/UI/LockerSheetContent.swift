import SwiftUI

struct LockerItemDetailsSheet: View {
    @Environment(GameStore.self) private var store
    let selectedSlot: GearSlot

    var body: some View {
        GameSheetScaffold(title: "Item Details", subtitle: selectedSlot.title) {
            HStack(alignment: .top, spacing: GoalRushTheme.Metrics.standardSpacing) {
                Image(systemName: selectedSlot.icon)
                    .font(.title2)
                    .foregroundStyle(item?.world.accentColor ?? .white.opacity(0.58))
                    .frame(width: 48, height: 48)
                    .background((item?.world.accentColor ?? .white).opacity(0.12), in: .rect(cornerRadius: 14))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.compactSpacing) {
                    Text(item?.name ?? "No \(selectedSlot.title) Gear")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)
                    Text(item?.effect ?? emptySlotMessage)
                        .font(.headline)
                        .foregroundStyle(item == nil ? .white.opacity(0.68) : GoalRushTheme.positive)
                        .fixedSize(horizontal: false, vertical: true)

                    if let item {
                        Label("\(GameContent.world(item.world).name) • Permanent", systemImage: "checkmark.shield.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(item.world.accentColor)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(GoalRushTheme.Metrics.standardSpacing)
            .gameSurface(.panel)
            .accessibilityElement(children: .combine)
        }
    }

    private var item: GearDefinition? {
        store.progress.equippedGear[selectedSlot].map(GearCatalog.item)
    }

    private var emptySlotMessage: String {
        if GearCatalog.items(for: selectedSlot, unlocked: store.progress.unlockedGear).isEmpty {
            return "Clear worlds to earn gear."
        }
        return "No gear equipped. Use the Locker arrows to equip an earned item."
    }
}

struct LockerSetProgressSheet: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        GameSheetScaffold(title: "Set Progress", subtitle: "Earn and equip complete world sets.") {
            VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                ForEach(GameContent.worlds) { world in
                    let earned = world.gearRewards.filter { store.progress.unlockedGear.contains($0) }.count
                    let equipped = world.gearRewards.filter { store.progress.equippedGear.values.contains($0) }.count

                    VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.compactSpacing) {
                        Label(world.gearSetName, systemImage: world.id.icon)
                            .font(.headline.bold())
                            .foregroundStyle(world.id.accentColor)
                        Text(GearCatalog.setBonus(for: world.id))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(earned == 5 ? "Set earned" : "\(earned) / 5 earned • clear \(world.name)")
                            .font(.caption.bold())
                            .foregroundStyle(earned == 5 ? world.id.accentColor : GoalRushTheme.gold)
                        Text("\(equipped) / 5 equipped")
                            .font(.caption.bold())
                            .foregroundStyle(equipped == 5 ? GoalRushTheme.positive : .white.opacity(0.62))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(GoalRushTheme.Metrics.standardSpacing)
                    .gameSurface(.panel)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

struct GearInfoSheet: View {
    var body: some View {
        GameSheetScaffold(title: "About Gear", subtitle: "Gear rewards stay with your player.") {
            VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
                Label("Clear worlds to earn gear", systemImage: "flag.checkered")
                Label("Item effects apply in every mode", systemImage: "checkmark.shield.fill")
                Label("Equip all 5 pieces for a set bonus", systemImage: "sparkles")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding(GoalRushTheme.Metrics.standardSpacing)
            .gameSurface(.panel)
        }
    }
}
