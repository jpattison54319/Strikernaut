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
        case .lunarCycle:
            .init(
                subject: .concept(concept),
                title: "Orbital Debris",
                detail: "Moon debris periodically marks a dangerous lane. Move clear before it strikes.",
                systemImage: "moon.stars.fill"
            )
        case .marsArena:
            .init(
                subject: .concept(concept),
                title: "Volatile Cores",
                detail: "Armed cores appear as enemies fall. Shoot each core before it detonates against you.",
                systemImage: "flame.fill"
            )
        case .windShear:
            .init(
                subject: .concept(concept),
                title: "Wind Shear",
                detail: "Wind ribbons show the gust. Steer against it before the charged rail catches you.",
                systemImage: "wind"
            )
        case .ringSweep:
            .init(
                subject: .concept(concept),
                title: "Ring Sweep",
                detail: "The bright opening is safe. Move and shoot through it before the ring crosses.",
                systemImage: "circle.hexagongrid.circle.fill"
            )
        case .cryoDrift:
            .init(
                subject: .concept(concept),
                title: "Cryo Drift",
                detail: "Frost preserves your momentum. Brake early and stay off the frozen rails.",
                systemImage: "snowflake"
            )
        case .pressureTide:
            .init(
                subject: .concept(concept),
                title: "Pressure Tide",
                detail: "Follow the clear channel while the pressure walls close from both sides.",
                systemImage: "water.waves"
            )
        }
    }

    static func discovery(for enemy: EnemyKind) -> CampaignDiscovery {
        let presentation: (title: String, detail: String) = switch enemy {
        case .coneRunner: ("Scout Runner", "Fast and fragile. Stop it before it reaches your line.")
        case .dummyDefender: ("Blocker Defender", "Armored and slower. It takes several clean hits.")
        case .tackleBot: ("Tackle Bot", "Fast and erratic. It cuts sideways between lanes.")
        case .keeperDrone: ("Aegis Keeper", "Slow and heavily armored. Focus your kicks.")
        case .ballLauncher: ("Ball Launcher", "Fires back from range. Move when a red ball appears.")
        case .titanKeeper: ("Titan Keeper", "Earth’s boss. It fires, changes phases, and calls reinforcements.")
        case .regolithRunner: ("Regolith Runner", "A quick lunar scout built for low-gravity lanes.")
        case .lunarHopper: ("Lunar Hopper", "Bounds sideways through crowded lunar lanes.")
        case .orbitDrone: ("Orbit Drone", "A heavily armored defender that floats between lanes.")
        case .eclipseKeeper: ("Eclipse Keeper", "A shadow-armored blocker that demands focused fire.")
        case .gravityStriker: ("Gravity Striker", "Fires from range while orbital debris pressures your lane.")
        case .lunarWarden: ("Lunar Warden", "The Moon’s boss. It commands eclipse phases and lunar reinforcements.")
        case .dustSprite: ("Dust Sprite", "Mars’s quickest grunt. Fragile, but dangerous in groups.")
        case .roverRaider: ("Rover Raider", "A durable alien that absorbs several hits.")
        case .craterCrawler: ("Crater Crawler", "Fast and unpredictable. It sweeps across lanes.")
        case .saucerKeeper: ("Saucer Keeper", "Mars’s slow, heavily armored defender.")
        case .plasmaStriker: ("Plasma Striker", "Fires plasma from range. Keep changing lanes.")
        case .marsColossus: ("Mars Colossus", "Mars’s boss. It fires, shifts phases, and summons reinforcements.")
        case .cloudRunner: ("Cloud Runner", "A fast Jupiter scout that rides the storm lanes.")
        case .pressureBrute: ("Pressure Brute", "Dense cloud armor absorbs repeated hits.")
        case .vortexSkimmer: ("Vortex Skimmer", "Spirals laterally while the wind changes.")
        case .stormKeeper: ("Storm Keeper", "A heavily armored guardian of the citadel.")
        case .boltStriker: ("Bolt Striker", "Fires through the gale from long range.")
        case .tempestRegent: ("Tempest Regent", "Jupiter’s boss. It commands wind rails and lightning.")
        case .ringRunner: ("Ring Runner", "A quick scout that threads Saturn’s apertures.")
        case .iceMason: ("Ice Mason", "A durable defender built from compressed ring ice.")
        case .shepherdDrone: ("Shepherd Drone", "Circles between lanes under orbital control.")
        case .haloKeeper: ("Halo Keeper", "A heavy guardian protected by ring armor.")
        case .shardStriker: ("Shard Striker", "Fires sharp orbital volleys from range.")
        case .crownSovereign: ("Crown Sovereign", "Saturn’s boss. It closes the arena with authored ring patterns.")
        case .frostSprinter: ("Frost Sprinter", "A fast scout that exploits the tilted ice.")
        case .tiltBrute: ("Tilt Brute", "A durable polar defender that holds its line.")
        case .auroraDrifter: ("Aurora Drifter", "Slides unpredictably across the frozen lanes.")
        case .polarKeeper: ("Polar Keeper", "A heavily armored magnetic guardian.")
        case .magnetStriker: ("Magnet Striker", "Fires charged shots through the polar field.")
        case .axisPrime: ("Axis Prime", "Uranus’s boss. It controls drift and mirrored polar fire.")
        case .mistRunner: ("Mist Runner", "A fast Neptune scout hidden by the storm spray.")
        case .currentBrute: ("Current Brute", "A durable defender that presses through the tide.")
        case .squallRay: ("Squall Ray", "Sweeps laterally on the dark current.")
        case .tridentKeeper: ("Trident Keeper", "A heavily armored guardian of the deep.")
        case .pressureStriker: ("Pressure Striker", "Fires compressed storm shots from range.")
        case .abyssalMonarch: ("Abyssal Monarch", "Neptune’s boss. It compresses the field and commands the deep.")
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
        case .roverBattery: ("Rover Battery", "Break it for 18 Training Tokens.")
        case .satelliteRelay: ("Satellite Relay", "A tough lunar obstacle worth 8 Training Tokens.")
        case .regolithBarricade: ("Regolith Barricade", "A low-gravity lane obstacle worth 8 Training Tokens.")
        case .gravityCell: ("Gravity Cell", "Break it to restore up to 24 stamina.")
        case .lunarVault: ("Lunar Vault", "Very durable. Break it for 35 Training Tokens.")
        case .oxygenPod: ("Oxygen Pod", "Break it to restore up to 24 stamina.")
        case .meteorCrate: ("Meteor Crate", "Break it for 18 Training Tokens.")
        case .holoGate: ("Holo Gate", "A tough obstacle worth 8 Training Tokens.")
        case .crystalBarricade: ("Crystal Barricade", "A lane obstacle worth 8 Training Tokens.")
        case .artifactVault: ("Artifact Vault", "Very durable. Break it for 35 Training Tokens.")
        case .pressureCell: ("Pressure Cell", "Break it for 18 Training Tokens.")
        case .cloudCondenser: ("Cloud Condenser", "Break it to restore up to 24 stamina.")
        case .windGate: ("Wind Gate", "A Jupiter lane obstacle worth 8 Training Tokens.")
        case .lightningMast: ("Lightning Mast", "A tough storm obstacle worth 8 Training Tokens.")
        case .stormVault: ("Storm Vault", "Very durable. Break it for 35 Training Tokens.")
        case .ringShardCrate: ("Ring Shard Crate", "Break it for 18 Training Tokens.")
        case .thermalPod: ("Thermal Pod", "Break it to restore up to 24 stamina.")
        case .shepherdBeacon: ("Shepherd Beacon", "A tough orbital obstacle worth 8 Training Tokens.")
        case .iceBarricade: ("Ice Barricade", "A Saturn lane obstacle worth 8 Training Tokens.")
        case .crownVault: ("Crown Vault", "Very durable. Break it for 35 Training Tokens.")
        case .magneticCoil: ("Magnetic Coil", "Break it for 18 Training Tokens.")
        case .cryoCanister: ("Cryo Canister", "Break it to restore up to 24 stamina.")
        case .auroraRelay: ("Aurora Relay", "A tough polar obstacle worth 8 Training Tokens.")
        case .frostBarricade: ("Frost Barricade", "A Uranus lane obstacle worth 8 Training Tokens.")
        case .polarVault: ("Polar Vault", "Very durable. Break it for 35 Training Tokens.")
        case .stormBattery: ("Storm Battery", "Break it for 18 Training Tokens.")
        case .oxygenBell: ("Oxygen Bell", "Break it to restore up to 24 stamina.")
        case .currentGate: ("Current Gate", "A tough deep-sea obstacle worth 8 Training Tokens.")
        case .coralBarricade: ("Coral Barricade", "A Neptune lane obstacle worth 8 Training Tokens.")
        case .trenchVault: ("Trench Vault", "Very durable. Break it for 35 Training Tokens.")
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
