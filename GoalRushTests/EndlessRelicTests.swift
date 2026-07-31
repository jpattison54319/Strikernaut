import Foundation
import Testing
@testable import GoalRush

@MainActor
struct EndlessRelicTests {
    @Test func eligibilityUsesCompletedWavesAndFiveWaveMilestones() {
        #expect(EndlessRelicRules.rewardMilestone(forWaveReached: 1) == nil)
        #expect(EndlessRelicRules.rewardMilestone(forWaveReached: 5) == nil)
        #expect(EndlessRelicRules.rewardMilestone(forWaveReached: 6) == 5)
        #expect(EndlessRelicRules.rewardMilestone(forWaveReached: 10) == 5)
        #expect(EndlessRelicRules.rewardMilestone(forWaveReached: 11) == 10)
        #expect(EndlessRelicRules.rewardMilestone(forWaveReached: 31) == 30)
    }

    @Test func rarityOddsMatchEveryPublishedTierAndContinuePastWaveOneHundred() {
        let expected: [Int: [Int]] = [
            5: [70, 25, 5, 0, 0],
            10: [58, 30, 10, 2, 0],
            20: [43, 34, 17, 5, 1],
            30: [30, 34, 25, 9, 2],
            50: [18, 30, 32, 16, 4],
            70: [10, 24, 36, 23, 7],
            100: [5, 15, 38, 30, 12],
        ]
        for (milestone, values) in expected {
            let odds = EndlessRelicRules.rarityOdds(at: milestone)
            #expect(EndlessRelicRarity.allCases.map { odds[$0, default: -1] } == values)
            #expect(odds.values.reduce(0, +) == 100)
        }

        let wave120 = EndlessRelicRules.rarityOdds(at: 120)
        #expect(wave120[.common] == 4)
        #expect(wave120[.legendary] == 13)
        let wave220 = EndlessRelicRules.rarityOdds(at: 220)
        #expect(wave220[.common] == 0)
        #expect(wave220[.uncommon] == 14)
        #expect(wave220[.legendary] == 18)
        #expect(wave220.values.reduce(0, +) == 100)
    }

