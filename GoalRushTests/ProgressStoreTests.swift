import Foundation
import Testing
@testable import GoalRush

@MainActor
struct ProgressStoreTests {
    @Test func progressRoundTrips() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let url = directory.appending(path: "save.json")
        let store = FileProgressStore(fileURL: url)
        var progress = PlayerProgress.newPlayer
        progress.trainingTokens = 321
        progress.highestUnlockedLevel = 4
        progress.setRank(2, for: .impact)
        progress.setPrestigeCount(1, for: .impact)
        try store.save(progress)
        #expect(try store.load() == progress)
    }

    @Test func versionOneSaveMigratesWithoutLosingProgress() throws {
        let json = """
        {
          "schemaVersion": 1,
          "trainingTokens": 777,
          "highestUnlockedLevel": 6,
          "upgradeRanks": [],
          "levelRecords": {},
          "hasMovedInTutorial": true
        }
        """
        let progress = try JSONDecoder().decode(PlayerProgress.self, from: Data(json.utf8))
        #expect(progress.schemaVersion == 2)
        #expect(progress.trainingTokens == 777)
        #expect(progress.highestUnlockedLevel == 6)
        #expect(progress.unlockedCharacters == [.ace])
        #expect(progress.endlessRecord == .empty)
    }

    @Test func corruptSaveRecoversToNewPlayer() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "save.json")
        try Data("not-json".utf8).write(to: url)
        let store = FileProgressStore(fileURL: url)
        #expect(try store.load() == .newPlayer)
    }

    @Test func resettingAccountRemovesSaveAndRestartsOnboarding() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let saveURL = directory.appending(path: "save.json")
        let persistence = FileProgressStore(fileURL: saveURL)
        var progress = PlayerProgress.newPlayer
        progress.trainingTokens = 8_000
        progress.highestUnlockedLevel = 21
        progress.hasSeenOnboarding = true
        try persistence.save(progress)

        let gameStore = GameStore(progress: progress, settings: .init(), persistence: persistence)
        gameStore.selectedLevel = 24
        gameStore.selectedWorld = .mars
        gameStore.pendingResetConfirmation = true

        gameStore.resetProgress()

        #expect(gameStore.progress == .newPlayer)
        #expect(gameStore.selectedLevel == 1)
        #expect(gameStore.selectedWorld == .earth)
        #expect(!gameStore.pendingResetConfirmation)
        #expect(gameStore.route == .onboarding)
        #expect(!FileManager.default.fileExists(atPath: saveURL.path))
    }

    @Test func upgradeCostsRiseThroughMasteryThenRemainSteadyForever() {
        #expect(UpgradeRules.costs == UpgradeRules.costs.sorted())
        #expect(UpgradeRules.costs.count == UpgradeRules.masteryRank)
        #expect(UpgradeRules.cost(forNextRank: 0) == 100)
        #expect(UpgradeRules.cost(forNextRank: 4) == 1_300)
        #expect(UpgradeRules.cost(forNextRank: 5) == 1_300)
        #expect(UpgradeRules.cost(forNextRank: 500) == 1_300)
        #expect(UpgradePrestigeRules.prestigeCost == 2_600)
        #expect(
            UpgradePrestigeRules.purchaseCost(level: 10, prestigeCount: 0)
                > UpgradeRules.sustainedCost
        )
    }

    @Test func permanentUpgradePurchasesContinueBeyondRankFive() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistence = FileProgressStore(fileURL: directory.appending(path: "save.json"))
        var progress = PlayerProgress.newPlayer
        progress.trainingTokens = 20_000
        progress.setRank(5, for: .impact)
        let gameStore = GameStore(progress: progress, settings: .init(), persistence: persistence)

        for _ in 0..<5 {
            #expect(gameStore.purchase(.impact))
        }

        #expect(gameStore.progress.rank(for: .impact) == 10)
        #expect(gameStore.progress.trainingTokens == 13_500)
        #expect(try persistence.load().rank(for: .impact) == 10)
    }

    @Test func thresholdPurchasePrestigesBeforeUnlockingTheNextLevel() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistence = FileProgressStore(fileURL: directory.appending(path: "save.json"))
        var progress = PlayerProgress.newPlayer
        progress.trainingTokens = 5_000
        progress.setRank(10, for: .impact)
        let gameStore = GameStore(progress: progress, settings: .init(), persistence: persistence)

        #expect(gameStore.purchase(.impact))
        #expect(gameStore.progress.rank(for: .impact) == 10)
        #expect(gameStore.progress.prestigeCount(for: .impact) == 1)
        #expect(gameStore.progress.trainingTokens == 2_400)

        #expect(gameStore.purchase(.impact))
        #expect(gameStore.progress.rank(for: .impact) == 11)
        #expect(gameStore.progress.prestigeCount(for: .impact) == 1)
        #expect(gameStore.progress.trainingTokens == 1_100)
        #expect(try persistence.load().prestigeCount(for: .impact) == 1)
    }

    @Test func prestigeProgressUsesTenCirclesAcrossNonlinearLevelRanges() {
        #expect(UpgradePrestigeRules.segment(level: 1, prestigeCount: 0).filled == 1)
        #expect(UpgradePrestigeRules.segment(level: 10, prestigeCount: 0).filled == 10)
        #expect(UpgradePrestigeRules.segment(level: 10, prestigeCount: 1).filled == 0)
        #expect(UpgradePrestigeRules.segment(level: 15, prestigeCount: 1).filled == 5)
        #expect(UpgradePrestigeRules.segment(level: 35, prestigeCount: 2).filled == 5)
        #expect(UpgradePrestigeRules.segment(level: 75, prestigeCount: 3).filled == 5)
        #expect(UpgradePrestigeRules.segment(level: 150, prestigeCount: 4).filled == 5)
        #expect(UpgradePrestigeRules.segment(level: 200, prestigeCount: 5).filled == 10)
    }

    @Test func existingHighLevelUpgradesReceiveRequiredPrestigeBadges() {
        var progress = PlayerProgress.newPlayer
        progress.schemaVersion = 6
        progress.setRank(21, for: .impact)

        progress.reconcileUnlockedContent()

        #expect(progress.schemaVersion == 9)
        #expect(progress.prestigeCount(for: .impact) == 2)
        #expect(progress.rank(for: .impact) == 21)
    }

    @Test func finishRetainsCreditedRunTokensWithoutDoubleCounting() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistence = FileProgressStore(fileURL: directory.appending(path: "save.json"))
        let gameStore = GameStore(progress: .newPlayer, settings: .init(), persistence: persistence)
        gameStore.creditRunTokens(12)
        gameStore.finish(.init(level: 1, didWin: false, tokensEarned: 12, remainingStamina: 0), tokensAlreadyCredited: 12)
        #expect(gameStore.progress.trainingTokens == 12)
        #expect(try persistence.load().trainingTokens == 12)
    }

    @Test func clearingEarthUnlocksVoltOnlyOnceAndUnlocksMoon() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistence = FileProgressStore(fileURL: directory.appending(path: "save.json"))
        var progress = PlayerProgress.newPlayer
        progress.highestUnlockedLevel = 10
        let gameStore = GameStore(progress: progress, settings: .init(), persistence: persistence)

        gameStore.finish(.init(level: 10, didWin: true, tokensEarned: 10, remainingStamina: 50))
        #expect(gameStore.progress.highestUnlockedLevel == 11)
        #expect(gameStore.progress.unlockedCharacters.contains(.volt))
        if case .result(let result) = gameStore.route {
            #expect(result.characterEarned == .volt)
        } else {
            Issue.record("Expected a result route")
        }

        gameStore.finish(.init(level: 10, didWin: true, tokensEarned: 0, remainingStamina: 50))
        if case .result(let result) = gameStore.route {
            #expect(result.characterEarned == nil)
        } else {
            Issue.record("Expected a result route")
        }
    }

    @Test func existingEarthCompletionRetroactivelyUnlocksMoonAndVolt() {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        var progress = PlayerProgress.newPlayer
        progress.highestUnlockedLevel = 10
        progress.levelRecords[10] = .init(completed: true, bestTokens: 100, bestStamina: 20)
        let gameStore = GameStore(
            progress: progress,
            settings: .init(),
            persistence: FileProgressStore(fileURL: directory.appending(path: "save.json"))
        )
        #expect(gameStore.progress.highestUnlockedLevel == 11)
        #expect(gameStore.progress.unlockedCharacters.contains(.volt))
    }

    @Test func completedLegacySecondWorldBecomesCompletedMoonAndUnlocksMars() {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        var progress = PlayerProgress.newPlayer
        progress.schemaVersion = 4
        progress.highestUnlockedLevel = 20
        progress.levelRecords[10] = .init(completed: true, bestTokens: 100, bestStamina: 20)
        progress.levelRecords[20] = .init(completed: true, bestTokens: 200, bestStamina: 25)
        progress.unlockedCharacters = [.ace, .volt, .nova, .aegis]

        let gameStore = GameStore(
            progress: progress,
            settings: .init(),
            persistence: FileProgressStore(fileURL: directory.appending(path: "save.json"))
        )

        #expect(gameStore.progress.schemaVersion == 9)
        #expect(gameStore.progress.highestUnlockedLevel == 21)
        #expect(gameStore.progress.unlockedCharacters == [.ace, .volt, .nova])
        #expect(GameContent.isWorldUnlocked(.mars, progress: gameStore.progress))
    }

    @Test func worldSelectionFollowsEarthMoonMarsOrder() {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistence = FileProgressStore(fileURL: directory.appending(path: "save.json"))
        let lockedStore = GameStore(progress: .newPlayer, settings: .init(), persistence: persistence)
        #expect(!lockedStore.selectWorld(.moon))
        #expect(!lockedStore.selectWorld(.mars))
        #expect(lockedStore.selectedWorld == .earth)

        var unlockedProgress = PlayerProgress.newPlayer
        unlockedProgress.highestUnlockedLevel = 11
        let unlockedStore = GameStore(progress: unlockedProgress, settings: .init(), persistence: persistence)
        #expect(unlockedStore.selectWorld(.moon))
        #expect(!unlockedStore.selectWorld(.mars))
        #expect(unlockedStore.selectedWorld == .moon)

        unlockedProgress.highestUnlockedLevel = 21
        let marsStore = GameStore(progress: unlockedProgress, settings: .init(), persistence: persistence)
        #expect(marsStore.selectWorld(.mars))
        #expect(marsStore.selectedWorld == .mars)
    }

    @Test func planetJourneyOpensOnTheActivePlanetsPage() {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistence = FileProgressStore(fileURL: directory.appending(path: "save.json"))

        for world in WorldID.allCases {
            var progress = PlayerProgress.newPlayer
            progress.highestUnlockedLevel = GameContent.world(world).levelRange.lowerBound
            let store = GameStore(progress: progress, settings: .init(), persistence: persistence)
            #expect(store.selectWorld(world))

            store.openPlanetJourney()

            let destinationIndex = WorldJourneyCatalog.destinations.firstIndex {
                $0.world == world
            }
            #expect(store.route == .campaign(.planets(
                page: (destinationIndex ?? 0) / WorldJourneyCatalog.pageSize
            )))
        }
    }

    @Test func rosterRejectsLockedCharacterAndPersistsUnlockedSelection() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let gameStore = GameStore(
            progress: .newPlayer,
            settings: .init(),
            persistence: FileProgressStore(fileURL: directory.appending(path: "save.json"))
        )
        #expect(!gameStore.selectCharacter(.nova))
        gameStore.progress.unlockedCharacters.insert(.nova)
        #expect(gameStore.selectCharacter(.nova))
        #expect(gameStore.progress.selectedCharacter == .nova)
    }

    @Test func endlessRecordIsSharedAcrossTheWorldCircuit() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let gameStore = GameStore(
            progress: .newPlayer,
            settings: .init(),
            persistence: FileProgressStore(fileURL: directory.appending(path: "save.json"))
        )
        gameStore.finish(.init(mode: .endless, didWin: false, tokensEarned: 9, remainingStamina: 0, wave: 12, score: 45_000))
        gameStore.finish(.init(mode: .endless, didWin: false, tokensEarned: 1, remainingStamina: 0, wave: 7, score: 8_000))
        #expect(gameStore.progress.endlessRecord == .init(
            bestWave: 12,
            bestScore: 45_000,
            lastWave: 7,
            lastScore: 8_000
        ))
    }

    @Test func endlessRecordPreservesBestAndPersistsTheMostRecentRun() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let url = directory.appending(path: "save.json")
        let persistence = FileProgressStore(fileURL: url)
        let gameStore = GameStore(
            progress: .newPlayer,
            settings: .init(),
            persistence: persistence
        )

        gameStore.finish(.init(
            mode: .endless,
            didWin: false,
            tokensEarned: 4,
            remainingStamina: 0,
            wave: 18,
            score: 92_000
        ))
        gameStore.finish(.init(
            mode: .endless,
            didWin: false,
            tokensEarned: 2,
            remainingStamina: 0,
            wave: 6,
            score: 14_000
        ))

        let loaded = try persistence.load()
        #expect(loaded.endlessRecord == .init(
            bestWave: 18,
            bestScore: 92_000,
            lastWave: 6,
            lastScore: 14_000
        ))
    }

    @Test func legacyEndlessRecordDecodesWithoutInventingALastRun() throws {
        let record = try JSONDecoder().decode(
            EndlessRecord.self,
            from: Data(#"{"bestWave":14,"bestScore":88000}"#.utf8)
        )

        #expect(record == .init(bestWave: 14, bestScore: 88_000))
        #expect(record.lastWave == nil)
        #expect(record.lastScore == nil)
    }

    @Test func legacyPerWorldEndlessRecordsMergeIntoTheSingleCircuitRecord() throws {
        let json = """
        {
          "schemaVersion": 7,
          "trainingTokens": 12,
          "highestUnlockedLevel": 30,
          "upgradeRanks": {},
          "upgradePrestiges": {},
          "levelRecords": {},
          "hasMovedInTutorial": true,
          "endlessRecords": {
            "earth": {"bestWave": 18, "bestScore": 42000},
            "moon": {"bestWave": 24, "bestScore": 39000},
            "mars": {"bestWave": 20, "bestScore": 61000}
          }
        }
        """

        var progress = try JSONDecoder().decode(
            PlayerProgress.self,
            from: Data(json.utf8)
        )

        #expect(progress.endlessRecord == .init(bestWave: 24, bestScore: 61_000))
        progress.reconcileUnlockedContent()
        #expect(progress.schemaVersion == 9)

        let encoded = try JSONEncoder().encode(progress)
        let object = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        #expect(object["endlessRecord"] != nil)
        #expect(object["endlessRecords"] == nil)
    }

    @Test func expectedAudioAssetsAreBundled() {
        let names = ["kick", "kick-2", "kick-3", "impact", "impact-2", "impact-3", "coin", "heal", "confirm", "victory", "defeat", "boss-phase", "music-calm", "music-pressure", "music-boss",
                     "ui-tap", "ui-whoosh", "ui-purchase", "ui-claim", "ui-fanfare", "ui-draft", "ui-locked", "ui-combo", "volt-chain"]
        for name in names {
            #expect(Bundle.main.url(forResource: name, withExtension: "wav") != nil)
        }
    }

    @Test func versionTwoSaveMigratesToEightWithCurrentDefaults() throws {
        let json = """
        {
          "schemaVersion": 2,
          "trainingTokens": 321,
          "highestUnlockedLevel": 5,
          "upgradeRanks": {"impact": 2},
          "levelRecords": {"1": {"completed": true, "bestTokens": 40, "bestStamina": 30}},
          "hasMovedInTutorial": true,
          "unlockedGear": [],
          "equippedGear": {},
          "endlessRecords": {}
        }
        """
        var progress = try JSONDecoder().decode(PlayerProgress.self, from: Data(json.utf8))
        progress.reconcileUnlockedContent()
        #expect(progress.schemaVersion == 9)
        #expect(progress.trainingTokens == 321)
        #expect(progress.lifetimeStats == LifetimeStats())
        #expect(progress.dailyReward == DailyRewardState())
        #expect(progress.missions.isEmpty)
        #expect(progress.missionsDay.isEmpty)
        #expect(progress.unlockedAchievements.isEmpty)
        #expect(progress.unlockedCharacters == [.ace])
        #expect(progress.selectedCharacter == .ace)
        #expect(!progress.hasSeenOnboarding)
        #expect(progress.seenCampaignBriefingLevels == [1, 2, 3, 4])
        #expect(progress.rank(for: .impact) == 2)
    }
}
