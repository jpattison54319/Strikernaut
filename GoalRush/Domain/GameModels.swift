import Foundation

enum EnemyKind: String, Codable, CaseIterable, Sendable {
    case coneRunner
    case dummyDefender
    case tackleBot
    case keeperDrone
    case ballLauncher
    case titanKeeper
    case dustSprite
    case roverRaider
    case craterCrawler
    case saucerKeeper
    case plasmaStriker
    case marsColossus
}

enum FieldObjectKind: String, Codable, CaseIterable, Sendable {
    case ballCart
    case waterCooler
    case tacticsBoard
    case coneBarricade
    case equipmentTrunk
    case oxygenPod
    case meteorCrate
    case holoGate
    case crystalBarricade
    case artifactVault
}

enum AbilityKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case powerDrive
    case quickRelease
    case throughBall
    case curler
    case oneTwo
    case cleanSheet
    case secondWind
    case gravityBoots
    case meteorStrike
    case goldenGoal

    var id: String { rawValue }
}

enum UpgradeTrack: String, Codable, CaseIterable, Identifiable, Sendable {
    case conditioning
    case footwork
    case tempo
    case impact
    case flight
    case spin

    var id: String { rawValue }
    var category: UpgradeCategory {
        switch self {
        case .conditioning, .footwork, .tempo: .player
        case .impact, .flight, .spin: .ball
        }
    }
}

enum UpgradeCategory: String, CaseIterable, Identifiable, Sendable {
    case player = "Player"
    case ball = "Ball"
    var id: String { rawValue }
}

struct LevelRecord: Codable, Equatable, Sendable {
    var completed: Bool
    var bestTokens: Int
    var bestStamina: Double
    static let empty = LevelRecord(completed: false, bestTokens: 0, bestStamina: 0)
}

struct PlayerProgress: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var trainingTokens: Int
    var highestUnlockedLevel: Int
    var upgradeRanks: [UpgradeTrack: Int]
    var levelRecords: [Int: LevelRecord]
    var hasMovedInTutorial: Bool
    var unlockedGear: Set<GearID>
    var equippedGear: [GearSlot: GearID]
    var endlessRecords: [WorldID: EndlessRecord]

    static let newPlayer = PlayerProgress(
        schemaVersion: 2,
        trainingTokens: 0,
        highestUnlockedLevel: 1,
        upgradeRanks: [:],
        levelRecords: [:],
        hasMovedInTutorial: false,
        unlockedGear: [],
        equippedGear: [:],
        endlessRecords: [:]
    )

    func rank(for track: UpgradeTrack) -> Int { upgradeRanks[track, default: 0] }
    mutating func setRank(_ rank: Int, for track: UpgradeTrack) { upgradeRanks[track] = rank }
    func endlessRecord(for world: WorldID) -> EndlessRecord { endlessRecords[world, default: .empty] }
    var loadout: GearLoadout { GearLoadout(equipped: equippedGear) }

    mutating func reconcileUnlockedContent() {
        schemaVersion = 2
        highestUnlockedLevel = min(GameContent.levels.count, max(1, highestUnlockedLevel))
        for world in GameContent.worlds where levelRecords[world.finalLevel]?.completed == true {
            unlockedGear.formUnion(world.gearRewards)
            highestUnlockedLevel = min(
                GameContent.levels.count,
                max(highestUnlockedLevel, world.finalLevel + 1)
            )
        }
        equippedGear = equippedGear.filter { slot, id in
            unlockedGear.contains(id) && GearCatalog.item(id).slot == slot
        }
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case trainingTokens
        case highestUnlockedLevel
        case upgradeRanks
        case levelRecords
        case hasMovedInTutorial
        case unlockedGear
        case equippedGear
        case endlessRecords
    }

    init(
        schemaVersion: Int,
        trainingTokens: Int,
        highestUnlockedLevel: Int,
        upgradeRanks: [UpgradeTrack: Int],
        levelRecords: [Int: LevelRecord],
        hasMovedInTutorial: Bool,
        unlockedGear: Set<GearID>,
        equippedGear: [GearSlot: GearID],
        endlessRecords: [WorldID: EndlessRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.trainingTokens = trainingTokens
        self.highestUnlockedLevel = highestUnlockedLevel
        self.upgradeRanks = upgradeRanks
        self.levelRecords = levelRecords
        self.hasMovedInTutorial = hasMovedInTutorial
        self.unlockedGear = unlockedGear
        self.equippedGear = equippedGear
        self.endlessRecords = endlessRecords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = 2
        trainingTokens = try container.decodeIfPresent(Int.self, forKey: .trainingTokens) ?? 0
        highestUnlockedLevel = try container.decodeIfPresent(Int.self, forKey: .highestUnlockedLevel) ?? 1
        upgradeRanks = try container.decodeIfPresent([UpgradeTrack: Int].self, forKey: .upgradeRanks) ?? [:]
        levelRecords = try container.decodeIfPresent([Int: LevelRecord].self, forKey: .levelRecords) ?? [:]
        hasMovedInTutorial = try container.decodeIfPresent(Bool.self, forKey: .hasMovedInTutorial) ?? false
        unlockedGear = try container.decodeIfPresent(Set<GearID>.self, forKey: .unlockedGear) ?? []
        let decodedGear = try container.decodeIfPresent([GearSlot: GearID].self, forKey: .equippedGear) ?? [:]
        equippedGear = [:]
        for (slot, id) in decodedGear where unlockedGear.contains(id) && GearCatalog.item(id).slot == slot {
            equippedGear[slot] = id
        }
        endlessRecords = try container.decodeIfPresent([WorldID: EndlessRecord].self, forKey: .endlessRecords) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(2, forKey: .schemaVersion)
        try container.encode(trainingTokens, forKey: .trainingTokens)
        try container.encode(highestUnlockedLevel, forKey: .highestUnlockedLevel)
        try container.encode(upgradeRanks, forKey: .upgradeRanks)
        try container.encode(levelRecords, forKey: .levelRecords)
        try container.encode(hasMovedInTutorial, forKey: .hasMovedInTutorial)
        try container.encode(unlockedGear, forKey: .unlockedGear)
        try container.encode(equippedGear, forKey: .equippedGear)
        try container.encode(endlessRecords, forKey: .endlessRecords)
    }
}

struct GameSettings: Codable, Equatable, Sendable {
    var musicEnabled = true
    var soundEnabled = true
    var hapticsEnabled = true
    var reducedFlashes = false
    var assistMode = false

    private static let key = "goal-rush-settings-v1"

    static func load(defaults: UserDefaults = .standard) -> GameSettings {
        guard let data = defaults.data(forKey: key), let value = try? JSONDecoder().decode(GameSettings.self, from: data) else {
            return GameSettings()
        }
        return value
    }

    func save(defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }
}
