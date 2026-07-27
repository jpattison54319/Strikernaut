import CoreGraphics
import SpriteKit
import Testing
@testable import GoalRush

@MainActor
struct GameSimulationTests {
    @Test func sameSeedProducesSameSimulation() {
        let level = GameContent.level(3)
        let first = GameSimulation(level: level, progress: .newPlayer, assistMode: false, seed: 42)
        let second = GameSimulation(level: level, progress: .newPlayer, assistMode: false, seed: 42)
        first.setPlayerTarget(x: 0.5)
        second.setPlayerTarget(x: 0.5)
        for _ in 0..<900 {
            _ = first.update(delta: 1.0 / 60.0)
            _ = second.update(delta: 1.0 / 60.0)
        }
        #expect(first.snapshot == second.snapshot)
    }

    @Test func movementClampsToPlayableField() {
        let simulation = GameSimulation(level: GameContent.level(1), progress: .newPlayer, assistMode: false, seed: 1)
        simulation.setPlayerTarget(x: 9)
        for _ in 0..<120 { _ = simulation.update(delta: 1.0 / 60.0) }
        #expect(simulation.snapshot.playerX <= 0.92)
    }

    @Test func temporaryAbilityRanksCapAtThree() {
        let simulation = GameSimulation(level: GameContent.level(1), progress: .newPlayer, assistMode: false, seed: 1)
        for _ in 0..<5 { simulation.apply(.powerDrive) }
        #expect(simulation.abilityRank(.powerDrive) == 3)
    }

    @Test func throughBallPiercesOneDistinctTargetPerRank() {
        for pierceRank in 1...2 {
            let simulation = GameSimulation(
                level: GameContent.level(1),
                progress: .newPlayer,
                assistMode: false,
                seed: UInt64(pierceRank)
            )
            let targets = (0..<3).map { index in
                TargetState(
                    id: 8_000 + index,
                    kind: .enemy(.coneRunner),
                    position: .init(x: 0, y: 0.35 + Double(index) * 0.20),
                    hitPoints: 100,
                    maximumHitPoints: 100,
                    phase: 0
                )
            }
            simulation.replaceTargetsForTesting(targets)
            simulation.spawnFriendlyProjectileForTesting(pierce: pierceRank)

            for _ in 0..<20 {
                _ = simulation.update(delta: 0.05)
            }

            let hitPoints = Dictionary(
                uniqueKeysWithValues: simulation.snapshot.targets.map { ($0.id, $0.hitPoints) }
            )
            #expect(hitPoints[8_000] == 90)
            #expect(hitPoints[8_001] == 90)
            #expect(hitPoints[8_002] == (pierceRank == 2 ? 90 : 100))
        }
    }

    @Test func heatSeekingTurnsIntoNearestAvailableTarget() {
        let simulation = GameSimulation(
            level: GameContent.level(1),
            progress: .newPlayer,
            assistMode: false,
            seed: 52
        )
        let nearest = TargetState(
            id: 8_100,
            kind: .enemy(.dummyDefender),
            position: .init(x: 0.34, y: 0.52),
            hitPoints: 100,
            maximumHitPoints: 100,
            phase: 0
        )
        let farther = TargetState(
            id: 8_101,
            kind: .enemy(.dummyDefender),
            position: .init(x: -0.62, y: 0.82),
            hitPoints: 100,
            maximumHitPoints: 100,
            phase: 0
        )
        simulation.replaceTargetsForTesting([nearest, farther])
        simulation.spawnFriendlyProjectileForTesting(
            pierce: 0,
            temporaryAbility: .heatSeeking
        )

        for _ in 0..<20 {
            _ = simulation.update(delta: 0.05)
        }

        let targets = Dictionary(
            uniqueKeysWithValues: simulation.snapshot.targets.map { ($0.id, $0.hitPoints) }
        )
        #expect(targets[nearest.id] == 90)
        #expect(targets[farther.id] == 100)
    }

    @Test func curlerRanksProduceVisibleIncreasingSteering() {
        var lateralVelocities: [Double] = []

        for rank in 1...3 {
            let simulation = GameSimulation(
                level: GameContent.level(1),
                progress: .newPlayer,
                assistMode: false,
                seed: UInt64(60 + rank)
            )
            for _ in 0..<rank {
                simulation.apply(.curler)
            }
            simulation.replaceTargetsForTesting([
                TargetState(
                    id: 8_200 + rank,
                    kind: .enemy(.dummyDefender),
                    position: .init(x: 0.48, y: 0.62),
                    hitPoints: 100,
                    maximumHitPoints: 100,
                    phase: 0
                )
            ])
            simulation.spawnFriendlyProjectileForTesting(pierce: 0)

            for _ in 0..<5 {
                _ = simulation.update(delta: 0.05)
            }

            lateralVelocities.append(simulation.snapshot.projectiles[0].velocity.x)
        }

        #expect(lateralVelocities[0] > 0.20)
        #expect(lateralVelocities[1] > lateralVelocities[0])
        #expect(lateralVelocities[2] > lateralVelocities[1])
    }

    @Test func hostileProjectilesOnlyDamageThePlayersUpperBody() {
        let feetSimulation = GameSimulation(
            level: GameContent.level(1),
            progress: .newPlayer,
            assistMode: false,
            seed: 70
        )
        feetSimulation.spawnHostileProjectileForTesting(x: 0, y: 0.105)
        _ = feetSimulation.update(delta: 0.05)

        let upperBodySimulation = GameSimulation(
            level: GameContent.level(1),
            progress: .newPlayer,
            assistMode: false,
            seed: 71
        )
        upperBodySimulation.spawnHostileProjectileForTesting(x: 0, y: 0.16)
        _ = upperBodySimulation.update(delta: 0.05)

        #expect(feetSimulation.snapshot.stamina == feetSimulation.snapshot.maxStamina)
        #expect(upperBodySimulation.snapshot.stamina < upperBodySimulation.snapshot.maxStamina)
    }

    @Test func wideChestHitboxMatchesItsRenderedBody() {
        let simulation = GameSimulation(
            level: GameContent.level(5),
            progress: .newPlayer,
            assistMode: false,
            seed: 72
        )
        let chest = TargetState(
            id: 8_300,
            kind: .fieldObject(.equipmentTrunk),
            position: .init(x: 0.22, y: 0.30),
            hitPoints: 55,
            maximumHitPoints: 55,
            phase: 0
        )
        simulation.replaceTargetsForTesting([chest])
        simulation.spawnFriendlyProjectileForTesting(pierce: 0)

        for _ in 0..<5 {
            _ = simulation.update(delta: 0.05)
        }

        #expect(simulation.snapshot.targets[0].hitPoints == 45)
    }

