import Foundation
import Testing
@testable import GoalRush

@MainActor
struct NewGamePlusTests {
    @Test func startingNewGamePlusResetsOnlyTheActiveCampaign() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = FileProgressStore(
            fileURL: directory.appending(path: "save.json")
        )
        let relic = try #require(
            EndlessRelicRules.runReward(
                runID: UUID(),
                waveReached: 31
            )
        )
        var progress = PlayerProgress.newPlayer
        progress.trainingTokens = 9_500
        progress.highestUnlockedLevel = GameContent.levels.count
        progress.currentCampaignClears = Set(1...GameContent.levels.count)
        progress.levelRecords[1] = .init(
            completed: true,
            bestTokens: 875,
            bestStamina: 91
        )
        progress.setRank(18, for: .impact)
        progress.unlockedCharacters = Set(CharacterID.allCases)
        progress.endlessRecord = .init(
            bestWave: 31,
            bestScore: 400_000,
            relics: [relic],
            equippedRelicID: relic.id,
            scrap: 120
        )

        let store = GameStore(
            progress: progress,
            settings: .init(),
            persistence: persistence
        )

        #expect(store.beginNextCampaignCycle())
        #expect(store.progress.campaignCycle == 1)
        #expect(store.progress.currentCampaignClears.isEmpty)
        #expect(store.progress.highestUnlockedLevel == 1)
        #expect(store.progress.trainingTokens == 9_500)
        #expect(store.progress.rank(for: .impact) == 18)
        #expect(store.progress.levelRecords[1]?.bestTokens == 875)
        #expect(store.progress.unlockedCharacters == Set(CharacterID.allCases))
        #expect(store.progress.endlessRecord.equippedRelic == relic)
        #expect(store.progress.endlessRecord.scrap == 120)
        #expect(store.progress.unlockedAchievements.contains(.newGamePlusStarted))
        #expect(
            store.route == .campaign(
                .worldMap(world: .earth, focusLevel: 1)
            )
        )
        #expect(try persistence.load() == store.progress)
    }

    @Test func cyclesCanRepeatAndFirstNewGamePlusClearEarnsAchievement() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = FileProgressStore(
            fileURL: directory.appending(path: "save.json")
        )
        var progress = PlayerProgress.newPlayer
        progress.campaignCycle = 1
        progress.highestUnlockedLevel = GameContent.levels.count
        progress.currentCampaignClears = Set(1..<GameContent.levels.count)
        progress.unlockedCharacters = Set(CharacterID.allCases)
        let store = GameStore(
            progress: progress,
            settings: .init(),
            persistence: persistence
        )
        let result = RunResult(
            level: GameContent.levels.count,
            didWin: true,
            tokensEarned: 500,
            remainingStamina: 75
        )

        store.finish(result)

        #expect(store.progress.currentCampaignClears.contains(GameContent.levels.count))
        #expect(store.progress.highestCompletedCampaignCycle == 1)
        #expect(store.progress.unlockedAchievements.contains(.newGamePlusCleared))

        store.continueAfterResult(result)
        #expect(store.route == .campaign(.planets(page: 2)))

        #expect(store.beginNextCampaignCycle())
        #expect(store.progress.campaignCycle == 2)
        #expect(store.progress.currentCampaignClears.isEmpty)
        #expect(store.progress.highestUnlockedLevel == 1)
        #expect(store.progress.highestCompletedCampaignCycle == 1)
    }

    @Test func legacyCampaignClearsMigrateIntoTheBaseCycle() throws {
        let json = """
        {
          "schemaVersion": 11,
          "highestUnlockedLevel": 70,
          "levelRecords": {
            "1": {"completed": true, "bestTokens": 20, "bestStamina": 80},
            "70": {"completed": true, "bestTokens": 900, "bestStamina": 40}
          }
        }
        """
        var progress = try JSONDecoder().decode(
            PlayerProgress.self,
            from: Data(json.utf8)
        )

        #expect(progress.campaignCycle == 0)
        #expect(progress.currentCampaignClears == [1, 70])
        #expect(progress.canBeginNextCampaignCycle)

        progress.reconcileUnlockedContent()
        #expect(progress.schemaVersion == 12)
        #expect(progress.levelRecords[70]?.bestTokens == 900)
    }

    @Test func difficultyStartsPastTheBaseFinalAndAcceleratesEveryCycle() throws {
        let baseFinal = GameContent.level(GameContent.levels.count)
        let newGamePlusOpening = GameContent.level(1)
        let baseWave = CampaignBalance.wave(1, for: baseFinal)
        let plusWave = CampaignBalance.wave(
            1,
            for: newGamePlusOpening,
            cycle: 1
        )

        #expect(CampaignBalance.targetPermanentRank(for: baseFinal) == 15)
        #expect(
            try #require(
                CampaignDifficulty.referenceRank(cycle: 1, levelNumber: 1)
            ) == 32
        )
        #expect(plusWave.healthMultiplier > baseWave.healthMultiplier)
        #expect(plusWave.damageMultiplier >= baseWave.damageMultiplier)
        #expect(plusWave.speedMultiplier > baseWave.speedMultiplier)

        let cycleOneFinalRank = try #require(
            CampaignDifficulty.referenceRank(cycle: 1, levelNumber: 70)
        )
        let cycleTwoStartRank = try #require(
            CampaignDifficulty.referenceRank(cycle: 2, levelNumber: 1)
        )
        let cycleTwoFinalRank = try #require(
            CampaignDifficulty.referenceRank(cycle: 2, levelNumber: 70)
        )
        let cycleThreeStartRank = try #require(
            CampaignDifficulty.referenceRank(cycle: 3, levelNumber: 1)
        )
        #expect(abs(cycleTwoStartRank - cycleOneFinalRank - 2) < 0.000_001)
        #expect(abs(cycleThreeStartRank - cycleTwoFinalRank - 2) < 0.000_001)

        let cycleOneFinalPressure = try #require(
            CampaignDifficulty.pressureLevel(cycle: 1, levelNumber: 70)
        )
        let cycleTwoStartPressure = try #require(
            CampaignDifficulty.pressureLevel(cycle: 2, levelNumber: 1)
        )
        #expect(abs(cycleTwoStartPressure - cycleOneFinalPressure - 10) < 0.000_001)
        #expect(
            try #require(
                CampaignDifficulty.pressureLevel(cycle: 2, levelNumber: 2)
            ) - cycleTwoStartPressure == 2.5
        )
    }

    @Test func newGamePlusPreservesSimulationSafetyCapsAndRaisesRewards() {
        let level = GameContent.level(GameContent.levels.count)
        let wave = CampaignBalance.wave(level.waveCount, for: level, cycle: 100)

        #expect(wave.speedMultiplier <= 2.25)
        #expect(wave.spawnInterval >= 0.32)
        #expect(
            CampaignBalance.hostileProjectileSpeedMultiplier(
                level: level,
                wave: level.waveCount,
                cycle: 100
            ) <= 2.5
        )
        #expect(
            CampaignBalance.maximumActiveEnemies(
                wave: level.waveCount,
                for: level,
                cycle: 100
            ) <= 48
        )
        #expect(
            CampaignBalance.maximumHostileProjectiles(
                wave: level.waveCount,
                for: level,
                cycle: 100
            ) <= 10
        )
        #expect(CampaignDifficulty.scaledCompletionBonus(100, cycle: 0) == 100)
        #expect(CampaignDifficulty.scaledCompletionBonus(100, cycle: 1) == 175)
        #expect(CampaignDifficulty.scaledCompletionBonus(100, cycle: 2) == 250)
    }

    @Test func campaignShieldsAppearOnlyAfterNewGamePlusStarts() {
        var plusProgress = PlayerProgress.newPlayer
        plusProgress.campaignCycle = 1
        plusProgress.setRank(35, for: .conditioning)
        var foundShield = false

        for seed in UInt64(1)...UInt64(30) where !foundShield {
            let simulation = GameSimulation(
                level: GameContent.level(1),
                progress: plusProgress,
                assistMode: false,
                seed: seed
            )
            for _ in 0..<500 {
                _ = simulation.update(delta: 0.01)
            }
            foundShield = simulation.snapshot.targets.contains {
                $0.maximumShieldHitPoints > 0
            }
        }
        #expect(foundShield)

        let baseSimulation = GameSimulation(
            level: GameContent.level(70),
            progress: .newPlayer,
            assistMode: false,
            seed: 4_022
        )
        for _ in 0..<500 {
            _ = baseSimulation.update(delta: 0.01)
        }
        #expect(baseSimulation.snapshot.targets.allSatisfy {
            $0.maximumShieldHitPoints == 0
        })
    }

    @Test func endlessDropsGainCyclePowerButForgeRollsRemainNormal() throws {
        let runID = try #require(
            UUID(uuidString: "1D87E537-EFF0-4DE5-A75F-5860396C629E")
        )
        let base = EndlessRelicRules.roll(
            id: runID,
            acquiredAt: .now,
            sourceWaveMilestone: 30,
            guaranteedPrimary: .attackDamage,
            seed: 91
        )
        let plus = EndlessRelicRules.roll(
            id: runID,
            acquiredAt: .now,
            sourceWaveMilestone: 30,
            newGamePlusCycle: 1,
            guaranteedPrimary: .attackDamage,
            seed: 91
        )
        let rarityReference = EndlessRelicRules.roll(
            id: runID,
            acquiredAt: .now,
            sourceWaveMilestone: 50,
            guaranteedPrimary: .attackDamage,
            seed: 91
        )
        let baseNormalized = try #require(base.affixes.first).percent
            / base.rarity.valueMultiplier
        let plusNormalized = try #require(plus.affixes.first).percent
            / plus.rarity.valueMultiplier

        #expect(plus.newGamePlusCycle == 1)
        #expect(plus.rarity == rarityReference.rarity)
        #expect(abs(plusNormalized / baseNormalized - 1.25) < 0.02)

        let forge = EndlessRelicRules.forgeRoll(
            id: UUID(),
            sourceWaveMilestone: 30,
            focusedStat: .attackDamage
        )
        #expect(forge.newGamePlusCycle == 0)

        let legacyJSON = """
        {
          "id": "1D87E537-EFF0-4DE5-A75F-5860396C629E",
          "acquiredAt": 0,
          "sourceWaveMilestone": 30,
          "rarity": "rare",
          "primaryStat": "attackDamage",
          "affixes": [{"stat": "attackDamage", "basisPoints": 500}]
        }
        """
        let legacy = try JSONDecoder().decode(
            EndlessRelic.self,
            from: Data(legacyJSON.utf8)
        )
        #expect(legacy.newGamePlusCycle == 0)
    }

    @Test func campaignCheckpointsAreBoundToTheirCycle() async throws {
        var progress = PlayerProgress.newPlayer
        progress.campaignCycle = 1
        progress.seenCampaignBriefingLevels.insert(1)
        let session = GameSessionModel(
            mode: .campaign(level: 1),
            progress: progress,
            settings: .init()
        )
        session.completeCurrentWaveForTesting()
        let checkpoint = try #require(
            session.makeRunCheckpoint(
                creditedRunTokens: session.snapshot.tokens,
                previous: nil
            )
        )
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let checkpointStore = RunCheckpointStore(directoryURL: directory)

        #expect(checkpoint.campaignCycle == 1)
        try await checkpointStore.save(checkpoint)
        #expect(
            await checkpointStore.load(
                for: .campaign(level: 1),
                campaignCycle: 1
            ) == checkpoint
        )
        #expect(
            await checkpointStore.load(
                for: .campaign(level: 1),
                campaignCycle: 0
            ) == nil
        )
    }
}
