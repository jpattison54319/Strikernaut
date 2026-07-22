import Foundation

enum CampaignBriefingCatalog {
    static func discoveries(for level: LevelDefinition) -> [CampaignDiscovery] {
        let earlierLevels = GameContent.levels.filter { $0.number < level.number }
        let seenConcepts = Set(earlierLevels.flatMap(\.concepts).map(\.rawValue))
        let seenEnemies = Set(earlierLevels.flatMap(enemies(in:)).map(\.rawValue))
        let seenObjects = Set(earlierLevels.flatMap(\.objects).map(\.rawValue))

        let concepts = unique(level.concepts)
            .filter { !seenConcepts.contains($0.rawValue) }
            .map(discovery(for:))
        let enemies = unique(enemies(in: level))
            .filter { !seenEnemies.contains($0.rawValue) }
            .map(discovery(for:))
        let objects = unique(level.objects)
            .filter { !seenObjects.contains($0.rawValue) }
            .map(discovery(for:))

        return concepts + enemies + objects
    }

    static func discovery(for concept: CampaignConcept) -> CampaignDiscovery {
        switch concept {
        case .automaticKicks:
            .init(
                subject: .concept(concept),
                title: "Auto Kick",
                detail: "Kicks are automatic. Drag anywhere to change lanes.",
                systemImage: "hand.draw.fill"
            )
        case .marsArena:
            .init(
                subject: .concept(concept),
                title: "Mars Arena",
                detail: "Alien enemies and Martian field objects await.",
                systemImage: "circle.grid.cross.fill"
            )
        }
    }

    static func discovery(for enemy: EnemyKind) -> CampaignDiscovery {
        let presentation: (title: String, detail: String) = switch enemy {
        case .coneRunner: ("Cone Runner", "Fast and fragile. Stop it before it reaches your line.")
        case .dummyDefender: ("Dummy Defender", "Armored and slower. It takes several clean hits.")
        case .tackleBot: ("Tackle Bot", "Fast and erratic. It cuts sideways between lanes.")
        case .keeperDrone: ("Keeper Drone", "Slow and heavily armored. Focus your kicks.")
        case .ballLauncher: ("Ball Launcher", "Fires back from range. Move when a red ball appears.")
        case .titanKeeper: ("Titan Keeper", "Earth’s boss. It fires, changes phases, and calls reinforcements.")
        case .dustSprite: ("Dust Sprite", "Mars’s quickest grunt. Fragile, but dangerous in groups.")
        case .roverRaider: ("Rover Raider", "A durable alien that absorbs several hits.")
        case .craterCrawler: ("Crater Crawler", "Fast and unpredictable. It sweeps across lanes.")
        case .saucerKeeper: ("Saucer Keeper", "Mars’s slow, heavily armored defender.")
        case .plasmaStriker: ("Plasma Striker", "Fires plasma from range. Keep changing lanes.")
        case .marsColossus: ("Mars Colossus", "Mars’s boss. It fires, shifts phases, and summons reinforcements.")
        }
        return .init(subject: .enemy(enemy), title: presentation.title, detail: presentation.detail, systemImage: "scope")
    }

    static func discovery(for object: FieldObjectKind) -> CampaignDiscovery {
        let presentation: (title: String, detail: String) = switch object {
        case .ballCart: ("Ball Cart", "Break it for 18 Training Tokens.")
        case .waterCooler: ("Water Cooler", "Break it to restore up to 24 stamina.")
        case .tacticsBoard: ("Tactics Board", "A tough obstacle worth 8 Training Tokens.")
        case .coneBarricade: ("Cone Barricade", "A lane obstacle worth 8 Training Tokens.")
        case .equipmentTrunk: ("Equipment Trunk", "Very durable. Break it for 35 Training Tokens.")
        case .oxygenPod: ("Oxygen Pod", "Break it to restore up to 24 stamina.")
        case .meteorCrate: ("Meteor Crate", "Break it for 18 Training Tokens.")
        case .holoGate: ("Holo Gate", "A tough obstacle worth 8 Training Tokens.")
        case .crystalBarricade: ("Crystal Barricade", "A lane obstacle worth 8 Training Tokens.")
        case .artifactVault: ("Artifact Vault", "Very durable. Break it for 35 Training Tokens.")
        }
        return .init(subject: .fieldObject(object), title: presentation.title, detail: presentation.detail, systemImage: "shippingbox.fill")
    }

    private static func unique<T: RawRepresentable>(_ values: [T]) -> [T] where T.RawValue == String {
        var seen: Set<String> = []
        return values.filter { seen.insert($0.rawValue).inserted }
    }

    private static func enemies(in level: LevelDefinition) -> [EnemyKind] {
        guard level.hasBoss else { return level.enemies }
        return level.enemies + [GameContent.world(level.world).boss]
    }
}