    @Test func campaignEnemiesSpawnAcrossContinuousHorizontalSpace() {
        let simulation = GameSimulation(
            level: GameContent.level(1),
            progress: .newPlayer,
            assistMode: false,
            seed: 73
        )
        var observedSpawnPositions: [Double] = []
        var observedIDs: Set<Int> = []

        for _ in 0..<500 {
            _ = simulation.update(delta: 0.05)
            for target in simulation.snapshot.targets where !observedIDs.contains(target.id) {
                if case .enemy = target.kind {
                    observedIDs.insert(target.id)
                    observedSpawnPositions.append(target.position.x)
                }
            }
        }

        #expect(observedSpawnPositions.count >= 6)
        #expect(observedSpawnPositions.allSatisfy { (-0.77...0.77).contains($0) })
        #expect(observedSpawnPositions.contains { position in
            [-0.62, 0, 0.62].allSatisfy { lane in abs(position - lane) > 0.04 }
        })
        let roundedPositions = Set(observedSpawnPositions.map { Int(($0 * 100).rounded()) })
        #expect(roundedPositions.count >= 5)
    }

    @Test func endlessAbilityRanksHaveNoAuthoredCap() {
        let simulation = GameSimulation(mode: .endless, progress: .newPlayer, assistMode: false, seed: 1)
        for _ in 0..<40 { simulation.apply(.powerDrive) }
        #expect(simulation.abilityRank(.powerDrive) == 40)
        #expect(simulation.kickInterval(atAbilityRank: 40) == 0.14)
        #expect(
            simulation.quickReleaseDamageMultiplier(atAbilityRank: 40)
                > simulation.quickReleaseDamageMultiplier(atAbilityRank: 39)
        )
    }

    @Test func endlessDraftPoolContainsTenCoreAndSixNonRedundantBallTracks() {
        let pool = RunUpgradeChoice.endlessPool
        let ballChoices = pool.compactMap { choice -> TemporaryBallAbility? in
            if case .specialBall(let ability) = choice { return ability }
            return nil
        }

        #expect(pool.count == 16)
        #expect(Set(pool).count == pool.count)
        #expect(ballChoices == [.volt, .ice, .fire, .reverse, .explosive, .split])
        #expect(!ballChoices.contains(.rapidFire))
        #expect(!ballChoices.contains(.heatSeeking))
        #expect(!ballChoices.contains(.orbitShot))
        #expect(!ballChoices.contains(.solarPierce))
    }

    @Test func endlessSpecialBallSelectionUsesEqualOrderedBuckets() {
        let ranks = Dictionary(
            uniqueKeysWithValues: EndlessSpecialBallRules.abilities.map { ($0, 1) }
        )
        let count = Double(EndlessSpecialBallRules.abilities.count)

        for (index, ability) in EndlessSpecialBallRules.abilities.enumerated() {
            let roll = (Double(index) + 0.5) / count
            #expect(
                EndlessSpecialBallRules.selectedAbility(ranks: ranks, roll: roll)
                    == ability
            )
        }

        #expect(
            EndlessSpecialBallRules.selectedAbility(
                ranks: [.ice: 4, .split: 1],
                roll: 0.49
            ) == .ice
        )
        #expect(
            EndlessSpecialBallRules.selectedAbility(
                ranks: [.ice: 4, .split: 1],
                roll: 0.50
            ) == .split
        )
    }

    @Test func endlessSpecialBallRanksMatchCampaignAtFiveAndKeepGrowing() {
        #expect(EndlessSpecialBallRules.scale(rank: 1) < 1)
        #expect(EndlessSpecialBallRules.scale(rank: 5) == 1)
        #expect(EndlessSpecialBallRules.scale(rank: 6) > 1)
        #expect(
            EndlessSpecialBallRules.fireDuration(rank: 10_001)
                > EndlessSpecialBallRules.fireDuration(rank: 10_000)
        )
        #expect(
            EndlessSpecialBallRules.explosionDamageMultiplier(rank: 10_001)
                > EndlessSpecialBallRules.explosionDamageMultiplier(rank: 10_000)
        )
        #expect(
            EndlessSpecialBallRules.splitDamageMultiplier(rank: 10_001)
                > EndlessSpecialBallRules.splitDamageMultiplier(rank: 10_000)
        )

        #expect(abs(EndlessSpecialBallRules.iceDuration(rank: 5) - 1.7) < 0.000_001)
        #expect(abs(EndlessSpecialBallRules.fireDuration(rank: 5) - 4) < 0.000_001)
        #expect(abs(EndlessSpecialBallRules.reverseDuration(rank: 5) - 2.8) < 0.000_001)
        #expect(abs(EndlessSpecialBallRules.explosionDamageMultiplier(rank: 5) - 0.55) < 0.000_001)
        #expect(abs(EndlessSpecialBallRules.explosionRadius(rank: 5) - 0.28) < 0.000_001)
        #expect(EndlessSpecialBallRules.splitProjectileCount(rank: 5, isCritical: false) == 5)
        #expect(EndlessSpecialBallRules.splitProjectileCount(rank: 5, isCritical: true) == 8)
        #expect(abs(EndlessSpecialBallRules.splitDamageMultiplier(rank: 5) - 0.42) < 0.000_001)
        #expect(abs(EndlessSpecialBallRules.voltDamageMultiplier(recipientOffset: 0, rank: 5) - 0.15) < 0.000_001)
    }

    @Test func endlessSpecialBallRanksAreRunOnlyAndCampaignRejectsThem() {
        let endless = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: false,
            seed: 91
        )
        for _ in 0..<7 {
            endless.apply(.specialBall(.fire))
        }
        #expect(endless.specialBallRank(.fire) == 7)

        let nextRun = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: false,
            seed: 91
        )
        #expect(nextRun.specialBallRank(.fire) == 0)

        let campaign = GameSimulation(
            level: GameContent.level(1),
            progress: .newPlayer,
            assistMode: false,
            seed: 91
        )
        campaign.apply(.specialBall(.fire))
        #expect(campaign.specialBallRank(.fire) == 0)
    }

    @Test func oneEndlessKickGivesEveryVolleyProjectileTheSameOwnedBallType() {
        let simulation = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: false,
            seed: 97
        )
        simulation.apply(.specialBall(.ice))
        simulation.apply(.ability(.oneTwo))
        simulation.apply(.ability(.oneTwo))

        var sawKick = false
        for _ in 0..<30 where !sawKick {
            sawKick = simulation.update(delta: 0.05).contains(.kick)
        }

        let friendly = simulation.snapshot.projectiles.filter { !$0.hostile }
        #expect(sawKick)
        #expect(friendly.count == 3)
        #expect(friendly.allSatisfy { $0.temporaryAbility == .ice })
    }

    @Test func endlessNeverSpawnsShootablePowerUpsOnRegularOrBossWaves() {
        let regular = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: true,
            seed: 101
        )
        regular.setWaveDefeatsForTesting(regular.snapshot.waveEnemyQuota / 2)
        for _ in 0..<400 {
            _ = regular.update(delta: 0.05)
        }
        #expect(!regular.snapshot.targets.contains {
            if case .powerUp = $0.kind { true } else { false }
        })

        let boss = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: true,
            seed: 103
        )
        boss.setEndlessWaveForTesting(5)
        for _ in 0..<400 {
            _ = boss.update(delta: 0.05)
        }
        #expect(!boss.snapshot.targets.contains {
            if case .powerUp = $0.kind { true } else { false }
        })
    }

    @Test func everyEndlessUpgradeCardChangesAtVeryHighRank() {
        for ability in AbilityKind.allCases {
            let effect = AbilityPresentation.effect(
                for: ability,
                currentRank: 40,
                isEndless: true,
                baseKickInterval: 1.12
            )
            #expect(effect.current != effect.next, "Expected \(ability) to keep improving")
        }

        for ability in EndlessSpecialBallRules.abilities {
            let effect = SpecialBallPresentation.presentation(
                for: ability,
                currentRank: 40
            ).effect
            #expect(effect.current != effect.next, "Expected \(ability) to keep improving")
        }
    }

    @Test func permanentStatsApplyExpectedModifiers() {
        var progress = PlayerProgress.newPlayer
        progress.setRank(2, for: .conditioning)
        progress.setRank(1, for: .impact)
        progress.setRank(5, for: .tempo)
        let stats = PlayerStats(progress: progress)
        #expect(abs(stats.maxStamina - 116) < 0.001)
        #expect(abs(stats.ballDamage - 11) < 0.001)
        #expect(stats.kickCooldown < 0.60)
        #expect(stats.kickCooldown > 0.58)
    }

    @Test func permanentStatsKeepImprovingBeyondMasteryWithoutUnsafeKickCadence() {
        var rankFive = PlayerProgress.newPlayer
        var godBuild = PlayerProgress.newPlayer
        for track in UpgradeTrack.allCases {
            rankFive.setRank(5, for: track)
            godBuild.setRank(50, for: track)
        }

        let mastered = PlayerStats(progress: rankFive)
        let powered = PlayerStats(progress: godBuild)
        #expect(powered.maxStamina > mastered.maxStamina)
        #expect(powered.movementResponse > mastered.movementResponse)
        #expect(powered.kickCooldown < mastered.kickCooldown)
        #expect(powered.kickCooldown > UpgradeRules.minimumKickCooldown)
        #expect(powered.ballDamage > mastered.ballDamage)
        #expect(powered.ballSpeed > mastered.ballSpeed)
        #expect(powered.criticalChance > 1)
    }

    @Test func spinOverflowCreatesGuaranteedAdditionalCriticalDamageTiers() {
        var progress = PlayerProgress.newPlayer
        progress.setRank(66, for: .spin)
        let simulation = GameSimulation(level: GameContent.level(1), progress: progress, assistMode: false, seed: 7)
        for _ in 0..<23 { _ = simulation.update(delta: 0.05) }

        let projectile = simulation.snapshot.projectiles.first { !$0.hostile }
        #expect(projectile?.isCritical == true)
        #expect(projectile?.damage ?? 0 >= 30)
    }

    @Test func baseKickCadenceIsDeliberateAndTempoDriven() {
        let simulation = GameSimulation(level: GameContent.level(1), progress: .newPlayer, assistMode: false, seed: 7)
        var earlyKick = false
        for _ in 0..<22 {
            earlyKick = earlyKick || simulation.update(delta: 0.05).contains(.kick)
        }
        #expect(!earlyKick)
        #expect(simulation.update(delta: 0.05).contains(.kick))
        #expect(abs(PlayerStats(progress: .newPlayer).kickCooldown - 1.12) < 0.001)
    }

    @Test func wideVolleyAddsOneBallAtEachCampaignRank() {
        for rank in 1...3 {
            let simulation = GameSimulation(level: GameContent.level(1), progress: .newPlayer, assistMode: false, seed: UInt64(rank))
            for _ in 0..<rank { simulation.apply(.oneTwo) }
            for _ in 0..<23 { _ = simulation.update(delta: 0.05) }

            let friendly = simulation.snapshot.projectiles.filter { !$0.hostile }
            #expect(friendly.count == rank + 1)
            #expect(friendly.contains { abs($0.velocity.x) < 0.001 })
            #expect(friendly.contains { abs($0.velocity.x) > 0.30 })
        }
    }

    @Test func campaignAbilityCardsShowAChangedEffectAtEveryAvailableRank() {
        let campaignAbilities: [AbilityKind] = [
            .powerDrive, .quickRelease, .throughBall, .curler, .oneTwo, .cleanSheet
        ]

        for ability in campaignAbilities {
            for currentRank in 0..<3 {
                let effect = AbilityPresentation.effect(
                    for: ability,
                    currentRank: currentRank,
                    isEndless: false,
                    baseKickInterval: 1.12
                )
                #expect(effect.current != effect.next, "Expected \(ability) rank \(currentRank + 1) to show a changed effect")
            }
        }
    }

    @Test func defeatsCreditTokensImmediatelyWithoutCollection() {
        let simulation = GameSimulation(level: GameContent.level(1), progress: .newPlayer, assistMode: true, seed: 11)
        var rewardEventValue = 0

        for _ in 0..<500 where rewardEventValue == 0 {
            if let target = simulation.snapshot.targets.first {
                simulation.setPlayerTarget(x: target.position.x)
            }
            for event in simulation.update(delta: 0.05) {
                if case .reward(let value, _) = event { rewardEventValue = value }
            }
        }

        #expect(rewardEventValue > 0)
        #expect(simulation.snapshot.tokens >= rewardEventValue)
    }

    @Test func allLevelsHaveValidContent() {
        #expect(GameContent.levels.count == 30)
        #expect(GameContent.worlds.count == 3)
        #expect(GameContent.levels(in: .earth).count == 10)
        #expect(GameContent.levels(in: .moon).count == 10)
        #expect(GameContent.levels(in: .mars).count == 10)
        for level in GameContent.levels {
            #expect(!level.enemies.isEmpty)
            #expect(!level.objects.isEmpty)
            #expect(level.referenceDuration > 60)
            #expect((3...5).contains(level.waveCount))
            #expect(level.referenceWaveDuration > 15)
            #expect(level.firstClearBonus > level.replayBonus)
        }
        #expect(GameContent.level(1).waveCount == 3)
        #expect(GameContent.level(4).waveCount == 4)
        #expect(GameContent.level(8).waveCount == 5)
        #expect(GameContent.level(11).waveCount == 3)
        #expect(GameContent.level(18).waveCount == 5)
        #expect(GameContent.level(10).hasBoss)
        #expect(GameContent.level(20).hasBoss)
        #expect(GameContent.level(30).hasBoss)
        #expect(GameContent.level(11).world == .moon)
        #expect(GameContent.level(21).world == .mars)
    }

    @Test func campaignWavePressureOutgrowsAnAverageDraftChoice() {
        for level in GameContent.levels {
            var previous = CampaignBalance.wave(1, for: level)
            for waveNumber in 2...level.waveCount {
                let wave = CampaignBalance.wave(waveNumber, for: level)
                #expect(wave.healthMultiplier > previous.healthMultiplier)
                #expect(wave.damageMultiplier > previous.damageMultiplier)
                #expect(wave.speedMultiplier > previous.speedMultiplier)
                #expect(wave.spawnInterval <= previous.spawnInterval)

                let enemyGrowth = wave.healthMultiplier / CampaignBalance.wave(1, for: level).healthMultiplier
                let playerGrowth = CampaignBalance.expectedOffenseMultiplier(afterUpgradeCount: waveNumber - 1)
                #expect(enemyGrowth > playerGrowth)
                previous = wave
            }
        }
    }

    @Test func levelsFiveAndEightCreatePersistentLandmarkStepsInEveryWorld() {
        for world in WorldID.allCases {
            let levels = GameContent.levels(in: world)
            let fourth = CampaignBalance.wave(1, for: levels[3])
            let fifth = CampaignBalance.wave(1, for: levels[4])
            let seventh = CampaignBalance.wave(1, for: levels[6])
            let eighth = CampaignBalance.wave(1, for: levels[7])

            #expect(CampaignBalance.landmarkTier(worldLevel: levels[3].worldLevel) == 0)
            #expect(CampaignBalance.landmarkTier(worldLevel: levels[4].worldLevel) == 1)
            #expect(CampaignBalance.landmarkTier(worldLevel: levels[7].worldLevel) == 2)
            #expect(fifth.healthMultiplier / fourth.healthMultiplier > 1.11)
            #expect(fifth.damageMultiplier / fourth.damageMultiplier > 1.038)
            #expect(
                fifth.spawnInterval < fourth.spawnInterval * 0.96
                    || fifth.spawnInterval == 0.60
            )
            #expect(eighth.healthMultiplier / seventh.healthMultiplier > 1.11)
            #expect(eighth.damageMultiplier / seventh.damageMultiplier > 1.038)
            #expect(
                eighth.spawnInterval < seventh.spawnInterval * 0.96
                    || eighth.spawnInterval == 0.60
            )
        }
    }

    @Test func campaignEnemyQuotasScaleAcrossWavesLevelsAndWorlds() {
        #expect(CampaignBalance.wave(1, for: GameContent.level(1)).enemyQuota == 18)
        #expect(CampaignBalance.wave(1, for: GameContent.level(11)).enemyQuota == 30)
        #expect(CampaignBalance.wave(1, for: GameContent.level(21)).enemyQuota == 42)
        #expect(CampaignBalance.wave(1, for: GameContent.level(30)).enemyQuota == 50)

        var previousOpeningQuota = 0
        for level in GameContent.levels {
            let openingQuota = CampaignBalance.wave(1, for: level).enemyQuota
            #expect(openingQuota >= previousOpeningQuota)
            previousOpeningQuota = openingQuota

            var previousWaveQuota = 0
            for waveNumber in 1..<level.waveCount {
                let wave = CampaignBalance.wave(waveNumber, for: level)
                #expect(!wave.isBossWave)
                #expect(wave.enemyQuota > previousWaveQuota)
                previousWaveQuota = wave.enemyQuota
            }

            let bossWave = CampaignBalance.wave(level.waveCount, for: level)
            #expect(bossWave.isBossWave)
            #expect(bossWave.enemyQuota == 1)
        }
    }

    @Test func activeEnemyCapsRiseWithoutAllowingUnboundedCrowds() {
        #expect(CampaignBalance.maximumActiveEnemies(wave: 1, world: .earth) == 4)
        #expect(CampaignBalance.maximumActiveEnemies(wave: 5, world: .earth) == 6)
        #expect(CampaignBalance.maximumActiveEnemies(wave: 5, world: .mars) == 8)
        #expect(CampaignBalance.maximumActiveEnemies(wave: 100, world: .mars) == 8)

        #expect(EndlessRules.maximumActiveEnemies(wave: 1) == 5)
        #expect(EndlessRules.maximumActiveEnemies(wave: 21) == 7)
        #expect(EndlessRules.maximumActiveEnemies(wave: 100) == 10)
    }

    @Test func spawningNeverExceedsTheUnspawnedQuotaTail() {
        let campaign = GameSimulation(
            level: GameContent.level(1),
            progress: .newPlayer,
            assistMode: false,
            seed: 100
        )
        campaign.setWaveDefeatsForTesting(campaign.snapshot.waveEnemyQuota - 1)
        for _ in 0..<32 { _ = campaign.update(delta: 0.05) }
        let campaignQuotaEnemies = campaign.snapshot.targets.filter {
            if case .enemy = $0.kind { $0.waveRole == .quota } else { false }
        }
        #expect(campaignQuotaEnemies.count == 1)

        let endless = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: false,
            seed: 101
        )
        endless.setEndlessWaveForTesting(31)
        endless.setWaveDefeatsForTesting(endless.snapshot.waveEnemyQuota - 2)
        for _ in 0..<20 { _ = endless.update(delta: 0.05) }
        let endlessQuotaEnemies = endless.snapshot.targets.filter {
            if case .enemy = $0.kind { $0.waveRole == .quota } else { false }
        }
        #expect(endlessQuotaEnemies.count == 2)
    }

    @Test func elapsedTimeCannotCompleteAQuotaWave() {
        let level = GameContent.level(1)
        let simulation = GameSimulation(
            level: level,
            progress: .newPlayer,
            assistMode: false,
            seed: 101
        )
        simulation.setCampaignWaveForTesting(
            1,
            elapsed: level.referenceWaveDuration * 10
        )

        let events = simulation.update(delta: 0.01)

        #expect(simulation.snapshot.wave == 1)
        #expect(simulation.snapshot.waveDefeats == 0)
        #expect(simulation.snapshot.remainingEnemies == simulation.snapshot.waveEnemyQuota)
        #expect(!events.contains(.waveCompleted(1)))
    }

    @Test func reachingTheEnemyQuotaCompletesTheWave() {
        let simulation = GameSimulation(
            level: GameContent.level(1),
            progress: .newPlayer,
            assistMode: false,
            seed: 102
        )
        simulation.setWaveDefeatsForTesting(simulation.snapshot.waveEnemyQuota)

        let events = simulation.update(delta: 0.01)

        #expect(events.contains(.waveCompleted(1)))
        #expect(events.contains(.checkpoint(1)))
        #expect(simulation.snapshot.wave == 2)
        #expect(simulation.snapshot.waveDefeats == 0)
    }

    @Test func escapedQuotaEnemiesDamageStaminaButDoNotLowerTheObjective() {
        let simulation = GameSimulation(
            level: GameContent.level(1),
            progress: .newPlayer,
            assistMode: false,
            seed: 103
        )
        let initialQuota = simulation.snapshot.waveEnemyQuota
        let initialStamina = simulation.snapshot.stamina
        simulation.replaceTargetsForTesting([
            TargetState(
                id: 10_001,
                kind: .enemy(.coneRunner),
                position: .init(x: 0.70, y: 0.121),
                hitPoints: 1_000,
                maximumHitPoints: 1_000,
                phase: 0,
                waveRole: .quota
            )
        ])

        _ = simulation.update(delta: 0.05)

        #expect(simulation.snapshot.stamina < initialStamina)
        #expect(simulation.snapshot.waveDefeats == 0)
        #expect(simulation.snapshot.remainingEnemies == initialQuota)
        #expect(!simulation.snapshot.targets.contains { $0.id == 10_001 })

        for _ in 0..<40 where !simulation.snapshot.targets.contains(where: {
            if case .enemy = $0.kind { $0.waveRole == .quota } else { false }
        }) {
            _ = simulation.update(delta: 0.05)
        }

        #expect(simulation.snapshot.targets.contains {
            if case .enemy = $0.kind { $0.waveRole == .quota } else { false }
        })
        #expect(simulation.snapshot.remainingEnemies == initialQuota)
    }

    @Test func reinforcementDefeatsDoNotReduceTheWaveObjective() {
        let simulation = GameSimulation(
            level: GameContent.level(8),
            progress: .newPlayer,
            assistMode: false,
            seed: 104
        )
        simulation.replaceTargetsForTesting([
            TargetState(
                id: 10_002,
                kind: .enemy(.tackleBot),
                position: .init(x: 0, y: 0.18),
                hitPoints: 1,
                maximumHitPoints: 1,
                phase: 0,
                waveRole: .reinforcement
            )
        ])
        simulation.spawnFriendlyProjectileForTesting(pierce: 0)

        _ = simulation.update(delta: 0.05)

        #expect(simulation.snapshot.targetsDefeated == 1)
        #expect(simulation.snapshot.waveDefeats == 0)
        #expect(simulation.snapshot.remainingEnemies == simulation.snapshot.waveEnemyQuota)
    }

    @Test func endlessQuotasGrowAndEveryFifthWaveIsBossOnly() {
        #expect(EndlessRules.enemyQuota(wave: 1) == 18)
        #expect(EndlessRules.enemyQuota(wave: 11) == 30)
        #expect(EndlessRules.enemyQuota(wave: 21) == 42)
        #expect(EndlessRules.enemyQuota(wave: 31) == 54)
        #expect(EndlessRules.enemyQuota(wave: 100) > EndlessRules.enemyQuota(wave: 10))
        #expect(!EndlessRules.isBossWave(4))
        #expect(EndlessRules.isBossWave(5))
        #expect(EndlessRules.isBossWave(10))

        let simulation = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: false,
            seed: 105
        )
        simulation.setEndlessWaveForTesting(5)
        #expect(simulation.snapshot.isBossWave)
        #expect(simulation.snapshot.waveEnemyQuota == 1)
        #expect(simulation.snapshot.remainingEnemies == 1)

        _ = simulation.update(delta: 0.01)

        let enemies = simulation.snapshot.targets.filter {
            if case .enemy = $0.kind { true } else { false }
        }
        #expect(enemies.count == 1)
        #expect(enemies.first?.waveRole == .boss)
        #expect(enemies.first?.bossTier == .megaBoss)
    }

    @Test func endlessWorldCatalogAdvancesEveryTenWavesAndLoops() {
        #expect(EndlessRules.world(for: 1) == .earth)
        #expect(EndlessRules.world(for: 10) == .earth)
        #expect(EndlessRules.world(for: 11) == .moon)
        #expect(EndlessRules.world(for: 20) == .moon)
        #expect(EndlessRules.world(for: 21) == .mars)
        #expect(EndlessRules.world(for: 30) == .mars)
        #expect(EndlessRules.world(for: 31) == .earth)
        #expect(EndlessRules.world(for: 41) == .moon)
        #expect(EndlessRules.waveInWorld(for: 31) == 1)
        #expect(EndlessRules.chapterIndex(for: 31) == 3)
        #expect(EndlessRules.worldTransition(after: 9) == nil)
        #expect(EndlessRules.worldTransition(after: 10)?.from == .earth)
        #expect(EndlessRules.worldTransition(after: 10)?.to == .moon)
        #expect(EndlessRules.worldTransition(after: 30)?.to == .earth)
    }

    @Test func endlessWorldTransitionChangesTheSnapshotAndEmitsOneHandoff() {
        let simulation = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: false,
            seed: 106
        )
        simulation.setEndlessWaveForTesting(10)
        simulation.replaceTargetsForTesting([
            TargetState(
                id: 10_010,
                kind: .enemy(.titanKeeper),
                position: .init(x: 0, y: 0.18),
                hitPoints: 1,
                maximumHitPoints: 1,
                phase: 0,
                bossTier: .megaBoss,
                waveRole: .boss
            )
        ])
        simulation.spawnFriendlyProjectileForTesting(pierce: 0)

        let events = simulation.update(delta: 0.05)

        #expect(events.contains(.waveCompleted(10)))
        #expect(events.contains(.worldTransitioned(from: .earth, to: .moon)))
        #expect(!events.contains(.checkpoint(10)))
        #expect(simulation.snapshot.wave == 11)
        #expect(simulation.snapshot.world == .moon)
        #expect(simulation.snapshot.waveEnemyQuota == EndlessRules.enemyQuota(wave: 11))
        #expect(!simulation.snapshot.isBossWave)
    }

    @Test func endlessEnemyFamiliesFollowTheCurrentWorld() {
        let simulation = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: false,
            seed: 107
        )
        simulation.setEndlessWaveForTesting(11)
        for _ in 0..<30 { _ = simulation.update(delta: 0.05) }

        let moonEnemies = simulation.snapshot.targets.compactMap { target -> EnemyKind? in
            if case .enemy(let kind) = target.kind { kind } else { nil }
        }
        #expect(simulation.snapshot.world == .moon)
        #expect(!moonEnemies.isEmpty)
        #expect(moonEnemies.allSatisfy { [.regolithRunner].contains($0) })

        simulation.replaceTargetsForTesting([])
        simulation.setEndlessWaveForTesting(21)
        for _ in 0..<30 { _ = simulation.update(delta: 0.05) }

        let marsEnemies = simulation.snapshot.targets.compactMap { target -> EnemyKind? in
            if case .enemy(let kind) = target.kind { kind } else { nil }
        }
        #expect(simulation.snapshot.world == .mars)
        #expect(!marsEnemies.isEmpty)
        #expect(marsEnemies.allSatisfy { [.dustSprite].contains($0) })
    }

    @Test func worldBossesScheduleDistinctTelegraphedSignatureAttacks() {
        let fixtures: [(level: Int, kind: BossAttackKind, initialHazards: Int)] = [
            (10, .orbitalLaser, 1),
            (20, .eclipseLane, 2),
            (30, .meteorStrike, 1)
        ]

        for fixture in fixtures {
            let level = GameContent.level(fixture.level)
            let simulation = GameSimulation(
                level: level,
                progress: .newPlayer,
                assistMode: false,
                seed: UInt64(200 + fixture.level)
            )
            simulation.setCampaignWaveForTesting(level.waveCount)
            simulation.forceBossSignatureAttackForTesting()

            let events = simulation.update(delta: 0.05)

            #expect(events.contains { event in
                if case .bossAttackTelegraphed(let kind) = event {
                    return kind == fixture.kind
                }
                return false
            })
            #expect(simulation.snapshot.bossHazards.count == fixture.initialHazards)
            #expect(simulation.snapshot.bossHazards.allSatisfy { $0.kind == fixture.kind })

            if fixture.kind == .eclipseLane {
                let lanePositions = simulation.snapshot.bossHazards.map(\.position.x).sorted()
                #expect(lanePositions.count == 2)
                #expect(Set(lanePositions.map { Int(($0 * 100).rounded()) }).count == 2)
            }

            if fixture.kind == .meteorStrike {
                for _ in 0..<20 { _ = simulation.update(delta: 0.05) }
                #expect(simulation.snapshot.bossHazards.count == 3)
            }
        }
    }

    @Test func bossHazardsDamageAPlayerAtMostOncePerMarker() {
        var progress = PlayerProgress.newPlayer
        progress.setRank(20, for: .conditioning)
        let level = GameContent.level(10)
        let simulation = GameSimulation(
            level: level,
            progress: progress,
            assistMode: false,
            seed: 106
        )
        simulation.setCampaignWaveForTesting(level.waveCount)
        simulation.forceBossSignatureAttackForTesting()
        _ = simulation.update(delta: 0.05)
        let hazardID = simulation.snapshot.bossHazards.first?.id
        var sawActivation = false

        for _ in 0..<40 where simulation.snapshot.bossHazards
            .first(where: { $0.id == hazardID })?.hasDamagedPlayer != true {
            let events = simulation.update(delta: 0.05)
            sawActivation = sawActivation || events.contains {
                if case .bossAttackActivated(.orbitalLaser, _) = $0 { true } else { false }
            }
        }

        #expect(sawActivation)
        #expect(simulation.snapshot.bossHazards
            .first(where: { $0.id == hazardID })?.hasDamagedPlayer == true)
        let staminaAfterHit = simulation.snapshot.stamina
        for _ in 0..<5 { _ = simulation.update(delta: 0.05) }
        #expect(simulation.snapshot.stamina == staminaAfterHit)
    }

    @Test func bossReinforcementsArriveInSeparatedPhasePulsesAndNeverCount() {
        let level = GameContent.level(10)
        let simulation = GameSimulation(
            level: level,
            progress: .newPlayer,
            assistMode: false,
            seed: 107
        )
        simulation.setCampaignWaveForTesting(level.waveCount)
        _ = simulation.update(delta: 0.01)
        guard var boss = simulation.snapshot.targets.first(where: { $0.waveRole == .boss }) else {
            #expect(Bool(false), "Expected the world boss to spawn immediately")
            return
        }
        boss.maximumHitPoints = 1_000_000_000
        // A high-damage build can cross both markers in one simulation frame.
        // Both authored pulses must still be queued.
        boss.hitPoints = 300_000_000
        boss.freezeRemaining = 30
        simulation.replaceTargetsForTesting([boss])

        _ = simulation.update(delta: 0.01)
        _ = simulation.update(delta: 0.01)

        let firstPulse = simulation.snapshot.targets.filter { $0.waveRole == .reinforcement }
        #expect(firstPulse.count == CampaignBalance.reinforcementPulseSize(levelNumber: level.number))
        #expect(simulation.snapshot.waveDefeats == 0)
        #expect(simulation.snapshot.remainingEnemies == 1)

        guard let phaseThreeBoss = simulation.snapshot.targets.first(where: { $0.waveRole == .boss }) else {
            #expect(Bool(false), "Expected the boss to remain active")
            return
        }
        simulation.replaceTargetsForTesting([phaseThreeBoss])
        _ = simulation.update(delta: 0.01)

        for _ in 0..<59 { _ = simulation.update(delta: 0.05) }
        #expect(!simulation.snapshot.targets.contains { $0.waveRole == .reinforcement })

        _ = simulation.update(delta: 0.05)
        #expect(simulation.snapshot.targets.contains { $0.waveRole == .reinforcement })
        #expect(simulation.snapshot.remainingEnemies == 1)
    }

    @Test func bossWavesOfferPowerUpsAfterSevenSecondsThenSixteenSecondIntervals() {
        let level = GameContent.level(8)
        let simulation = GameSimulation(
            level: level,
            progress: .newPlayer,
            assistMode: false,
            seed: 108
        )
        simulation.setCampaignWaveForTesting(level.waveCount)
        _ = simulation.update(delta: 0.01)
        guard var boss = simulation.snapshot.targets.first(where: { $0.waveRole == .boss }) else {
            #expect(Bool(false), "Expected the wave boss to spawn immediately")
            return
        }
        boss.maximumHitPoints = 1_000_000_000
        boss.hitPoints = 1_000_000_000
        boss.freezeRemaining = 40
        simulation.replaceTargetsForTesting([boss])

        for _ in 0..<139 { _ = simulation.update(delta: 0.05) }
        #expect(!simulation.snapshot.targets.contains {
            if case .powerUp = $0.kind { true } else { false }
        })

        _ = simulation.update(delta: 0.05)
        #expect(simulation.snapshot.targets.contains {
            if case .powerUp = $0.kind { true } else { false }
        })

        guard let currentBoss = simulation.snapshot.targets.first(where: { $0.waveRole == .boss }) else {
            #expect(Bool(false), "Expected the boss to remain active")
            return
        }
        simulation.replaceTargetsForTesting([currentBoss])

        for _ in 0..<319 { _ = simulation.update(delta: 0.05) }
        #expect(!simulation.snapshot.targets.contains {
            if case .powerUp = $0.kind { true } else { false }
        })

        for _ in 0..<2 { _ = simulation.update(delta: 0.05) }
        #expect(simulation.snapshot.targets.contains {
            if case .powerUp = $0.kind { true } else { false }
        })
    }

    @Test func moonCadenceSchedulesTwoHarmfulDebrisStrikesWithoutHUDState() {
        var progress = PlayerProgress.newPlayer
        progress.setRank(100, for: .conditioning)
        let simulation = GameSimulation(
            level: GameContent.level(11),
            progress: progress,
            assistMode: true,
            seed: 17
        )
        var activationEvents: [SimulationEvent] = []
        for _ in 0..<205 {
            activationEvents.append(contentsOf: simulation.update(delta: 0.05))
            simulation.replaceTargetsForTesting(
                simulation.snapshot.targets.filter {
                    if case .enemy = $0.kind { false } else { true }
                }
            )
        }

        #expect(activationEvents.count {
            if case .worldEffectActivated(.lunarCycle, _) = $0 { true } else { false }
        } == 1)
        #expect(simulation.snapshot.bossHazards.contains { $0.kind == .lunarDebris })

        for _ in 0..<60 {
            activationEvents.append(contentsOf: simulation.update(delta: 0.05))
            simulation.replaceTargetsForTesting(
                simulation.snapshot.targets.filter {
                    if case .enemy = $0.kind { false } else { true }
                }
            )
        }
        #expect(activationEvents.count {
            if case .worldEffectActivated(.lunarCycle, _) = $0 { true } else { false }
        } == 2)
    }

    @Test func lunarDebrisTelegraphsThenDamagesItsLaneOnce() {
        var progress = PlayerProgress.newPlayer
        progress.setRank(100, for: .conditioning)
        progress.setRank(20, for: .footwork)
        let simulation = GameSimulation(
            level: GameContent.level(11),
            progress: progress,
            assistMode: false,
            seed: 19
        )

        for _ in 0..<205 {
            _ = simulation.update(delta: 0.05)
            simulation.replaceTargetsForTesting(
                simulation.snapshot.targets.filter {
                    if case .enemy = $0.kind { false } else { true }
                }
            )
        }
        guard let debris = simulation.snapshot.bossHazards.first(where: {
            $0.kind == .lunarDebris
        }) else {
            Issue.record("Expected lunar debris at the ten-second cadence")
            return
        }

        simulation.setPlayerTarget(x: debris.position.x)
        let startingStamina = simulation.snapshot.stamina
        var impacts = 0
        for _ in 0..<40 {
            let events = simulation.update(delta: 0.05)
            impacts += events.count {
                if case .worldEffectImpact(.lunarCycle, _) = $0 { true } else { false }
            }
        }

        #expect(impacts == 1)
        #expect(simulation.snapshot.stamina < startingStamina)
    }

    @Test func moonNeverSlowsHostileProjectiles() {
        let moon = GameSimulation(
            level: GameContent.level(11),
            progress: .newPlayer,
            assistMode: false,
            seed: 21
        )
        moon.spawnHostileProjectileForTesting(x: 0.8, y: 0.60)
        _ = moon.update(delta: 0.05)

        #expect(abs((moon.snapshot.projectiles.first?.position.y ?? 0) - 0.581) < 0.0001)
    }

    @Test func marsDefeatsExposeAVolatileCore() {
        var progress = PlayerProgress.newPlayer
        for track in UpgradeTrack.allCases {
            progress.setRank(8, for: track)
        }
        let simulation = GameSimulation(
            level: GameContent.level(21),
            progress: progress,
            assistMode: true,
            seed: 23
        )
        var exposedCore = false
        var activationEvents: [SimulationEvent] = []

        for _ in 0..<2_400 where !exposedCore {
            if let target = simulation.snapshot.targets.first(where: {
                if case .enemy = $0.kind { true } else { false }
            }) {
                simulation.setPlayerTarget(x: target.position.x)
            }
            activationEvents.append(contentsOf: simulation.update(delta: 0.05))
            exposedCore = simulation.snapshot.targets.contains {
                if case .volatileCore = $0.kind { true } else { false }
            }
        }

        #expect(exposedCore)
        #expect(activationEvents.contains {
            if case .worldEffectActivated(.volatileCores, _) = $0 { true } else { false }
        })
    }

    @Test func shootingAVolatileCoreOnlyNeutralizesTheHazard() {
        let simulation = GameSimulation(
            level: GameContent.level(21),
            progress: .newPlayer,
            assistMode: false,
            seed: 25
        )
        simulation.replaceTargetsForTesting([
            TargetState(
                id: 9_201,
                kind: .volatileCore,
                position: .init(x: 0, y: 0.21),
                hitPoints: 1,
                maximumHitPoints: 1,
                phase: 0
            ),
            TargetState(
                id: 9_202,
                kind: .enemy(.dustSprite),
                position: .init(x: 0.08, y: 0.22),
                hitPoints: 25,
                maximumHitPoints: 25,
                phase: 0
            )
        ])
        simulation.spawnFriendlyProjectileForTesting(pierce: 0)
        let events = simulation.update(delta: 0.05)

        #expect(events.contains {
            if case .volatileCoreNeutralized = $0 { true } else { false }
        })
        #expect(!simulation.snapshot.targets.contains {
            if case .volatileCore = $0.kind { true } else { false }
        })
        #expect(simulation.snapshot.targets.first {
            if case .enemy = $0.kind { true } else { false }
        }?.hitPoints == 25)
        #expect(simulation.snapshot.tokens == 0)
        #expect(simulation.snapshot.targetsDefeated == 0)
        #expect(simulation.snapshot.characterAbilityCharge == 0)
    }

    @Test func ignoredVolatileCoreDetonatesAgainstThePlayer() {
        let simulation = GameSimulation(
            level: GameContent.level(21),
            progress: .newPlayer,
            assistMode: false,
            seed: 27
        )
        simulation.setPlayerTarget(x: -0.8)
        simulation.replaceTargetsForTesting([
            TargetState(
                id: 9_301,
                kind: .volatileCore,
                position: .init(x: 0.8, y: 0.50),
                hitPoints: 1,
                maximumHitPoints: 1,
                phase: 0
            )
        ])
        let startingStamina = simulation.snapshot.stamina
        var detonationEvents: [SimulationEvent] = []
        for _ in 0..<56 {
            detonationEvents.append(contentsOf: simulation.update(delta: 0.05))
        }

        #expect(detonationEvents.count {
            if case .volatileCoreDetonated = $0 { true } else { false }
        } == 1)
        #expect(simulation.snapshot.stamina < startingStamina)
        #expect(simulation.snapshot.tokens == 0)
    }

    @Test func campaignDifficultyKeepsEscalatingFromEarthThroughMars() {
        let openingEarth = CampaignBalance.wave(1, for: GameContent.level(1))
        let earthFinale = CampaignBalance.wave(1, for: GameContent.level(10))
        let openingMoon = CampaignBalance.wave(1, for: GameContent.level(11))
        let moonFinale = CampaignBalance.wave(1, for: GameContent.level(20))
        let openingMars = CampaignBalance.wave(1, for: GameContent.level(21))
        let marsFinale = CampaignBalance.wave(1, for: GameContent.level(30))
        #expect(earthFinale.healthMultiplier > openingEarth.healthMultiplier)
        #expect(openingMoon.healthMultiplier > earthFinale.healthMultiplier)
        #expect(moonFinale.healthMultiplier > openingMoon.healthMultiplier)
        #expect(openingMars.healthMultiplier > moonFinale.healthMultiplier)
        #expect(marsFinale.healthMultiplier > openingMars.healthMultiplier)
        #expect(openingMoon.healthMultiplier / earthFinale.healthMultiplier > 1.14)
        #expect(openingMoon.damageMultiplier / earthFinale.damageMultiplier > 1.12)
        #expect(openingMoon.speedMultiplier / earthFinale.speedMultiplier > 1.08)
        #expect(openingMoon.spawnInterval < earthFinale.spawnInterval)
        #expect(openingMars.healthMultiplier / moonFinale.healthMultiplier > 1.14)
        #expect(openingMars.damageMultiplier / moonFinale.damageMultiplier > 1.09)
        #expect(openingMars.speedMultiplier / moonFinale.speedMultiplier > 1.08)
        #expect(openingMars.spawnInterval < moonFinale.spawnInterval)
    }

    @Test func campaignBossesAppearOnlyOnTheFinalWave() {
        for level in GameContent.levels {
            for waveNumber in 1...level.waveCount {
                let wave = CampaignBalance.wave(waveNumber, for: level)
                if waveNumber == level.waveCount {
                    if level.hasBoss {
                        #expect(wave.bossTier == .megaBoss)
                        #expect(wave.boss == GameContent.world(level.world).boss)
                    } else {
                        #expect(wave.bossTier == .miniBoss)
                        #expect(wave.boss.map(level.enemies.contains) == true)
                    }
                } else {
                    #expect(wave.bossTier == nil)
                    #expect(wave.boss == nil)
                }
            }
        }
    }

    @Test func campaignSpawningCannotPublishABossBeforeTheFinalWave() {
        let level = GameContent.level(8)
        let openingWave = GameSimulation(
            level: level,
            progress: .newPlayer,
            assistMode: true,
            seed: 88
        )
        openingWave.setCampaignWaveForTesting(1)

        _ = openingWave.update(delta: 0.05)

        #expect(openingWave.snapshot.targets.allSatisfy { $0.bossTier == .standard })

        let finalWave = GameSimulation(
            level: level,
            progress: .newPlayer,
            assistMode: true,
            seed: 88
        )
        finalWave.setCampaignWaveForTesting(level.waveCount)

        _ = finalWave.update(delta: 0.05)

        let boss = finalWave.snapshot.targets.first { $0.bossTier == .miniBoss }
        #expect(boss != nil)
        #expect(boss?.position.y == CampaignBalance.bossArenaY)
    }

    @Test func defeatingCampaignBossWinsImmediatelyWithEnemiesStillOnScreen() {
        let level = GameContent.level(8)
        let simulation = GameSimulation(
            level: level,
            progress: .newPlayer,
            assistMode: true,
            seed: 89
        )
        simulation.setCampaignWaveForTesting(level.waveCount)
        simulation.replaceTargetsForTesting([
            TargetState(
                id: 9_700,
                kind: .enemy(.ballLauncher),
                position: .init(x: 0, y: 0.21),
                hitPoints: 1,
                maximumHitPoints: 1,
                phase: 0,
                bossTier: .miniBoss
            ),
            TargetState(
                id: 9_701,
                kind: .enemy(.tackleBot),
                position: .init(x: 0.72, y: 0.62),
                hitPoints: 100,
                maximumHitPoints: 100,
                phase: 0
            )
        ])
        simulation.spawnFriendlyProjectileForTesting(pierce: 0)

        let events = simulation.update(delta: 0.05)

        #expect(events.contains(.waveCompleted(level.waveCount)))
        #expect(events.contains(.finished(true)))
        #expect(simulation.snapshot.bossesDefeated == 1)
        #expect(simulation.snapshot.targets.isEmpty)
        #expect(simulation.update(delta: 0.05).isEmpty)
    }

    @Test func endlessDifficultyContinuesGrowingAtHighWaves() {
        #expect(EndlessRules.healthMultiplier(wave: 100) > EndlessRules.healthMultiplier(wave: 10))
        #expect(EndlessRules.healthMultiplier(wave: 1_000) > EndlessRules.healthMultiplier(wave: 100))
        #expect(EndlessRules.damageMultiplier(wave: 1_000) > EndlessRules.damageMultiplier(wave: 100))
        #expect(EndlessRules.speedMultiplier(wave: 1_000) > EndlessRules.speedMultiplier(wave: 100))
        #expect(EndlessRules.spawnInterval(wave: 10_000) == 0.32)
        #expect(EndlessRules.packSize(wave: 10_000) == 4)
    }

    @Test func everyCharacterHasRosterAndGameplayPresentation() {
        for id in CharacterID.allCases {
            let roster = GameNodeFactory.player(character: id, presentation: .roster)
            let gameplay = GameNodeFactory.player(character: id)
            #expect(roster.childNode(withName: "body")?.childNode(withName: "character-sprite") != nil)
            #expect(gameplay.childNode(withName: "body")?.childNode(withName: "character-sprite") != nil)
            #expect(roster.calculateAccumulatedFrame().height > gameplay.calculateAccumulatedFrame().height)
        }
    }

    @Test func everyCharacterAnimatesAnIndependentKickingLeg() {
        for id in CharacterID.allCases {
            let player = GameNodeFactory.player(character: id)
            let body = player.childNode(withName: "body")
            let kickingLeg = body?.childNode(withName: "kicking-leg")
                ?? body?.childNode(withName: "slot-legs")?.childNode(withName: "kicking-leg")

            GameNodeFactory.animateKick(on: player, reducedMotion: false)

            #expect(kickingLeg?.action(forKey: "kick-leg") != nil)
            #expect(body?.action(forKey: "kick-body") != nil)
        }
    }

    @Test func repeatedKicksRetriggerACompleteLegSequenceForEveryCharacter() {
        for id in CharacterID.allCases {
            let player = GameNodeFactory.player(character: id)
            let body = player.childNode(withName: "body")
            let kickingLeg = body?.childNode(withName: "kicking-leg")
                ?? body?.childNode(withName: "slot-legs")?.childNode(withName: "kicking-leg")

            GameNodeFactory.animateKick(on: player, reducedMotion: false)
            GameNodeFactory.animateKick(on: player, reducedMotion: false)

            #expect(kickingLeg?.action(forKey: "kick-leg") != nil)
        }
    }

    @Test func eachCharacterAbilityConsumesFullCharge() {
        for id in CharacterID.allCases {
            var progress = PlayerProgress.newPlayer
            progress.selectedCharacter = id
            progress.unlockedCharacters.insert(id)
            let simulation = GameSimulation(level: GameContent.level(1), progress: progress, assistMode: false, seed: 8)
            simulation.fullyChargeCharacterAbilityForTesting()
            let events = simulation.activateCharacterAbility()
            #expect(events.contains(.characterAbilityActivated(CharacterCatalog.character(id).ability)))
            #expect(simulation.snapshot.characterAbilityCharge == 0)
            #expect(!simulation.snapshot.characterAbilityReady)
        }
    }

    @Test func damagingCharacterAbilitiesDoNotRechargeThemselves() {
        let cases: [(CharacterID, TargetState, Int)] = [
            (
                .ace,
                TargetState(
                    id: 9_101,
                    kind: .enemy(.coneRunner),
                    position: .init(x: -0.07, y: 0.18),
                    hitPoints: 1,
                    maximumHitPoints: 1,
                    phase: 0
                ),
                1
            ),
            (
                .nova,
                TargetState(
                    id: 9_102,
                    kind: .enemy(.coneRunner),
                    position: .init(x: 0.22, y: 0.55),
                    hitPoints: 1,
                    maximumHitPoints: 1,
                    phase: 0
                ),
                24
            ),
            (
                .aegis,
                TargetState(
                    id: 9_103,
                    kind: .enemy(.coneRunner),
                    position: .init(x: 0, y: 0.20),
                    hitPoints: 1,
                    maximumHitPoints: 1,
                    phase: 0
                ),
                2
            )
        ]

        for (characterID, target, updateCount) in cases {
            var progress = PlayerProgress.newPlayer
            progress.selectedCharacter = characterID
            progress.unlockedCharacters.insert(characterID)
            let simulation = GameSimulation(
                level: GameContent.level(1),
                progress: progress,
                assistMode: false,
                seed: 90
            )
            simulation.replaceTargetsForTesting([target])
            simulation.fullyChargeCharacterAbilityForTesting()
            _ = simulation.activateCharacterAbility()

            for _ in 0..<updateCount {
                _ = simulation.update(delta: 0.05)
            }

            #expect(simulation.snapshot.targetsDefeated == 1)
            #expect(simulation.snapshot.characterAbilityCharge == 0)
            #expect(!simulation.snapshot.characterAbilityReady)
        }
    }

    @Test func characterAbilityCanNeutralizeCoreWithoutCoreRewards() {
        var progress = PlayerProgress.newPlayer
        progress.selectedCharacter = .aegis
        progress.unlockedCharacters.insert(.aegis)
        let simulation = GameSimulation(
            level: GameContent.level(21),
            progress: progress,
            assistMode: false,
            seed: 91
        )
        simulation.replaceTargetsForTesting([
            TargetState(
                id: 9_201,
                kind: .volatileCore,
                position: .init(x: 0, y: 0.24),
                hitPoints: 1,
                maximumHitPoints: 1,
                phase: 0
            )
        ])
        simulation.fullyChargeCharacterAbilityForTesting()

        var events = simulation.activateCharacterAbility()
        for _ in 0..<8 {
            events.append(contentsOf: simulation.update(delta: 0.05))
        }

        #expect(events.contains {
            if case .volatileCoreNeutralized = $0 { true } else { false }
        })
        #expect(simulation.snapshot.targetsDefeated == 0)
        #expect(simulation.snapshot.tokens == 0)
        #expect(simulation.snapshot.characterAbilityCharge == 0)
        #expect(!simulation.snapshot.characterAbilityReady)
    }

    @Test func aceAbilityLaunchesRealProjectilesWithoutInstantFieldDamage() {
        var progress = PlayerProgress.newPlayer
        progress.selectedCharacter = .ace
        let simulation = GameSimulation(level: GameContent.level(1), progress: progress, assistMode: false, seed: 81)
        let robot = TargetState(
            id: 9_001,
            kind: .enemy(.coneRunner),
            position: .init(x: 0.72, y: 0.72),
            hitPoints: 500,
            maximumHitPoints: 500,
            phase: 0
        )
        simulation.replaceTargetsForTesting([robot])
        simulation.fullyChargeCharacterAbilityForTesting()

        _ = simulation.activateCharacterAbility()

        #expect(simulation.snapshot.targets.first?.hitPoints == 500)
        #expect(simulation.snapshot.projectiles.count == 3)
        #expect(simulation.snapshot.projectiles.allSatisfy {
            $0.characterProjectile == .pinballBlitz && $0.remainingLifetime.isFinite
        })
    }

    @Test func acePinballOnlyDamagesARobotAfterCollisionAndSurvivesTheHit() {
        var progress = PlayerProgress.newPlayer
        progress.selectedCharacter = .ace
        let simulation = GameSimulation(level: GameContent.level(1), progress: progress, assistMode: false, seed: 82)
        let robot = TargetState(
            id: 9_002,
            kind: .enemy(.coneRunner),
            position: .init(x: -0.07, y: 0.18),
            hitPoints: 500,
            maximumHitPoints: 500,
            phase: 0
        )
        simulation.replaceTargetsForTesting([robot])
        simulation.fullyChargeCharacterAbilityForTesting()
        _ = simulation.activateCharacterAbility()

        let events = simulation.update(delta: 0.01)

        #expect((simulation.snapshot.targets.first?.hitPoints ?? 500) < 500)
        let impact = events.compactMap { event -> ImpactEvent? in
            if case .impact(let impact) = event { return impact }
            return nil
        }.first
        #expect(impact?.targetID == robot.id)
        #expect(impact?.delivery == .direct)
        #expect(impact?.isDefeating == false)
        #expect(abs(hypot(impact?.impulse.x ?? 0, impact?.impulse.y ?? 0) - 1) < 0.001)
        #expect(simulation.snapshot.projectiles.count == 3)
        #expect(simulation.snapshot.projectiles.contains {
            $0.characterProjectile == .pinballBlitz && $0.contactedTargetIDs.contains(robot.id)
        })
    }

    @Test func defeatingImpactCarriesTheTargetAndOutcomeNeededByRendering() {
        var progress = PlayerProgress.newPlayer
        progress.selectedCharacter = .ace
        let simulation = GameSimulation(
            level: GameContent.level(1),
            progress: progress,
            assistMode: false,
            seed: 821
        )
        let robot = TargetState(
            id: 9_021,
            kind: .enemy(.coneRunner),
            position: .init(x: -0.07, y: 0.18),
            hitPoints: 1,
            maximumHitPoints: 1,
            phase: 0
        )
        simulation.replaceTargetsForTesting([robot])
        simulation.fullyChargeCharacterAbilityForTesting()
        _ = simulation.activateCharacterAbility()

        let events = simulation.update(delta: 0.01)
        let impact = events.compactMap { event -> ImpactEvent? in
            if case .impact(let impact) = event { return impact }
            return nil
        }.first

        #expect(impact?.targetID == robot.id)
        #expect(impact?.delivery == .direct)
        #expect(impact?.isDefeating == true)
        #expect(abs((impact?.position.x ?? 0) - robot.position.x) < 0.001)
        #expect(abs((impact?.position.y ?? 0) - robot.position.y) < 0.001)
    }

    @Test func acePinballsRicochetOffThePlayableTrack() {
        var progress = PlayerProgress.newPlayer
        progress.selectedCharacter = .ace
        let simulation = GameSimulation(level: GameContent.level(1), progress: progress, assistMode: false, seed: 83)
        simulation.fullyChargeCharacterAbilityForTesting()
        _ = simulation.activateCharacterAbility()

        var sawRicochet = false
        for _ in 0..<12 {
            let events = simulation.update(delta: 0.05)
            sawRicochet = sawRicochet || events.contains { event in
                if case .characterProjectileRicochet = event { return true }
                return false
            }
        }

        #expect(sawRicochet)
        #expect(simulation.snapshot.projectiles.contains {
            $0.characterProjectile == .pinballBlitz && abs($0.position.x) <= 0.88
        })
    }

    @Test func timeBreakStillFreezesAndEmitsTargetedVisuals() {
        var progress = PlayerProgress.newPlayer
        progress.selectedCharacter = .volt
        progress.unlockedCharacters.insert(.volt)
        let simulation = GameSimulation(level: GameContent.level(1), progress: progress, assistMode: false, seed: 84)
        let robot = TargetState(
            id: 9_003,
            kind: .enemy(.coneRunner),
            position: .init(x: 0.22, y: 0.55),
            hitPoints: 500,
            maximumHitPoints: 500,
            phase: 0
        )
        simulation.replaceTargetsForTesting([robot])
        simulation.fullyChargeCharacterAbilityForTesting()

        let events = simulation.activateCharacterAbility()

        #expect(events.contains(.characterAbilityTargets(.timeBreak, [robot.position])))
        #expect((simulation.snapshot.targets.first?.freezeRemaining ?? 0) >= 5.5)
    }

    @Test func meteorVolleyUsesVisibleFlightBeforeImpactDamage() {
        var progress = PlayerProgress.newPlayer
        progress.selectedCharacter = .nova
        progress.unlockedCharacters.insert(.nova)
        let simulation = GameSimulation(level: GameContent.level(1), progress: progress, assistMode: false, seed: 85)
        let robot = TargetState(
            id: 9_004,
            kind: .enemy(.coneRunner),
            position: .init(x: 0.22, y: 0.55),
            hitPoints: 500,
            maximumHitPoints: 500,
            phase: 0
        )
        simulation.replaceTargetsForTesting([robot])
        simulation.fullyChargeCharacterAbilityForTesting()

        _ = simulation.activateCharacterAbility()

        #expect(simulation.snapshot.targets.first?.hitPoints == 500)
        #expect(simulation.snapshot.characterAttacks.count == 1)
        #expect(simulation.snapshot.characterAttacks.first?.kind == .meteor)

        var sawImpact = false
        for _ in 0..<20 {
            let events = simulation.update(delta: 0.05)
            sawImpact = sawImpact || events.contains {
                if case .characterMeteorImpact = $0 { return true }
                return false
            }
        }
        #expect(sawImpact)
        #expect((simulation.snapshot.targets.first?.hitPoints ?? 500) < 500)
    }

    @Test func meteorExplosionDamagesAcrossItsFullRenderedBlastWidth() {
        var progress = PlayerProgress.newPlayer
        progress.selectedCharacter = .nova
        progress.unlockedCharacters.insert(.nova)
        let simulation = GameSimulation(level: GameContent.level(1), progress: progress, assistMode: false, seed: 851)
        let directTarget = TargetState(
            id: 9_041,
            kind: .enemy(.coneRunner),
            position: .init(x: 0.22, y: 0.55),
            hitPoints: 500,
            maximumHitPoints: 500,
            phase: 0
        )
        let collateralTarget = TargetState(
            id: 9_042,
            kind: .enemy(.coneRunner),
            position: .init(x: -0.50, y: 0.55),
            hitPoints: 500,
            maximumHitPoints: 500,
            phase: 0
        )
        simulation.replaceTargetsForTesting([directTarget, collateralTarget])
        simulation.fullyChargeCharacterAbilityForTesting()
        _ = simulation.activateCharacterAbility()

        var impacts: [ImpactEvent] = []
        for _ in 0..<19 {
            impacts.append(contentsOf: simulation.update(delta: 0.05).compactMap { event in
                if case .impact(let impact) = event { return impact }
                return nil
            })
        }

        let collateralHealth = simulation.snapshot.targets
            .first(where: { $0.id == collateralTarget.id })?
            .hitPoints ?? 500
        #expect(collateralHealth < 500)
        #expect(impacts.contains {
            $0.targetID == collateralTarget.id && $0.delivery == .area
        })
    }

    @Test func shockwaveBurstsCaptureNewOriginsAndStunOnContact() {
        var progress = PlayerProgress.newPlayer
        progress.selectedCharacter = .aegis
        progress.unlockedCharacters.insert(.aegis)
        let simulation = GameSimulation(level: GameContent.level(1), progress: progress, assistMode: false, seed: 86)
        let robot = TargetState(
            id: 9_005,
            kind: .enemy(.coneRunner),
            position: .init(x: 0.18, y: 0.48),
            hitPoints: 500,
            maximumHitPoints: 500,
            phase: 0
        )
        simulation.replaceTargetsForTesting([robot])
        simulation.fullyChargeCharacterAbilityForTesting()

        let activationEvents = simulation.activateCharacterAbility()
        #expect(activationEvents.contains(.characterShockwaveBurst(.init(x: 0, y: 0.18))))
        #expect(simulation.snapshot.targets.first?.hitPoints == 500)

        simulation.setPlayerTarget(x: 0.72)
        var burstOrigins = [Vector2(x: 0, y: 0.18)]
        var sawStun = false
        for _ in 0..<30 {
            let events = simulation.update(delta: 0.05)
            for event in events {
                if case .characterShockwaveBurst(let origin) = event {
                    burstOrigins.append(origin)
                }
                if case .characterShockwaveHit = event {
                    sawStun = true
                }
            }
        }

        #expect(burstOrigins.count == 4)
        #expect(burstOrigins.dropFirst().contains { $0.x > 0.1 })
        #expect(sawStun)
        #expect((simulation.snapshot.targets.first?.hitPoints ?? 500) < 500)
    }

    @Test func pinballProjectileHasDistinctHighEnergyPresentation() {
        let node = GameNodeFactory.projectile(hostile: false)
        GameNodeFactory.configureProjectile(
            node,
            hostile: false,
            critical: true,
            temporaryAbility: nil,
            characterProjectile: .pinballBlitz
        )

        let ball = node.childNode(withName: "ball") as? SKSpriteNode
        let halo = node.childNode(withName: "ball-halo") as? SKShapeNode
        #expect(ball?.size.width == 39)
        #expect((halo?.glowWidth ?? 0) > 0)
    }

    @Test func everyEnemyHasAMotionPresentationRigMatchingItsAssetType() {
        for enemy in EnemyKind.allCases {
            let node = GameNodeFactory.target(
                TargetState(
                    id: 1,
                    kind: .enemy(enemy),
                    position: .init(x: 0, y: 0.5),
                    hitPoints: 10,
                    maximumHitPoints: 10,
                    phase: 0
                )
            )
            let rig = node.childNode(withName: "motion-body")
            let reactionRig = rig?.childNode(withName: "hit-reaction")
            #expect(rig != nil)
            #expect(reactionRig != nil)
            #expect(reactionRig?.childNode(withName: "body-sprite") != nil)
            #expect(rig?.childNode(withName: "left-leg") == nil)
            #expect(rig?.childNode(withName: "right-leg") == nil)
        }
    }

    @Test func everyFieldObjectUsesRenderedArtworkInsteadOfProceduralPlaceholders() {
        for (index, object) in FieldObjectKind.allCases.enumerated() {
            let node = GameNodeFactory.target(
                TargetState(
                    id: index,
                    kind: .fieldObject(object),
                    position: .init(x: 0, y: 0.5),
                    hitPoints: 10,
                    maximumHitPoints: 10,
                    phase: 0
                )
            )
            let rig = node.childNode(withName: "motion-body")
            let sprite = rig?.childNode(withName: "//body-sprite") as? SKSpriteNode

            #expect(rig != nil)
            #expect(sprite?.texture != nil)
            #expect(sprite?.size.width ?? 0 >= 88)
            #expect(node.childNode(withName: "health-background") != nil)
        }
    }

    @Test func enemyMotionMovesArtworkWithoutMovingGameplayRoot() {
        let target = TargetState(
            id: 1,
            kind: .enemy(.tackleBot),
            position: .init(x: 0.4, y: 0.5),
            hitPoints: 10,
            maximumHitPoints: 10,
            phase: 0
        )
        let node = GameNodeFactory.target(target)
        node.position = .init(x: 140, y: 360)
        let startingRootPosition = node.position
        let startingRigPosition = node.childNode(withName: "motion-body")?.position

        GameNodeFactory.animateTarget(on: node, kind: target.kind, phase: 0.17, reducedMotion: false)

        #expect(node.position == startingRootPosition)
        #expect(node.childNode(withName: "motion-body")?.position != startingRigPosition)
        #expect(node.childNode(withName: "health-background")?.position.y == 51)
    }

    @Test func directImpactAnimatesAnIndependentReactionRigAndFlashesTheModel() {
        let target = TargetState(
            id: 1,
            kind: .enemy(.tackleBot),
            position: .init(x: 0.4, y: 0.5),
            hitPoints: 10,
            maximumHitPoints: 10,
            phase: 0
        )
        let node = GameNodeFactory.target(target) as? TargetRenderNode
        let rootPosition = node?.position
        let motionPosition = node?.motionRig?.position

        node?.playHitReaction(
            ImpactEvent(
                targetID: target.id,
                position: target.position,
                impulse: .init(x: 0.6, y: 0.8),
                damage: 4,
                flavor: .standard,
                isCritical: false,
                isDefeating: false,
                delivery: .direct
            ),
            reducedMotion: false
        )

        #expect(node?.hitReactionRig?.action(forKey: "hit-reaction") != nil)
        #expect(node?.motionRig?.action(forKey: "hit-reaction") == nil)
        #expect(node?.position == rootPosition)
        #expect(node?.motionRig?.position == motionPosition)
        #expect(node?.bodySprite?.colorBlendFactor ?? 0 > 0.81)
        #expect(node?.childNode(withName: "health-background")?.parent === node)
    }

    @Test func damageOverTimeUsesAPulseWithoutDirectionalRecoil() {
        let target = TargetState(
            id: 2,
            kind: .enemy(.tackleBot),
            position: .init(x: 0, y: 0.5),
            hitPoints: 10,
            maximumHitPoints: 10,
            phase: 0
        )
        let node = GameNodeFactory.target(target) as? TargetRenderNode

        node?.playHitReaction(
            ImpactEvent(
                targetID: target.id,
                position: target.position,
                impulse: .init(x: 0, y: 0),
                damage: 1,
                flavor: .fire,
                isCritical: false,
                isDefeating: false,
                delivery: .damageOverTime
            ),
            reducedMotion: false
        )

        #expect(node?.hitReactionRig?.action(forKey: "hit-reaction") != nil)
        #expect(node?.hitReactionRig?.position == .zero)
        #expect(node?.hitReactionRig?.zRotation == 0)
    }

    @Test func coneWigglesWithoutGrowingHumanoidLimbs() {
        let target = TargetState(
            id: 1,
            kind: .enemy(.coneRunner),
            position: .init(x: 0, y: 0.5),
            hitPoints: 10,
            maximumHitPoints: 10,
            phase: 0
        )
        let node = GameNodeFactory.target(target)
        let rig = node.childNode(withName: "motion-body")

        GameNodeFactory.animateTarget(on: node, kind: target.kind, phase: 0.12, reducedMotion: false)

        #expect(rig?.zRotation != 0)
        #expect(rig?.childNode(withName: "//left-leg") == nil)
        #expect(rig?.childNode(withName: "//right-leg") == nil)
    }

    @Test func everyDamageableTargetUsesModelBoundStatusEffectsInsteadOfARing() {
        let kinds: [TargetState.Kind] = EnemyKind.allCases.map(TargetState.Kind.enemy)
            + FieldObjectKind.allCases.map(TargetState.Kind.fieldObject)

        for (index, kind) in kinds.enumerated() {
            let target = TargetState(
                id: index,
                kind: kind,
                position: .init(x: 0, y: 0.5),
                hitPoints: 10,
                maximumHitPoints: 10,
                phase: 0
            )
            let node = GameNodeFactory.target(target)
            #expect(node.childNode(withName: "//status-ring") == nil)
            #expect(node.childNode(withName: "//status-underlay") != nil)
            #expect(node.childNode(withName: "//status-overlay") != nil)
            #expect(node.childNode(withName: "//status-fire-front")?.children.count ?? 0 >= 8)
            #expect(node.childNode(withName: "//status-ice-crystals")?.children.count == 6)
            #expect(node.childNode(withName: "//status-reverse-trail")?.children.count == 5)
        }
    }

    @Test func frozenTargetsCoatTheModelAndHoldAStaticPose() {
        var target = TargetState(
            id: 1,
            kind: .enemy(.tackleBot),
            position: .init(x: 0, y: 0.5),
            hitPoints: 10,
            maximumHitPoints: 10,
            phase: 0.7
        )
        target.freezeRemaining = 1.4
        let node = GameNodeFactory.target(target)

        GameNodeFactory.animateTarget(
            on: node,
            kind: target.kind,
            phase: target.phase,
            reducedMotion: false,
            frozen: true
        )
        GameNodeFactory.updateStatus(on: node, target: target, reducedMotion: false)

        let rig = node.childNode(withName: "motion-body")
        let body = rig?.childNode(withName: "//body-sprite") as? SKSpriteNode
        #expect(rig?.position == .zero)
        #expect(rig?.zRotation == 0)
        #expect(body?.colorBlendFactor ?? 0 > 0.4)
        #expect(node.childNode(withName: "//status-ice-crystals")?.alpha == 1)
        #expect(node.childNode(withName: "//status-frost-glaze")?.action(forKey: "frost-shimmer") != nil)
    }

    @Test func burningTargetsRunLayeredFlamesAndResetCleanlyForPooling() {
        var target = TargetState(
            id: 1,
            kind: .enemy(.titanKeeper),
            position: .init(x: 0, y: 0.5),
            hitPoints: 10,
            maximumHitPoints: 10,
            phase: 0
        )
        target.burnRemaining = 3.5
        let node = GameNodeFactory.target(target)

        GameNodeFactory.updateStatus(on: node, target: target, reducedMotion: false)

        let front = node.childNode(withName: "//status-fire-front")
        let back = node.childNode(withName: "//status-fire-back")
        #expect(front?.alpha == 1)
        #expect(abs((back?.alpha ?? 0) - 0.82) < 0.001)
        #expect(front?.children.contains { $0.action(forKey: "flame-loop") != nil } == true)
        #expect(back?.children.contains { $0.action(forKey: "flame-loop") != nil } == true)

        GameNodeFactory.resetStatus(on: node)
        #expect(node.childNode(withName: "//status-overlay")?.alpha == 0)
        #expect(node.childNode(withName: "//status-underlay")?.alpha == 0)
        #expect(front?.children.allSatisfy { !$0.hasActions() } == true)
    }

    @Test func everyMarsAlienAcceptsFireIceAndReverseOnItsRenderedBody() {
        let marsEnemies: [EnemyKind] = [
            .dustSprite,
            .roverRaider,
            .craterCrawler,
            .saucerKeeper,
            .plasmaStriker,
            .marsColossus
        ]

        for (index, enemy) in marsEnemies.enumerated() {
            var target = TargetState(
                id: index,
                kind: .enemy(enemy),
                position: .init(x: 0, y: 0.5),
                hitPoints: 10,
                maximumHitPoints: 10,
                phase: 0
            )
            let node = GameNodeFactory.target(target)
            let body = node.childNode(withName: "//body-sprite") as? SKSpriteNode

            target.freezeRemaining = 2
            GameNodeFactory.updateStatus(on: node, target: target, reducedMotion: false)
            #expect(body?.colorBlendFactor ?? 0 > 0.4)
            #expect(node.childNode(withName: "//status-ice-crystals")?.alpha == 1)

            GameNodeFactory.resetStatus(on: node)
            target.freezeRemaining = 0
            target.burnRemaining = 2
            GameNodeFactory.updateStatus(on: node, target: target, reducedMotion: false)
            #expect(body?.colorBlendFactor ?? 0 > 0.15)
            #expect(node.childNode(withName: "//status-fire-front")?.alpha == 1)

            GameNodeFactory.resetStatus(on: node)
            target.burnRemaining = 0
            target.reverseRemaining = 2
            GameNodeFactory.updateStatus(on: node, target: target, reducedMotion: false)
            #expect(body?.colorBlendFactor ?? 0 > 0.15)
            #expect(node.childNode(withName: "//status-reverse-trail")?.alpha ?? 0 > 0.8)
        }
    }

    @Test func firstEndlessWaveClearsAndOffersAnotherDraft() {
        var progress = PlayerProgress.newPlayer
        for track in UpgradeTrack.allCases { progress.setRank(5, for: track) }
        let simulation = GameSimulation(mode: .endless, progress: progress, assistMode: true, seed: 9)
        simulation.apply(.oneTwo)
        simulation.apply(.powerDrive)
        simulation.apply(.curler)
        var cleared = false
        for _ in 0..<1_400 where !cleared {
            if let target = simulation.snapshot.targets.first {
                simulation.setPlayerTarget(x: target.position.x)
            }
            let events = simulation.update(delta: 0.05)
            cleared = events.contains { if case .waveCompleted(1) = $0 { true } else { false } }
        }
        #expect(cleared)
        #expect(simulation.snapshot.wave == 2)
        #expect(simulation.snapshot.score >= EndlessRules.waveClearScore(wave: 1))
    }

    @Test func checkpointPausesCanBeDetectedDeterministically() {
        var progress = PlayerProgress.newPlayer
        for track in UpgradeTrack.allCases { progress.setRank(5, for: track) }
        let simulation = GameSimulation(level: GameContent.level(2), progress: progress, assistMode: true, seed: 8)
        var sawCheckpoint = false
        for _ in 0..<2_000 {
            if let target = simulation.snapshot.targets.first {
                simulation.setPlayerTarget(x: target.position.x)
            }
            let events = simulation.update(delta: 0.05)
            if events.contains(where: { if case .checkpoint = $0 { true } else { false } }) {
                sawCheckpoint = true
                break
            }
        }
        #expect(sawCheckpoint)
        #expect(simulation.snapshot.wave == 2)
    }

    @Test func completionBonusesSupportUpgradesWithoutFundingAStraightWalkthrough() {
        let earthCampaign = GameContent.levels(in: .earth).reduce(0) { $0 + $1.firstClearBonus }
        let moonCampaign = GameContent.levels(in: .moon).reduce(0) { $0 + $1.firstClearBonus }
        let marsCampaign = GameContent.levels(in: .mars).reduce(0) { $0 + $1.firstClearBonus }
        let firstTwoRanksAcrossAllTracks = UpgradeTrack.allCases.count * (UpgradeRules.costs[0] + UpgradeRules.costs[1])
        let masteryBuild = UpgradeTrack.allCases.count * UpgradeRules.costs.reduce(0, +)
        #expect(GameContent.level(1).firstClearBonus >= UpgradeRules.cost(forNextRank: 0))
        #expect(earthCampaign == 1_725)
        #expect(moonCampaign == 3_450)
        #expect(marsCampaign == 6_405)
        #expect(earthCampaign < firstTwoRanksAcrossAllTracks)
        #expect(earthCampaign < masteryBuild)
        #expect(GameContent.levels.allSatisfy { $0.replayBonus < $0.firstClearBonus })
    }

    @Test func comboResetsWhenStaminaTakesDamage() {
        let simulation = simulationWithCombo()
        let staminaBeforeHit = simulation.snapshot.stamina

        simulation.spawnHostileProjectileForTesting(x: simulation.snapshot.playerX, y: 0.16)
        let events = simulation.update(delta: 0.05)

        #expect(simulation.snapshot.stamina < staminaBeforeHit)
        #expect(simulation.snapshot.combo == 0)
        #expect(simulation.snapshot.comboFraction == 0)
        #expect(events.contains(.comboChanged(0)))
    }

    @Test func comboPersistsAsTimePassesWithoutStaminaLoss() {
        let simulation = simulationWithCombo()
        let staminaBeforeWaiting = simulation.snapshot.stamina
        let comboBeforeWaiting = simulation.snapshot.combo

        for _ in 0..<200 {
            simulation.replaceTargetsForTesting([])
            _ = simulation.update(delta: 0.05)
        }

        #expect(simulation.snapshot.stamina == staminaBeforeWaiting)
        #expect(simulation.snapshot.combo == comboBeforeWaiting)
        #expect(simulation.snapshot.comboFraction == 1)
    }

    @Test func shieldedHitDoesNotResetCombo() {
        let simulation = simulationWithCombo()
        simulation.apply(.cleanSheet)
        let staminaBeforeHit = simulation.snapshot.stamina
        let comboBeforeHit = simulation.snapshot.combo

        simulation.spawnHostileProjectileForTesting(x: simulation.snapshot.playerX, y: 0.16)
        let events = simulation.update(delta: 0.05)

        #expect(simulation.snapshot.stamina == staminaBeforeHit)
        #expect(simulation.snapshot.shieldCharges == 0)
        #expect(simulation.snapshot.combo == comboBeforeHit)
        #expect(!events.contains(.comboChanged(0)))
    }

    private func simulationWithCombo() -> GameSimulation {
        let simulation = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: false,
            seed: 5
        )
        simulation.replaceTargetsForTesting([
            TargetState(
                id: 9_000,
                kind: .enemy(.coneRunner),
                position: .init(x: 0, y: 0.28),
                hitPoints: 1,
                maximumHitPoints: 1,
                phase: 0
            )
        ])
        simulation.spawnFriendlyProjectileForTesting(pierce: 0)
        for _ in 0..<20 where simulation.snapshot.combo == 0 {
            _ = simulation.update(delta: 0.05)
        }
        #expect(simulation.snapshot.combo == 1)
        return simulation
    }

    @Test func levelOneIsForgivingForNewPlayers() {
        let forgiving = GameSimulation(level: GameContent.level(1), progress: .newPlayer, assistMode: false, seed: 3)
        let standard = GameSimulation(level: GameContent.level(2), progress: .newPlayer, assistMode: false, seed: 3)
        for _ in 0..<200 {
            _ = forgiving.update(delta: 0.05)
            _ = standard.update(delta: 0.05)
        }
        let forgivingHP = forgiving.snapshot.targets
            .filter { if case .enemy = $0.kind { $0.bossTier == .standard } else { false } }
            .map(\.maximumHitPoints)
            .max() ?? 0
        let standardHP = standard.snapshot.targets
            .filter { if case .enemy = $0.kind { $0.bossTier == .standard } else { false } }
            .map(\.maximumHitPoints)
            .max() ?? 0
        #expect(forgivingHP < standardHP)
        #expect(abs(forgivingHP - 7.8) < 0.0001)
    }

    @Test func levelOneEnemiesAdvanceMoreSlowly() {
        let forgiving = GameSimulation(level: GameContent.level(1), progress: .newPlayer, assistMode: false, seed: 3)
        let standard = GameSimulation(level: GameContent.level(2), progress: .newPlayer, assistMode: false, seed: 3)
        let sharedEnemy = TargetState(
            id: 9_600,
            kind: .enemy(.coneRunner),
            position: .init(x: 0, y: 0.80),
            hitPoints: 10,
            maximumHitPoints: 10,
            phase: 0
        )
        forgiving.replaceTargetsForTesting([sharedEnemy])
        standard.replaceTargetsForTesting([sharedEnemy])

        _ = forgiving.update(delta: 0.05)
        _ = standard.update(delta: 0.05)

        let forgivingAdvance = 0.80 - forgiving.snapshot.targets[0].position.y
        let standardAdvance = 0.80 - standard.snapshot.targets[0].position.y
        #expect(forgivingAdvance < standardAdvance)

        // Pin the level-one speed factor exactly for standard enemies.
        let before = Dictionary(uniqueKeysWithValues: forgiving.snapshot.targets.map { ($0.id, $0.position.y) })
        _ = forgiving.update(delta: 0.05)
        var tracked = 0
        for target in forgiving.snapshot.targets {
            guard case .enemy = target.kind,
                  target.bossTier == .standard,
                  let previousY = before[target.id] else { continue }
            tracked += 1
            #expect(abs(previousY - target.position.y - 0.105 * 0.80 * 0.05) < 0.0001)
        }
        #expect(tracked > 0)
    }

    @Test func everyRegularWaveOffersAZigZagPowerTargetAtHalfQuota() {
        let simulation = GameSimulation(level: GameContent.level(1), progress: .newPlayer, assistMode: false, seed: 3)
        simulation.setWaveDefeatsForTesting(simulation.snapshot.waveEnemyQuota / 2)
        var sawPowerTarget = false
        var movedLaterally = false
        var previousX: Double?
        for _ in 0..<500 where !sawPowerTarget || !movedLaterally {
            _ = simulation.update(delta: 0.05)
            if let powerTarget = simulation.snapshot.targets.first(where: {
                if case .powerUp = $0.kind { true } else { false }
            }) {
                sawPowerTarget = true
                if let previousX, abs(previousX - powerTarget.position.x) > 0.001 {
                    movedLaterally = true
                }
                previousX = powerTarget.position.x
            }
        }
        #expect(sawPowerTarget)
        #expect(movedLaterally)
    }

    @Test func powerUpIsAHealthBarFreeTrophyPickup() {
        let target = TargetState(
            id: 1,
            kind: .powerUp(.fire),
            position: .init(x: 0, y: 0.5),
            hitPoints: 1,
            maximumHitPoints: 1,
            phase: 0
        )
        let node = GameNodeFactory.target(target)

        #expect(node.childNode(withName: "power-up-trophy") != nil)
        #expect(node.childNode(withName: "health-background") == nil)
        #expect(node.childNode(withName: "status-ring") == nil)
    }

    @Test func firstDirectBallHitCollectsPowerUpTrophy() {
        let simulation = GameSimulation(
            level: GameContent.level(1),
            progress: .newPlayer,
            assistMode: true,
            seed: 3
        )
        for _ in 0..<3 {
            simulation.apply(.quickRelease)
            simulation.apply(.throughBall)
        }
        simulation.setWaveDefeatsForTesting(simulation.snapshot.waveEnemyQuota / 2)

        var spawnedHitPoints: Double?
        var collectedAbility: TemporaryBallAbility?
        for _ in 0..<500 where collectedAbility == nil {
            if let trophy = simulation.snapshot.targets.first(where: {
                if case .powerUp = $0.kind { true } else { false }
            }) {
                spawnedHitPoints = trophy.maximumHitPoints
                simulation.setPlayerTarget(x: trophy.position.x)
            }
            let events = simulation.update(delta: 0.05)
            for event in events {
                if case .temporaryAbilityActivated(let ability, _, _) = event {
                    collectedAbility = ability
                }
            }
        }

        #expect(spawnedHitPoints == 1)
        #expect(collectedAbility != nil)
        #expect(simulation.snapshot.activeTemporaryAbility == collectedAbility)
        #expect(!simulation.snapshot.targets.contains {
            if case .powerUp = $0.kind { true } else { false }
        })
    }

    @Test func temporaryAbilitiesExpireAndRapidFireIsExtremeButBounded() {
        let simulation = GameSimulation(level: GameContent.level(1), progress: .newPlayer, assistMode: true, seed: 17)
        simulation.activateTemporaryAbility(.rapidFire)
        let duration = TemporaryAbilityRules.duration(for: .rapidFire)
        var kickCount = 0
        for _ in 0..<20 {
            kickCount += simulation.update(delta: 0.05).count { $0 == .kick }
        }
        #expect(kickCount >= 4)
        #expect(simulation.snapshot.activeTemporaryAbility == .rapidFire)

        for _ in 0..<Int(duration / 0.05) + 2 {
            _ = simulation.update(delta: 0.05)
        }
        #expect(simulation.snapshot.activeTemporaryAbility == nil)
        #expect(simulation.snapshot.temporaryAbilityRemaining == 0)
    }

    @Test func voltBallIsASevenSecondRareUniversalPower() {
        #expect(TemporaryAbilityRules.duration(for: .volt) == 7)
        #expect(TemporaryAbilityRules.title(for: .volt) == "Volt Ball")
        #expect(TemporaryAbilityRules.icon(for: .volt) == "bolt.horizontal.fill")
        #expect(TemporaryAbilityRules.voltSpawnChance == 0.15)

        for world in WorldID.allCases {
            let powers = GameContent.world(world).temporaryPowers
            #expect(TemporaryAbilityRules.spawnedAbility(
                worldPowers: powers,
                universalRoll: 0.149,
                worldRoll: 0.9
            ) == .volt)
            #expect(TemporaryAbilityRules.spawnedAbility(
                worldPowers: powers,
                universalRoll: 0.15,
                worldRoll: 0
            ) == powers[0])
            #expect(TemporaryAbilityRules.spawnedAbility(
                worldPowers: powers,
                universalRoll: 0.99,
                worldRoll: 0.999
            ) == powers[2])
        }
    }

    @Test func voltChainOrdersEveryEnemyAndBuildsOneTwoFourBranches() throws {
        let simulation = GameSimulation(
            level: GameContent.level(10),
            progress: .newPlayer,
            assistMode: false,
            seed: 607
        )
        let origin = TargetState(
            id: 10_000,
            kind: .enemy(.dummyDefender),
            position: .init(x: 0, y: 0.18),
            hitPoints: 1_000,
            maximumHitPoints: 1_000,
            phase: 0
        )
        let enemyPositions: [Vector2] = [
            .init(x: 0.10, y: 0.30),
            .init(x: -0.20, y: 0.34),
            .init(x: 0.26, y: 0.38),
            .init(x: -0.34, y: 0.45),
            .init(x: 0.42, y: 0.50),
            .init(x: -0.50, y: 0.58),
            .init(x: 0.60, y: 0.68)
        ]
        let enemies = enemyPositions.enumerated().map { offset, position in
            TargetState(
                id: 10_001 + offset,
                kind: .enemy(offset == 6 ? .titanKeeper : .tackleBot),
                position: position,
                hitPoints: 1_000,
                maximumHitPoints: 1_000,
                phase: 0,
                bossTier: offset == 6 ? .megaBoss : .standard,
                waveRole: offset == 5 ? .reinforcement : .quota
            )
        }
        let excluded = [
            TargetState(
                id: 10_100,
                kind: .fieldObject(.ballCart),
                position: .init(x: 0.04, y: 0.24),
                hitPoints: 100,
                maximumHitPoints: 100,
                phase: 0
            ),
            TargetState(
                id: 10_101,
                kind: .powerUp(.fire),
                position: .init(x: -0.05, y: 0.25),
                hitPoints: 1,
                maximumHitPoints: 1,
                phase: 0
            ),
            TargetState(
                id: 10_102,
                kind: .volatileCore,
                position: .init(x: 0.06, y: 0.26),
                hitPoints: 1,
                maximumHitPoints: 1,
                phase: 0
            )
        ]
        simulation.replaceTargetsForTesting([origin] + enemies + excluded)
        simulation.spawnFriendlyProjectileForTesting(pierce: 3, temporaryAbility: .volt)

        let events = simulation.update(delta: 0.01)
        let chain = try #require(events.compactMap { event -> VoltChainEvent? in
            if case .voltChain(let chain) = event { return chain }
            return nil
        }.first)
        let directImpact = try #require(events.compactMap { event -> ImpactEvent? in
            if case .impact(let impact) = event { return impact }
            return nil
        }.first)

        #expect(directImpact.targetID == origin.id)
        #expect(directImpact.flavor == .volt)
        #expect(chain.originTargetID == origin.id)
        #expect(Set(chain.arcs.map(\.targetID)) == Set(enemies.map(\.id)))
        let distances = chain.arcs.map {
            hypot(
                $0.destination.x - chain.origin.x,
                $0.destination.y - chain.origin.y
            )
        }
        #expect(zip(distances, distances.dropFirst()).allSatisfy { $0 <= $1 })
        #expect(chain.arcs.map(\.generation) == [1, 2, 2, 3, 3, 3, 3])
        #expect(chain.arcs[0].source == chain.origin)
        #expect(chain.arcs[1].source == chain.arcs[0].destination)
        #expect(chain.arcs[2].source == chain.arcs[0].destination)
        #expect(chain.arcs[3].source == chain.arcs[1].destination)
        #expect(chain.arcs[4].source == chain.arcs[1].destination)
        #expect(chain.arcs[5].source == chain.arcs[2].destination)
        #expect(chain.arcs[6].source == chain.arcs[2].destination)
        for (offset, arc) in chain.arcs.enumerated() {
            let expectedDamage = 10 * (0.15 + Double(offset) * 0.05)
            #expect(abs(arc.damage - expectedDamage) < 0.000_001)
        }
        #expect(Set(chain.arcs.map(\.targetID)).isDisjoint(with: excluded.map(\.id)))
    }

    @Test func onePiercingVoltBallTriggersOnlyOneChainButSeparateBallsEachTrigger() {
        let makeSimulation = {
            let simulation = GameSimulation(
                level: GameContent.level(4),
                progress: .newPlayer,
                assistMode: false,
                seed: 613
            )
            simulation.replaceTargetsForTesting([
                TargetState(
                    id: 11_000,
                    kind: .enemy(.dummyDefender),
                    position: .init(x: 0, y: 0.18),
                    hitPoints: 1_000,
                    maximumHitPoints: 1_000,
                    phase: 0
                ),
                TargetState(
                    id: 11_001,
                    kind: .enemy(.tackleBot),
                    position: .init(x: 0, y: 0.34),
                    hitPoints: 1_000,
                    maximumHitPoints: 1_000,
                    phase: 0
                ),
                TargetState(
                    id: 11_002,
                    kind: .enemy(.keeperDrone),
                    position: .init(x: 0, y: 0.52),
                    hitPoints: 1_000,
                    maximumHitPoints: 1_000,
                    phase: 0
                )
            ])
            return simulation
        }

        let piercing = makeSimulation()
        piercing.spawnFriendlyProjectileForTesting(pierce: 3, temporaryAbility: .volt)
        var piercingChainCount = 0
        var directHitIDs: [Int] = []
        for _ in 0..<60 {
            for event in piercing.update(delta: 0.01) {
                if case .voltChain = event {
                    piercingChainCount += 1
                } else if case .impact(let impact) = event, impact.delivery == .direct {
                    directHitIDs.append(impact.targetID)
                }
            }
        }
        #expect(piercingChainCount == 1)
        #expect(Set(directHitIDs).count >= 2)

        let volley = makeSimulation()
        volley.spawnFriendlyProjectileForTesting(pierce: 0, temporaryAbility: .volt)
        volley.spawnFriendlyProjectileForTesting(pierce: 0, temporaryAbility: .volt)
        let volleyChains = volley.update(delta: 0.01).count {
            if case .voltChain = $0 { return true }
            return false
        }
        #expect(volleyChains == 2)
    }

    @Test func voltChainDefeatsUseNormalComboQuotaRewardAndChargeBookkeeping() {
        let simulation = GameSimulation(
            level: GameContent.level(1),
            progress: .newPlayer,
            assistMode: false,
            seed: 619
        )
        simulation.replaceTargetsForTesting([
            TargetState(
                id: 12_000,
                kind: .enemy(.coneRunner),
                position: .init(x: 0, y: 0.18),
                hitPoints: 1,
                maximumHitPoints: 1,
                phase: 0
            ),
            TargetState(
                id: 12_001,
                kind: .enemy(.coneRunner),
                position: .init(x: 0.14, y: 0.30),
                hitPoints: 1,
                maximumHitPoints: 1,
                phase: 0
            ),
            TargetState(
                id: 12_002,
                kind: .enemy(.coneRunner),
                position: .init(x: -0.24, y: 0.36),
                hitPoints: 1,
                maximumHitPoints: 1,
                phase: 0
            )
        ])
        simulation.spawnFriendlyProjectileForTesting(pierce: 0, temporaryAbility: .volt)

        let events = simulation.update(delta: 0.01)

        #expect(simulation.snapshot.targets.isEmpty)
        #expect(simulation.snapshot.waveDefeats == 3)
        #expect(simulation.snapshot.targetsDefeated == 3)
        #expect(simulation.snapshot.combo == 3)
        #expect(simulation.snapshot.characterAbilityCharge > 0)
        #expect(events.count {
            if case .reward = $0 { return true }
            return false
        } == 3)
    }

    @Test func iceAndSplitPowersProduceDistinctCombatEffects() {
        let ice = GameSimulation(level: GameContent.level(4), progress: .newPlayer, assistMode: true, seed: 21)
        ice.activateTemporaryAbility(.ice)
        var sawIceDamage = false
        var sawFrozenEnemy = false
        for _ in 0..<600 where !sawIceDamage || !sawFrozenEnemy {
            if let target = ice.snapshot.targets.first {
                ice.setPlayerTarget(x: target.position.x)
            }
            let events = ice.update(delta: 0.05)
            sawIceDamage = sawIceDamage || events.contains { event in
                if case .impact(let impact) = event { impact.flavor == .ice } else { false }
            }
            sawFrozenEnemy = sawFrozenEnemy || ice.snapshot.targets.contains { $0.freezeRemaining > 0 }
        }
        #expect(sawIceDamage)
        #expect(sawFrozenEnemy)

        let split = GameSimulation(level: GameContent.level(4), progress: .newPlayer, assistMode: true, seed: 21)
        split.activateTemporaryAbility(.split)
        var sawSplitBurst = false
        for _ in 0..<600 where !sawSplitBurst {
            if let target = split.snapshot.targets.first {
                split.setPlayerTarget(x: target.position.x)
            }
            _ = split.update(delta: 0.05)
            sawSplitBurst = split.snapshot.projectiles.count {
                $0.temporaryAbility == .split && !$0.canSplit
            } >= 5
        }
        #expect(sawSplitBurst)
    }

    @Test func elementalAndControlPowersTagHitsAndApplyStatuses() {
        let cases: [(TemporaryBallAbility, DamageFlavor)] = [
            (.explosive, .explosive),
            (.fire, .fire),
            (.ice, .ice),
            (.reverse, .reverse),
            (.split, .split)
        ]

        for (ability, flavor) in cases {
            let simulation = GameSimulation(
                level: GameContent.level(4),
                progress: .newPlayer,
                assistMode: true,
                seed: 31
            )
            simulation.activateTemporaryAbility(ability)
            var sawFlavor = false
            var sawStatus = ability == .explosive || ability == .split
            for _ in 0..<600 where !sawFlavor || !sawStatus {
                if let target = simulation.snapshot.targets.first {
                    simulation.setPlayerTarget(x: target.position.x)
                }
                let events = simulation.update(delta: 0.05)
                sawFlavor = sawFlavor || events.contains { event in
                    if case .impact(let impact) = event {
                        impact.flavor == flavor
                    } else {
                        false
                    }
                }
                sawStatus = sawStatus || simulation.snapshot.targets.contains { target in
                    switch ability {
                    case .fire: target.burnRemaining > 0
                    case .ice: target.freezeRemaining > 0
                    case .reverse: target.reverseRemaining > 0
                    default: false
                    }
                }
            }
            #expect(sawFlavor)
            #expect(sawStatus)
        }
    }

    @Test func burningTicksPublishNonRecoilImpactMetadata() {
        let simulation = GameSimulation(
            level: GameContent.level(4),
            progress: .newPlayer,
            assistMode: true,
            seed: 311
        )
        simulation.activateTemporaryAbility(.fire)
        var directImpact: ImpactEvent?
        var damageOverTimeImpact: ImpactEvent?

        for _ in 0..<600 where directImpact == nil || damageOverTimeImpact == nil {
            if let target = simulation.snapshot.targets.first {
                simulation.setPlayerTarget(x: target.position.x)
            }
            for event in simulation.update(delta: 0.05) {
                guard case .impact(let impact) = event, impact.flavor == .fire else { continue }
                if impact.delivery == .direct {
                    directImpact = directImpact ?? impact
                } else if impact.delivery == .damageOverTime {
                    damageOverTimeImpact = damageOverTimeImpact ?? impact
                }
            }
        }

        #expect(directImpact?.delivery == .direct)
        #expect(damageOverTimeImpact?.delivery == .damageOverTime)
        #expect(damageOverTimeImpact?.impulse == .init(x: 0, y: 0))
        #expect(damageOverTimeImpact?.isCritical == false)
        #expect(damageOverTimeImpact?.targetID == directImpact?.targetID)
    }

    @Test func fireAndIceReplaceEachOtherWithAReactionInsteadOfStacking() {
        let simulation = GameSimulation(
            level: GameContent.level(4),
            progress: .newPlayer,
            assistMode: true,
            seed: 47
        )
        simulation.activateTemporaryAbility(.fire)
        var burningTargetID: Int?
        for _ in 0..<600 where burningTargetID == nil {
            if let target = simulation.snapshot.targets.first {
                simulation.setPlayerTarget(x: target.position.x)
            }
            _ = simulation.update(delta: 0.05)
            burningTargetID = simulation.snapshot.targets.first { $0.burnRemaining > 0 }?.id
        }
        #expect(burningTargetID != nil)

        simulation.activateTemporaryAbility(.ice)
        var sawReaction = false
        var everStacked = false
        for _ in 0..<600 where !sawReaction {
            if let target = simulation.snapshot.targets.first(where: { $0.id == burningTargetID })
                ?? simulation.snapshot.targets.first {
                simulation.setPlayerTarget(x: target.position.x)
            }
            let events = simulation.update(delta: 0.05)
            sawReaction = events.contains {
                if case .elementalReaction = $0 { true } else { false }
            }
            everStacked = everStacked || simulation.snapshot.targets.contains {
                $0.burnRemaining > 0 && $0.freezeRemaining > 0
            }
        }

        #expect(sawReaction)
        #expect(!everStacked)
    }

    @Test func bossMovementIsDeliberatelySlowAndMegaBossesAreLargest() {
        #expect(CampaignBalance.bossMovementRate(tier: .megaBoss)
                < CampaignBalance.bossMovementRate(tier: .miniBoss))
        #expect(CampaignBalance.bossMovementRate(tier: .miniBoss)
                < CampaignBalance.bossMovementRate(tier: .standard))
        #expect(CampaignBalance.bossScale(tier: .megaBoss)
                > CampaignBalance.bossScale(tier: .miniBoss))
        #expect(CampaignBalance.bossScale(tier: .miniBoss) >= 1.5)
        #expect(CampaignBalance.bossHealthMultiplier(tier: .miniBoss, wave: 5, world: .earth)
                > CampaignBalance.bossHealthMultiplier(tier: .miniBoss, wave: 1, world: .earth))
        let earthBossHealth = 720 * (1 + 9.0 * 0.025)
            * CampaignBalance.bossHealthMultiplier(tier: .megaBoss, wave: 5, world: .earth)
        let moonBossHealth = 820 * (1 + 19.0 * 0.025)
            * CampaignBalance.bossHealthMultiplier(tier: .megaBoss, wave: 5, world: .moon)
        let marsBossHealth = 900 * (1 + 29.0 * 0.025)
            * CampaignBalance.bossHealthMultiplier(tier: .megaBoss, wave: 5, world: .mars)
        #expect(moonBossHealth > earthBossHealth)
        #expect(marsBossHealth > moonBossHealth)
    }

    @Test func bossTargetsUseARedSigilHealthPlateThatResetsWhenPooled() {
        for (index, world) in WorldID.allCases.enumerated() {
            let boss = TargetState(
                id: 9_499 + index,
                kind: .enemy(GameContent.world(world).boss),
                position: .init(x: 0, y: CampaignBalance.bossArenaY),
                hitPoints: 75,
                maximumHitPoints: 100,
                phase: 0,
                bossTier: .megaBoss,
                waveRole: .boss
            )
            let node = GameNodeFactory.target(boss, world: world)
            let regularHealth = node.childNode(withName: "health-background")
            let bossHealth = node.childNode(withName: "boss-health")
            let bossIcon = bossHealth?.childNode(withName: "boss-health-icon") as? SKSpriteNode
            let track = bossHealth?.childNode(withName: "boss-health-track")
            guard let fill = track?.childNode(withName: "boss-health-fill") as? SKShapeNode else {
                Issue.record("\(world.rawValue) boss should have an in-world health fill")
                continue
            }

            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            #expect(regularHealth?.isHidden == true)
            #expect(bossHealth?.isHidden == false)
            #expect(bossIcon?.texture != nil)
            #expect(abs(fill.xScale - 0.75) < 0.001)
            #expect(fill.fillColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
            #expect(red > 0.9)
            #expect(green < 0.2)
            #expect(blue < 0.2)

            var regularTarget = boss
            regularTarget.bossTier = .standard
            regularTarget.waveRole = .quota
            GameNodeFactory.configureTarget(node, target: regularTarget, world: world)

            #expect(regularHealth?.isHidden == false)
            #expect(bossHealth?.isHidden == true)
        }
    }

    @Test func bossObjectivePublishesHealthProgressWithoutSeparateHUDState() {
        let boss = TargetState(
            id: 9_500,
            kind: .enemy(.ballLauncher),
            position: .init(x: 0, y: CampaignBalance.bossArenaY),
            hitPoints: 75,
            maximumHitPoints: 100,
            phase: 0,
            bossTier: .miniBoss
        )
        var snapshot = GameSimulation(
            level: GameContent.level(6),
            progress: .newPlayer,
            assistMode: false,
            seed: 6
        ).snapshot
        snapshot.targets = [boss]
        snapshot.isBossWave = true
        snapshot.waveEnemyQuota = 1
        snapshot.waveDefeats = 0

        let hud = HUDState(snapshot: snapshot)

        #expect(hud.remainingEnemies == 1)
        #expect(hud.waveObjectiveProgress == 0.25)
        #expect(snapshot.waveObjectiveProgress == 0.25)
    }

    @Test func regularWaveHUDPublishesDefeatsRemainingAndProgress() {
        var snapshot = GameSimulation(
            level: GameContent.level(1),
            progress: .newPlayer,
            assistMode: false,
            seed: 7
        ).snapshot
        snapshot.waveDefeats = 7

        let hud = HUDState(snapshot: snapshot)

        #expect(hud.waveEnemyQuota == 18)
        #expect(hud.waveDefeats == 7)
        #expect(hud.remainingEnemies == 11)
        #expect(abs(hud.waveObjectiveProgress - 7.0 / 18.0) < 0.0001)
    }
}
