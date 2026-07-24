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
    var endlessRecords: [WorldID: EndlessRecord]
    var lifetimeStats: LifetimeStats
    var dailyReward: DailyRewardState
    var missions: [MissionState]
    var missionsDay: String
    var unlockedAchievements: Set<AchievementID>
    var hasSeenOnboarding: Bool
    var unlockedCharacters: Set<CharacterID>
    var selectedCharacter: CharacterID

    static let newPlayer = PlayerProgress(
        schemaVersion: 4,
        trainingTokens: 0,
        highestUnlockedLevel: 1,
        upgradeRanks: [:],
        levelRecords: [:],
        hasMovedInTutorial: false,
        endlessRecords: [:],
        lifetimeStats: LifetimeStats(),
        dailyReward: DailyRewardState(),
        missions: [],
        missionsDay: "",
        unlockedAchievements: [],
        hasSeenOnboarding: false,
        unlockedCharacters: [.ace],
        selectedCharacter: .ace
    )

    func rank(for track: UpgradeTrack) -> Int { upgradeRanks[track, default: 0] }
    mutating func setRank(_ rank: Int, for track: UpgradeTrack) { upgradeRanks[track] = rank }
    func endlessRecord(for world: WorldID) -> EndlessRecord { endlessRecords[world, default: .empty] }
    mutating func reconcileUnlockedContent() {
        schemaVersion = 4
        highestUnlockedLevel = min(GameContent.levels.count, max(1, highestUnlockedLevel))
        for world in GameContent.worlds where levelRecords[world.finalLevel]?.completed == true {
            highestUnlockedLevel = min(
                GameContent.levels.count,
                max(highestUnlockedLevel, world.finalLevel + 1)
            )
        }
        unlockedCharacters.formUnion(CharacterCatalog.unlockedCharacters(for: self))
        unlockedCharacters.insert(.ace)
        if !unlockedCharacters.contains(selectedCharacter) {
            selectedCharacter = .ace
        }
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case trainingTokens
        case highestUnlockedLevel
        case upgradeRanks
        case levelRecords
        case hasMovedInTutorial
        case endlessRecords
        case lifetimeStats
        case dailyReward
        case missions
        case missionsDay
        case unlockedAchievements
        case hasSeenOnboarding
        case unlockedCharacters
        case selectedCharacter
    }

    init(
        schemaVersion: Int,
        trainingTokens: Int,
        highestUnlockedLevel: Int,
        upgradeRanks: [UpgradeTrack: Int],
        levelRecords: [Int: LevelRecord],
        hasMovedInTutorial: Bool,
        endlessRecords: [WorldID: EndlessRecord],
        lifetimeStats: LifetimeStats = LifetimeStats(),
        dailyReward: DailyRewardState = DailyRewardState(),
        missions: [MissionState] = [],
        missionsDay: String = "",
        unlockedAchievements: Set<AchievementID> = [],
        hasSeenOnboarding: Bool = false,
        unlockedCharacters: Set<CharacterID> = [.ace],
        selectedCharacter: CharacterID = .ace
    ) {
        self.schemaVersion = schemaVersion
        self.trainingTokens = trainingTokens
        self.highestUnlockedLevel = highestUnlockedLevel
        self.upgradeRanks = upgradeRanks
        self.levelRecords = levelRecords
        self.hasMovedInTutorial = hasMovedInTutorial
        self.endlessRecords = endlessRecords
        self.lifetimeStats = lifetimeStats
        self.dailyReward = dailyReward
        self.missions = missions
        self.missionsDay = missionsDay
        self.unlockedAchievements = unlockedAchievements
        self.hasSeenOnboarding = hasSeenOnboarding
        self.unlockedCharacters = unlockedCharacters
        self.selectedCharacter = selectedCharacter
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Preserve the stored version (floor at 2, matching the v1→v2 migration);
        // reconcileUnlockedContent() bumps older saves to the current schema.
        schemaVersion = max(2, try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 2)
        trainingTokens = try container.decodeIfPresent(Int.self, forKey: .trainingTokens) ?? 0
        highestUnlockedLevel = try container.decodeIfPresent(Int.self, forKey: .highestUnlockedLevel) ?? 1
        upgradeRanks = container.decodeEnumKeyedMap(forKey: .upgradeRanks)
        levelRecords = try container.decodeIfPresent([Int: LevelRecord].self, forKey: .levelRecords) ?? [:]
        hasMovedInTutorial = try container.decodeIfPresent(Bool.self, forKey: .hasMovedInTutorial) ?? false
        endlessRecords = container.decodeEnumKeyedMap(forKey: .endlessRecords)
        lifetimeStats = try container.decodeIfPresent(LifetimeStats.self, forKey: .lifetimeStats) ?? LifetimeStats()
        dailyReward = try container.decodeIfPresent(DailyRewardState.self, forKey: .dailyReward) ?? DailyRewardState()
        missions = try container.decodeIfPresent([MissionState].self, forKey: .missions) ?? []
        missionsDay = try container.decodeIfPresent(String.self, forKey: .missionsDay) ?? ""
        unlockedAchievements = try container.decodeIfPresent(Set<AchievementID>.self, forKey: .unlockedAchievements) ?? []
        hasSeenOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasSeenOnboarding) ?? false
        unlockedCharacters = try container.decodeIfPresent(Set<CharacterID>.self, forKey: .unlockedCharacters) ?? [.ace]
        selectedCharacter = try container.decodeIfPresent(CharacterID.self, forKey: .selectedCharacter) ?? .ace
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(4, forKey: .schemaVersion)
        try container.encode(trainingTokens, forKey: .trainingTokens)
        try container.encode(highestUnlockedLevel, forKey: .highestUnlockedLevel)
        try container.encode(upgradeRanks, forKey: .upgradeRanks)
        try container.encode(levelRecords, forKey: .levelRecords)
        try container.encode(hasMovedInTutorial, forKey: .hasMovedInTutorial)
        try container.encode(endlessRecords, forKey: .endlessRecords)
        try container.encode(lifetimeStats, forKey: .lifetimeStats)
        try container.encode(dailyReward, forKey: .dailyReward)
        try container.encode(missions, forKey: .missions)
        try container.encode(missionsDay, forKey: .missionsDay)
        try container.encode(unlockedAchievements, forKey: .unlockedAchievements)
        try container.encode(hasSeenOnboarding, forKey: .hasSeenOnboarding)
        try container.encode(unlockedCharacters, forKey: .unlockedCharacters)
        try container.encode(selectedCharacter, forKey: .selectedCharacter)
    }
}

private extension KeyedDecodingContainer {
    /// Dictionaries keyed by String-raw enums encode as arrays under Codable, but
    /// v2 saves stored them as JSON objects keyed by the raw value. Accept both.
    func decodeEnumKeyedMap<Key, Value>(forKey key: K) -> [Key: Value]
        where Key: RawRepresentable & Decodable, Key.RawValue == String, Value: Decodable {
        if let object = try? decode([String: Value].self, forKey: key) {
            return object.reduce(into: [:]) { result, pair in
                if let typedKey = Key(rawValue: pair.key) { result[typedKey] = pair.value }
            }
        }
        return (try? decode([Key: Value].self, forKey: key)) ?? [:]
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