    @Test func runRewardIsStableForRunIDAndStoresRolledValues() throws {
        let runID = try #require(
            UUID(uuidString: "EC6C9CC2-76EC-4EA8-9D49-C4DB229636C0")
        )
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let first = try #require(
            EndlessRelicRules.runReward(
                runID: runID,
                waveReached: 38,
                acquiredAt: date
            )
        )
        let second = try #require(
            EndlessRelicRules.runReward(
                runID: runID,
                waveReached: 38,
                acquiredAt: date
            )
        )

        #expect(first == second)
        #expect(first.id == runID)
        #expect(first.sourceWaveMilestone == 35)
        #expect(first.affixes.map(\.stat).first == first.primaryStat)
        #expect(Set(first.affixes.map(\.stat)).count == first.affixes.count)

        let roundTrip = try JSONDecoder().decode(
            EndlessRelic.self,
            from: JSONEncoder().encode(first)
        )
        #expect(roundTrip == first)
    }

    @Test func everyRarityProducesItsDeclaredUniqueAffixCountAndValueRange() throws {
        var found = Set<EndlessRelicRarity>()
        for seed in 1...5_000 where found.count < EndlessRelicRarity.allCases.count {
            let relic = EndlessRelicRules.roll(
                id: UUID(),
                acquiredAt: .now,
                sourceWaveMilestone: 100,
                guaranteedPrimary: .attackDamage,
                seed: UInt64(seed)
            )
            guard found.insert(relic.rarity).inserted else { continue }
            #expect(relic.affixes.count == relic.rarity.affixCount)
            #expect(Set(relic.affixes.map(\.stat)).count == relic.affixes.count)
            for (index, affix) in relic.affixes.enumerated() {
                let factors = index == 0 ? 0.90...1.10 : 0.65...0.85
                let unroundedBase = affix.stat.basePercent
                    * relic.rarity.valueMultiplier
                    * EndlessRelicRules.waveScale(at: 100)
                let actual = affix.percent
                #expect(actual >= unroundedBase * factors.lowerBound - 0.051)
                #expect(actual <= unroundedBase * factors.upperBound + 0.051)
            }
        }
        #expect(found == Set(EndlessRelicRarity.allCases))
    }

    @Test func focusedRollGuaranteesPrimaryWhileRandomRollRemainsDeterministic() {
        let id = UUID()
        let focused = EndlessRelicRules.forgeRoll(
            id: id,
            sourceWaveMilestone: 50,
            focusedStat: .heroChargeRate
        )
        #expect(focused.primaryStat == .heroChargeRate)
        #expect(focused.affixes.first?.stat == .heroChargeRate)

        let acquiredAt = Date(timeIntervalSince1970: 1_700_000_000)
        let randomOne = EndlessRelicRules.forgeRoll(
            id: id,
            acquiredAt: acquiredAt,
            sourceWaveMilestone: 50,
            focusedStat: nil
        )
        let randomTwo = EndlessRelicRules.forgeRoll(
            id: id,
            acquiredAt: acquiredAt,
            sourceWaveMilestone: 50,
            focusedStat: nil
        )
        #expect(randomOne == randomTwo)
    }

    @Test func statPowerScalesForeverEveryFiveClearedWaves() {
        #expect(abs(EndlessRelicRules.waveScale(at: 5) - 1) < 0.0001)
        #expect(abs(EndlessRelicRules.waveScale(at: 30) - 1.25) < 0.0001)
        #expect(abs(EndlessRelicRules.waveScale(at: 100) - 1.95) < 0.0001)
        #expect(abs(EndlessRelicRules.waveScale(at: 500) - 5.95) < 0.0001)
    }

    @Test func legacyRecordDefaultsRelicProgressionWithoutRetroactiveItems() throws {
        let record = try JSONDecoder().decode(
            EndlessRecord.self,
            from: Data(#"{"bestWave":101,"bestScore":900000}"#.utf8)
        )
        #expect(record.relics.isEmpty)
        #expect(record.equippedRelicID == nil)
        #expect(record.scrap == 0)
        #expect(record.lastRewardedRunID == nil)
        #expect(EndlessRelicRules.forgeMilestone(forBestWaveReached: record.bestWave) == 100)
    }

    @Test func invalidEquippedIDAndDuplicateInventoryIDsAreReconciled() {
        let relic = makeRelic(stat: .attackDamage, basisPoints: 500)
        var record = EndlessRecord(
            bestWave: 6,
            bestScore: 1_000,
            relics: [relic, relic],
            equippedRelicID: UUID(),
            scrap: -20
        )
        record.reconcileRelics()
        #expect(record.relics == [relic])
        #expect(record.equippedRelicID == nil)
        #expect(record.scrap == 0)
    }

    @Test func everyRelicStatAppliesExactlyAndCampaignIgnoresTheEquippedRelic() {
        for stat in EndlessRelicStat.allCases {
            let basisPoints = 1_000
            let relic = makeRelic(stat: stat, basisPoints: basisPoints)
            var progress = PlayerProgress.newPlayer
            progress.endlessRecord.relics = [relic]
            progress.endlessRecord.equippedRelicID = relic.id

            let base = PlayerStats(progress: .newPlayer, mode: .endless)
            let endless = PlayerStats(progress: progress, mode: .endless)
            let campaign = PlayerStats(progress: progress, mode: .campaign(level: 1))

            #expect(campaign == PlayerStats(progress: .newPlayer, mode: .campaign(level: 1)))
            switch stat {
            case .attackDamage:
                #expect(abs(endless.ballDamage - base.ballDamage * 1.10) < 0.0001)
            case .maximumStamina:
                #expect(abs(endless.maxStamina - base.maxStamina * 1.10) < 0.0001)
            case .kickRate:
                #expect(abs(endless.kickCooldown - base.kickCooldown / 1.10) < 0.0001)
            case .movementResponse:
                #expect(abs(endless.movementResponse - base.movementResponse * 1.10) < 0.0001)
            case .ballSpeed:
                #expect(abs(endless.ballSpeed - base.ballSpeed * 1.10) < 0.0001)
            case .criticalChance:
                #expect(abs(endless.criticalChance - base.criticalChance - 0.10) < 0.0001)
            case .heroChargeRate:
                #expect(abs(endless.characterAbilityChargeMultiplier - 1.10) < 0.0001)
            case .trainingTokenGain:
                #expect(abs(endless.tokenMultiplier - 1.10) < 0.0001)
            }
        }
    }

    @Test func kickRateOverflowStillConvertsIntoQuickReleaseDamage() {
        let relic = makeRelic(stat: .kickRate, basisPoints: 5_000)
        var progress = PlayerProgress.newPlayer
        progress.endlessRecord.relics = [relic]
        progress.endlessRecord.equippedRelicID = relic.id
        let baseline = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: false,
            seed: 42
        )
        let boosted = GameSimulation(
            mode: .endless,
            progress: progress,
            assistMode: false,
            seed: 42
        )

        #expect(boosted.kickInterval(atAbilityRank: 40) == 0.14)
        #expect(
            boosted.quickReleaseDamageMultiplier(atAbilityRank: 40)
                > baseline.quickReleaseDamageMultiplier(atAbilityRank: 40)
        )
    }

    @Test func heroChargeAndTokenGainUseTheExistingSimulationRewardSources() {
        let chargeBase = chargeAfterOneDefeat(relic: nil)
        let chargeRelic = makeRelic(stat: .heroChargeRate, basisPoints: 5_000)
        let chargeBoosted = chargeAfterOneDefeat(relic: chargeRelic)
        #expect(abs(chargeBoosted / chargeBase - 1.5) < 0.001)

        let tokenBase = tokensAfterOneDefeat(relic: nil)
        let tokenRelic = makeRelic(stat: .trainingTokenGain, basisPoints: 5_000)
        let tokenBoosted = tokensAfterOneDefeat(relic: tokenRelic)
        #expect(tokenBase == 2)
        #expect(tokenBoosted == 3)
    }

    @Test func playerStatsFromAnOlderCheckpointDefaultNewMultiplierToOne() throws {
        let stats = PlayerStats(progress: .newPlayer, mode: .endless)
        let encoded = try JSONEncoder().encode(stats)
        var object = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "characterAbilityChargeMultiplier")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(PlayerStats.self, from: legacyData)
        #expect(decoded.characterAbilityChargeMultiplier == 1)
    }

    @Test func runIDDeduplicatesRewardAndTheResultCarriesThePersistedRelic() throws {
        let store = makeStore()
        let runID = UUID()
        let result = RunResult(
            runID: runID,
            mode: .endless,
            didWin: false,
            tokensEarned: 20,
            remainingStamina: 0,
            wave: 16,
            score: 100_000
        )

        store.finish(result)
        guard case .relicDrop(let firstResult) = store.route else {
            Issue.record("Expected relic drop route")
            return
        }
        let firstRelic = try #require(firstResult.relicEarned)
        #expect(store.progress.endlessRecord.relics == [firstRelic])
        #expect(store.progress.endlessRecord.lastRewardedRunID == runID)
        store.continueAfterRelicDrop(firstResult)
        #expect(store.route == .result(firstResult))

        store.finish(result)
        guard case .result(let secondResult) = store.route else {
            Issue.record("Expected result route")
            return
        }
        #expect(store.progress.endlessRecord.relics == [firstRelic])
        #expect(secondResult.relicEarned == nil)
    }

    @Test func forgeSpendsAtomicallyAndFocusedForgeGuaranteesTheRequestedStat() throws {
        let store = makeStore(bestWave: 51, scrap: 119)
        let focused = try #require(store.forgeRelic(focusing: .ballSpeed))
        #expect(focused.primaryStat == .ballSpeed)
        #expect(focused.sourceWaveMilestone == 50)
        #expect(store.progress.endlessRecord.scrap == 39)
        #expect(store.progress.endlessRecord.relics == [focused])

        let count = store.progress.endlessRecord.relics.count
        #expect(store.forgeRelic() == nil)
        #expect(store.progress.endlessRecord.scrap == 39)
        #expect(store.progress.endlessRecord.relics.count == count)
    }

    @Test func randomForgeAndScrappingUseRarityValuesAndHandleEquippedRelics() throws {
        let store = makeStore(bestWave: 31, scrap: 40)
        let rolled = try #require(store.forgeRelic())
        #expect(store.progress.endlessRecord.scrap == 0)
        #expect(store.equipRelic(rolled.id))

        let legendary = makeRelic(
            stat: .criticalChance,
            basisPoints: 600,
            rarity: .legendary
        )
        store.progress.endlessRecord.relics.append(legendary)
        let recovered = store.scrapRelics([rolled.id, legendary.id])

        #expect(recovered == rolled.scrapValue + 35)
        #expect(store.progress.endlessRecord.scrap == recovered)
        #expect(store.progress.endlessRecord.relics.isEmpty)
        #expect(store.progress.endlessRecord.equippedRelicID == nil)
    }

    @Test func equippedRelicAndStatsAreFrozenIntoRecoveredRunCheckpoint() throws {
        let relic = makeRelic(stat: .maximumStamina, basisPoints: 2_500)
        var progress = PlayerProgress.newPlayer
        progress.endlessRecord.relics = [relic]
        progress.endlessRecord.equippedRelicID = relic.id
        let session = GameSessionModel(
            mode: .endless,
            progress: progress,
            settings: GameSettings()
        )
        if case .draft(let choices) = session.phase, let choice = choices.first {
            session.choose(choice)
        }
        session.completeCurrentWaveForTesting()
        let checkpoint = try #require(
            session.makeRunCheckpoint(creditedRunTokens: 0, previous: nil)
        )

        #expect(checkpoint.runID == session.runID)
        #expect(checkpoint.activeRelic == relic)
        #expect(abs(checkpoint.simulation.stats.maxStamina - 125) < 0.001)

        let restored = GameSessionModel(
            mode: .endless,
            progress: .newPlayer,
            settings: GameSettings(),
            checkpoint: checkpoint
        )
        #expect(restored.runID == session.runID)
        #expect(restored.activeRelic == relic)
        #expect(abs(restored.snapshot.maxStamina - 125) < 0.001)
    }

    @Test func resetRemovesInventoryScrapAndEquippedRelic() {
        let store = makeStore(bestWave: 51, scrap: 100)
        let relic = makeRelic(stat: .attackDamage, basisPoints: 500)
        store.progress.endlessRecord.relics = [relic]
        store.progress.endlessRecord.equippedRelicID = relic.id

        store.resetProgress()

        #expect(store.progress.endlessRecord == .empty)
    }

    private func makeRelic(
        stat: EndlessRelicStat,
        basisPoints: Int,
        rarity: EndlessRelicRarity = .common
    ) -> EndlessRelic {
        EndlessRelic(
            id: UUID(),
            acquiredAt: .now,
            sourceWaveMilestone: 5,
            rarity: rarity,
            primaryStat: stat,
            affixes: [.init(stat: stat, basisPoints: basisPoints)]
        )
    }

    private func makeStore(bestWave: Int = 0, scrap: Int = 0) -> GameStore {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
        var progress = PlayerProgress.newPlayer
        progress.endlessRecord.bestWave = bestWave
        progress.endlessRecord.scrap = scrap
        return GameStore(
            progress: progress,
            settings: .init(),
            persistence: FileProgressStore(
                fileURL: directory.appending(path: "save.json")
            )
        )
    }

    private func progress(equipping relic: EndlessRelic?) -> PlayerProgress {
        var progress = PlayerProgress.newPlayer
        if let relic {
            progress.endlessRecord.relics = [relic]
            progress.endlessRecord.equippedRelicID = relic.id
        }
        return progress
    }

    private func chargeAfterOneDefeat(relic: EndlessRelic?) -> Double {
        let simulation = GameSimulation(
            mode: .endless,
            progress: progress(equipping: relic),
            assistMode: false,
            seed: 88
        )
        simulation.replaceTargetsForTesting([
            .init(
                id: 1,
                kind: .enemy(.coneRunner),
                position: .init(x: 0, y: 0.18),
                hitPoints: 1,
                maximumHitPoints: 1,
                phase: 0
            ),
        ])
        simulation.spawnFriendlyProjectileForTesting(pierce: 0)
        _ = simulation.update(delta: 0.01)
        return simulation.snapshot.characterAbilityCharge
    }

    private func tokensAfterOneDefeat(relic: EndlessRelic?) -> Int {
        let simulation = GameSimulation(
            mode: .endless,
            progress: progress(equipping: relic),
            assistMode: false,
            seed: 89
        )
        simulation.replaceTargetsForTesting([
            .init(
                id: 1,
                kind: .enemy(.coneRunner),
                position: .init(x: 0, y: 0.18),
                hitPoints: 1,
                maximumHitPoints: 1,
                phase: 0
            ),
        ])
        simulation.spawnFriendlyProjectileForTesting(pierce: 0)
        _ = simulation.update(delta: 0.01)
        return simulation.snapshot.tokens
    }
}
