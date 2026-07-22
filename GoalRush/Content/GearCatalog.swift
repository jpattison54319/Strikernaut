import Foundation

enum GearCatalog {
    static let all: [GearDefinition] = [
        .init(id: .earthVisor, slot: .head, world: .earth, name: "Striker Visor", shortName: "Visor", effect: "+2% critical-hit chance", modifiers: .init(criticalChanceBonus: 0.02)),
        .init(id: .earthJersey, slot: .torso, world: .earth, name: "Captain Jersey", shortName: "Jersey", effect: "+10 maximum stamina", modifiers: .init(staminaBonus: 10)),
        .init(id: .earthGloves, slot: .hands, world: .earth, name: "Flight Gloves", shortName: "Gloves", effect: "+8% ball flight speed", modifiers: .init(ballSpeedMultiplier: 1.08)),
        .init(id: .earthGuards, slot: .legs, world: .earth, name: "Sprint Guards", shortName: "Guards", effect: "+8% lateral response", modifiers: .init(movementMultiplier: 1.08)),
        .init(id: .earthCleats, slot: .feet, world: .earth, name: "Tempo Cleats", shortName: "Cleats", effect: "6% shorter kick interval", modifiers: .init(kickCooldownMultiplier: 0.94)),
        .init(id: .marsLens, slot: .head, world: .mars, name: "Orbital Lens", shortName: "Lens", effect: "Balls curve toward nearby targets", modifiers: .init(homingStrength: 0.18)),
        .init(id: .marsCore, slot: .torso, world: .mars, name: "Red Planet Core", shortName: "Core", effect: "+15% ball damage", modifiers: .init(damageMultiplier: 1.15)),
        .init(id: .marsGauntlets, slot: .hands, world: .mars, name: "Plasma Gauntlets", shortName: "Gauntlets", effect: "+5% critical-hit chance", modifiers: .init(criticalChanceBonus: 0.05)),
        .init(id: .marsGuards, slot: .legs, world: .mars, name: "Gravity Guards", shortName: "Gravity", effect: "+12% lateral response", modifiers: .init(movementMultiplier: 1.12)),
        .init(id: .marsBoots, slot: .feet, world: .mars, name: "Comet Boots", shortName: "Boots", effect: "8% shorter kick interval", modifiers: .init(kickCooldownMultiplier: 0.92))
    ]

    static func item(_ id: GearID) -> GearDefinition {
        all.first(where: { $0.id == id }) ?? all[0]
    }

    static func items(for world: WorldID) -> [GearDefinition] {
        all.filter { $0.world == world }
    }

    static func items(for slot: GearSlot, unlocked: Set<GearID>) -> [GearDefinition] {
        all.filter { $0.slot == slot && unlocked.contains($0.id) }
    }

    static func modifiers(for loadout: GearLoadout) -> GearModifiers {
        var result = GearModifiers()
        for id in loadout.equipped.values {
            result.combine(item(id).modifiers)
        }
        if loadout.wearsCompleteSet(for: .earth) {
            result.startingShields += 1
        }
        if loadout.wearsCompleteSet(for: .mars) {
            result.extraPierce += 1
        }
        return result
    }

    static func setName(for world: WorldID) -> String {
        switch world {
        case .earth: "Earth Vanguard"
        case .mars: "Mars Pioneer"
        }
    }

    static func setBonus(for world: WorldID) -> String {
        switch world {
        case .earth: "Full set: start every run with one shield block."
        case .mars: "Full set: every ball pierces one additional target."
        }
    }
}
