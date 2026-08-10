import Foundation

enum EnemyKind: String, Codable, CaseIterable, Sendable {
    case coneRunner
    case dummyDefender
    case tackleBot
    case keeperDrone
    case ballLauncher
    case titanKeeper
    case regolithRunner
    case lunarHopper
    case orbitDrone
    case eclipseKeeper
    case gravityStriker
    case lunarWarden
    case dustSprite
    case roverRaider
    case craterCrawler
    case saucerKeeper
    case plasmaStriker
    case marsColossus
    case cloudRunner
    case pressureBrute
    case vortexSkimmer
    case stormKeeper
    case boltStriker
    case tempestRegent
    case ringRunner
    case iceMason
    case shepherdDrone
    case haloKeeper
    case shardStriker
    case crownSovereign
    case frostSprinter
    case tiltBrute
    case auroraDrifter
    case polarKeeper
    case magnetStriker
    case axisPrime
    case mistRunner
    case currentBrute
    case squallRay
    case tridentKeeper
    case pressureStriker
    case abyssalMonarch
}

enum FieldObjectKind: String, Codable, CaseIterable, Sendable {
    case ballCart
    case waterCooler
    case tacticsBoard
    case coneBarricade
    case equipmentTrunk
    case roverBattery
    case satelliteRelay
    case regolithBarricade
    case gravityCell
    case lunarVault
    case oxygenPod
    case meteorCrate
    case holoGate
    case crystalBarricade
    case artifactVault
    case pressureCell
    case cloudCondenser
    case windGate
    case lightningMast
    case stormVault
    case ringShardCrate
    case thermalPod
    case shepherdBeacon
    case iceBarricade
    case crownVault
    case magneticCoil
    case cryoCanister
    case auroraRelay
    case frostBarricade
    case polarVault
    case stormBattery
    case oxygenBell
    case currentGate
    case coralBarricade
    case trenchVault
}

