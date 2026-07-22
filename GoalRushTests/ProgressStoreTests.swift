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
        #expect(progress.unlockedGear.isEmpty)
        #expect(progress.equippedGear.isEmpty)
        #expect(progress.endlessRecords.isEmpty)
    }

    @Test func corruptSaveRecoversToNewPlayer() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "save.json")
        try Data("not-json".utf8).write(to: url)
        let store = FileProgressStore(fileURL: url)
        #expect(try store.load() == .newPlayer)
    }

    @Test func upgradeCostTableIsMonotonic() {
        #expect(UpgradeRules.costs == UpgradeRules.costs.sorted())
        #expect(UpgradeRules.costs.count == UpgradeRules.maxRank)
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

    @Test func clearingWorldAwardsGearOnlyOnceAndUnlocksMars() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistence = FileProgressStore(fileURL: directory.appending(path: "save.json"))
        var progress = PlayerProgress.newPlayer
        progress.highestUnlockedLevel = 10
        let gameStore = GameStore(progress: progress, settings: .init(), persistence: persistence)

        gameStore.finish(.init(level: 10, didWin: true, tokensEarned: 10, remainingStamina: 50))
        #expect(gameStore.progress.highestUnlockedLevel == 11)
        #expect(gameStore.progress.unlockedGear == Set(GameContent.world(.earth).gearRewards))
        if case .result(let result) = gameStore.route {
            #expect(result.gearEarned.count == 5)
        } else {
            Issue.record("Expected a result route")
        }

        gameStore.finish(.init(level: 10, didWin: true, tokensEarned: 0, remainingStamina: 50))
        if case .result(let result) = gameStore.route {
            #expect(result.gearEarned.isEmpty)
        } else {
            Issue.record("Expected a result route")
        }
    }

    @Test func existingEarthCompletionRetroactivelyUnlocksMarsAndGear() {
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
        #expect(gameStore.progress.unlockedGear == Set(GameContent.world(.earth).gearRewards))
    }

    @Test func worldSelectionAcceptsUnlockedMarsAndRejectsLockedMars() {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistence = FileProgressStore(fileURL: directory.appending(path: "save.json"))
        let lockedStore = GameStore(progress: .newPlayer, settings: .init(), persistence: persistence)
        #expect(!lockedStore.selectWorld(.mars))
        #expect(lockedStore.selectedWorld == .earth)

        var unlockedProgress = PlayerProgress.newPlayer
        unlockedProgress.highestUnlockedLevel = 11
        let unlockedStore = GameStore(progress: unlockedProgress, settings: .init(), persistence: persistence)
        #expect(unlockedStore.selectWorld(.mars))
        #expect(unlockedStore.selectedWorld == .mars)
    }

    @Test func lockerRejectsLockedOrWrongSlotGear() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let gameStore = GameStore(
            progress: .newPlayer,
            settings: .init(),
            persistence: FileProgressStore(fileURL: directory.appending(path: "save.json"))
        )
        #expect(!gameStore.equip(.earthVisor, in: .head))
        gameStore.progress.unlockedGear.insert(.earthVisor)
        #expect(!gameStore.equip(.earthVisor, in: .feet))
        #expect(gameStore.equip(.earthVisor, in: .head))
        #expect(gameStore.progress.equippedGear[.head] == .earthVisor)
        #expect(gameStore.equip(nil, in: .head))
        #expect(gameStore.progress.equippedGear[.head] == nil)
    }

    @Test func endlessRecordsAreIndependentPerWorld() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let gameStore = GameStore(
            progress: .newPlayer,
            settings: .init(),
            persistence: FileProgressStore(fileURL: directory.appending(path: "save.json"))
        )
        gameStore.finish(.init(mode: .endless(world: .earth), didWin: false, tokensEarned: 9, remainingStamina: 0, wave: 12, score: 45_000))
        gameStore.finish(.init(mode: .endless(world: .earth), didWin: false, tokensEarned: 1, remainingStamina: 0, wave: 7, score: 8_000))
        #expect(gameStore.progress.endlessRecord(for: .earth) == .init(bestWave: 12, bestScore: 45_000))
        #expect(gameStore.progress.endlessRecord(for: .mars) == .empty)
    }

    @Test func expectedAudioAssetsAreBundled() {
        let names = ["kick", "impact", "coin", "heal", "confirm", "victory", "defeat", "boss-phase", "music-calm", "music-pressure", "music-boss"]
        for name in names {
            #expect(Bundle.main.url(forResource: name, withExtension: "wav") != nil)
        }
    }
}