nonisolated enum AbilityKind: String, Codable, CaseIterable, Identifiable, Sendable {
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
    var campaignCycle: Int
    var currentCampaignClears: Set<Int>
    var highestCompletedCampaignCycle: Int
    var upgradeRanks: [UpgradeTrack: Int]
    var upgradePrestiges: [UpgradeTrack: Int]
    var levelRecords: [Int: LevelRecord]
    var hasMovedInTutorial: Bool
    var endlessRecord: EndlessRecord
    var lifetimeStats: LifetimeStats
    var dailyReward: DailyRewardState
    var missions: [MissionState]
    var missionsDay: String
    var unlockedAchievements: Set<AchievementID>
    var hasSeenOnboarding: Bool
    var seenCampaignBriefingLevels: Set<Int>
    var unlockedCharacters: Set<CharacterID>
    var selectedCharacter: CharacterID

    static let newPlayer = PlayerProgress(
        schemaVersion: 12,
        trainingTokens: 0,
        highestUnlockedLevel: 1,
        campaignCycle: 0,
        currentCampaignClears: [],
        highestCompletedCampaignCycle: 0,
        upgradeRanks: [:],
        upgradePrestiges: [:],
        levelRecords: [:],
        hasMovedInTutorial: false,
        endlessRecord: .empty,
        lifetimeStats: LifetimeStats(),
        dailyReward: DailyRewardState(),
        missions: [],
        missionsDay: "",
        unlockedAchievements: [],
        hasSeenOnboarding: false,
        seenCampaignBriefingLevels: [],
        unlockedCharacters: [.ace],
        selectedCharacter: .ace
    )

    func rank(for track: UpgradeTrack) -> Int { upgradeRanks[track, default: 0] }
    mutating func setRank(_ rank: Int, for track: UpgradeTrack) { upgradeRanks[track] = rank }
    func prestigeCount(for track: UpgradeTrack) -> Int { upgradePrestiges[track, default: 0] }
    mutating func setPrestigeCount(_ count: Int, for track: UpgradeTrack) {
        upgradePrestiges[track] = min(max(count, 0), UpgradePrestigeTier.allCases.count)
    }
    mutating func reconcileUnlockedContent() {
        let isMoonCampaignMigration = schemaVersion < 5
        let isBriefingSeenMigration = schemaVersion < 6
        let isUpgradePrestigeMigration = schemaVersion < 7
        let isCampaignCycleMigration = schemaVersion < 12
        campaignCycle = max(0, campaignCycle)
        highestCompletedCampaignCycle = min(
            campaignCycle,
            max(0, highestCompletedCampaignCycle)
        )
        currentCampaignClears = Set(currentCampaignClears.filter {
            GameContent.levels.indices.contains($0 - 1)
        })
        if isCampaignCycleMigration {
            currentCampaignClears.formUnion(
                levelRecords.compactMap {
                    $0.value.completed ? $0.key : nil
                }
            )
        }
        highestUnlockedLevel = min(GameContent.levels.count, max(1, highestUnlockedLevel))
        if let highestClear = currentCampaignClears.max() {
            highestUnlockedLevel = min(
                GameContent.levels.count,
                max(highestUnlockedLevel, highestClear + 1)
            )
        }
        if isMoonCampaignMigration {
            unlockedCharacters = CharacterCatalog.unlockedCharacters(for: self)
        } else {
            unlockedCharacters.formUnion(CharacterCatalog.unlockedCharacters(for: self))
        }
        unlockedCharacters.insert(.ace)
        if !unlockedCharacters.contains(selectedCharacter) {
            selectedCharacter = .ace
        }
        if isBriefingSeenMigration {
            seenCampaignBriefingLevels.formUnion(
                GameContent.levels.compactMap { level in
                    if level.number < highestUnlockedLevel
                        || levelRecords[level.number]?.completed == true {
                        level.number
                    } else {
                        nil
                    }
                }
            )
        }
        if isUpgradePrestigeMigration {
            for track in UpgradeTrack.allCases {
                setPrestigeCount(
                    max(
                        prestigeCount(for: track),
                        UpgradePrestigeRules.migratedPrestigeCount(for: rank(for: track))
                    ),
                    for: track
                )
            }
        }
        endlessRecord.reconcileRelics()
        schemaVersion = 12
    }

    func hasClearedCurrentCampaignLevel(_ level: Int) -> Bool {
        currentCampaignClears.contains(level)
    }

    var canBeginNextCampaignCycle: Bool {
        currentCampaignClears.contains(GameContent.levels.count)
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case trainingTokens
        case highestUnlockedLevel
        case campaignCycle
        case currentCampaignClears
        case highestCompletedCampaignCycle
        case upgradeRanks
        case upgradePrestiges
        case levelRecords
        case hasMovedInTutorial
        case endlessRecord
        /// Legacy per-world Endless records, merged into `endlessRecord` on decode.
        case endlessRecords
        case lifetimeStats
        case dailyReward
        case missions
        case missionsDay
        case unlockedAchievements
        case hasSeenOnboarding
        case seenCampaignBriefingLevels
        case unlockedCharacters
        case selectedCharacter
    }

    init(
        schemaVersion: Int,
        trainingTokens: Int,
        highestUnlockedLevel: Int,
        campaignCycle: Int = 0,
        currentCampaignClears: Set<Int>? = nil,
        highestCompletedCampaignCycle: Int = 0,
        upgradeRanks: [UpgradeTrack: Int],
        upgradePrestiges: [UpgradeTrack: Int] = [:],
        levelRecords: [Int: LevelRecord],
        hasMovedInTutorial: Bool,
        endlessRecord: EndlessRecord = .empty,
        lifetimeStats: LifetimeStats = LifetimeStats(),
        dailyReward: DailyRewardState = DailyRewardState(),
        missions: [MissionState] = [],
        missionsDay: String = "",
        unlockedAchievements: Set<AchievementID> = [],
        hasSeenOnboarding: Bool = false,
        seenCampaignBriefingLevels: Set<Int> = [],
        unlockedCharacters: Set<CharacterID> = [.ace],
        selectedCharacter: CharacterID = .ace
    ) {
        self.schemaVersion = schemaVersion
        self.trainingTokens = trainingTokens
        self.highestUnlockedLevel = highestUnlockedLevel
        self.campaignCycle = max(0, campaignCycle)
        self.currentCampaignClears = currentCampaignClears ?? Set(
            levelRecords.compactMap { $0.value.completed ? $0.key : nil }
        )
        self.highestCompletedCampaignCycle = max(0, highestCompletedCampaignCycle)
        self.upgradeRanks = upgradeRanks
        self.upgradePrestiges = upgradePrestiges
        self.levelRecords = levelRecords
        self.hasMovedInTutorial = hasMovedInTutorial
        self.endlessRecord = endlessRecord
        self.lifetimeStats = lifetimeStats
        self.dailyReward = dailyReward
        self.missions = missions
        self.missionsDay = missionsDay
        self.unlockedAchievements = unlockedAchievements
        self.hasSeenOnboarding = hasSeenOnboarding
        self.seenCampaignBriefingLevels = seenCampaignBriefingLevels
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
        upgradePrestiges = container.decodeEnumKeyedMap(forKey: .upgradePrestiges)
        levelRecords = try container.decodeIfPresent([Int: LevelRecord].self, forKey: .levelRecords) ?? [:]
        campaignCycle = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .campaignCycle) ?? 0
        )
        currentCampaignClears = try container.decodeIfPresent(
            Set<Int>.self,
            forKey: .currentCampaignClears
        ) ?? Set(levelRecords.compactMap { $0.value.completed ? $0.key : nil })
        highestCompletedCampaignCycle = max(
            0,
            try container.decodeIfPresent(
                Int.self,
                forKey: .highestCompletedCampaignCycle
            ) ?? 0
        )
        hasMovedInTutorial = try container.decodeIfPresent(Bool.self, forKey: .hasMovedInTutorial) ?? false
        if let storedRecord = try container.decodeIfPresent(
            EndlessRecord.self,
            forKey: .endlessRecord
        ) {
            endlessRecord = storedRecord
        } else {
            var legacyRecords: [WorldID: EndlessRecord] = container.decodeEnumKeyedMap(
                forKey: .endlessRecords
            )
            if schemaVersion < 5 {
                legacyRecords.removeValue(forKey: .mars)
            }
            endlessRecord = EndlessRecord(
                bestWave: legacyRecords.values.map(\.bestWave).max() ?? 0,
                bestScore: legacyRecords.values.map(\.bestScore).max() ?? 0
            )
        }
        lifetimeStats = try container.decodeIfPresent(LifetimeStats.self, forKey: .lifetimeStats) ?? LifetimeStats()
        dailyReward = try container.decodeIfPresent(DailyRewardState.self, forKey: .dailyReward) ?? DailyRewardState()
        missions = try container.decodeIfPresent([MissionState].self, forKey: .missions) ?? []
        missionsDay = try container.decodeIfPresent(String.self, forKey: .missionsDay) ?? ""
        unlockedAchievements = try container.decodeIfPresent(Set<AchievementID>.self, forKey: .unlockedAchievements) ?? []
        hasSeenOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasSeenOnboarding) ?? false
        seenCampaignBriefingLevels = try container.decodeIfPresent(
            Set<Int>.self,
            forKey: .seenCampaignBriefingLevels
        ) ?? []
        unlockedCharacters = try container.decodeIfPresent(Set<CharacterID>.self, forKey: .unlockedCharacters) ?? [.ace]
        selectedCharacter = try container.decodeIfPresent(CharacterID.self, forKey: .selectedCharacter) ?? .ace
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(12, forKey: .schemaVersion)
        try container.encode(trainingTokens, forKey: .trainingTokens)
        try container.encode(highestUnlockedLevel, forKey: .highestUnlockedLevel)
        try container.encode(campaignCycle, forKey: .campaignCycle)
        try container.encode(currentCampaignClears, forKey: .currentCampaignClears)
        try container.encode(
            highestCompletedCampaignCycle,
            forKey: .highestCompletedCampaignCycle
        )
        try container.encode(upgradeRanks, forKey: .upgradeRanks)
        try container.encode(upgradePrestiges, forKey: .upgradePrestiges)
        try container.encode(levelRecords, forKey: .levelRecords)
        try container.encode(hasMovedInTutorial, forKey: .hasMovedInTutorial)
        try container.encode(endlessRecord, forKey: .endlessRecord)
        try container.encode(lifetimeStats, forKey: .lifetimeStats)
        try container.encode(dailyReward, forKey: .dailyReward)
        try container.encode(missions, forKey: .missions)
        try container.encode(missionsDay, forKey: .missionsDay)
        try container.encode(unlockedAchievements, forKey: .unlockedAchievements)
        try container.encode(hasSeenOnboarding, forKey: .hasSeenOnboarding)
        try container.encode(seenCampaignBriefingLevels, forKey: .seenCampaignBriefingLevels)
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
