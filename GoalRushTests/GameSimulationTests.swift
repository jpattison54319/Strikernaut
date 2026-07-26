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
        let simulation = GameSimulation(mode: .endless(world: .earth), progress: .newPlayer, assistMode: false, seed: 1)
        for _ in 0..<40 { simulation.apply(.powerDrive) }
        #expect(simulation.abilityRank(.powerDrive) == 40)
        #expect(simulation.kickInterval(atAbilityRank: 40) < simulation.kickInterval(atAbilityRank: 39))
        #expect(simulation.kickInterval(atAbilityRank: 40) > 0.14)
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
            #expect(level.duration > 60)
            #expect((3...5).contains(level.waveCount))
            #expect(level.waveDuration > 15)
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

    @Test func campaignWaveDifficultyAndUpgradeBudgetScaleTogether() {
        for level in GameContent.levels {
            var previous = CampaignBalance.wave(1, for: level)
            for waveNumber in 2...level.waveCount {
                let wave = CampaignBalance.wave(waveNumber, for: level)
                #expect(wave.healthMultiplier > previous.healthMultiplier)
                #expect(wave.damageMultiplier > previous.damageMultiplier)
                #expect(wave.speedMultiplier > previous.speedMultiplier)
                #expect(wave.spawnInterval < previous.spawnInterval)

                let enemyGrowth = wave.healthMultiplier / CampaignBalance.wave(1, for: level).healthMultiplier
                let playerGrowth = CampaignBalance.expectedOffenseMultiplier(afterUpgradeCount: waveNumber - 1)
                #expect(playerGrowth >= enemyGrowth)
                previous = wave
            }
        }
    }

    @Test func moonEntersAndLeavesZeroGravityOnARepeatableCycle() {
        let simulation = GameSimulation(
            level: GameContent.level(11),
            progress: .newPlayer,
            assistMode: true,
            seed: 17
        )
        var activationEvents: [SimulationEvent] = []
        for _ in 0..<201 {
            activationEvents.append(contentsOf: simulation.update(delta: 0.05))
        }

        #expect(simulation.snapshot.worldEffectActive)
        #expect(activationEvents.contains {
            if case .worldEffectActivated(.lunarCycle, _) = $0 { true } else { false }
        })

        for _ in 0..<120 {
            _ = simulation.update(delta: 0.05)
        }
        #expect(!simulation.snapshot.worldEffectActive)
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

        for _ in 0..<2_400 where !exposedCore {
            if let target = simulation.snapshot.targets.first(where: {
                if case .enemy = $0.kind { true } else { false }
            }) {
                simulation.setPlayerTarget(x: target.position.x)
            }
            _ = simulation.update(delta: 0.05)
            exposedCore = simulation.snapshot.targets.contains {
                if case .volatileCore = $0.kind { true } else { false }
            }
        }

        #expect(exposedCore)
        _ = simulation.update(delta: 0.01)
        #expect(simulation.snapshot.worldEffectProgress == 0)
    }

    @Test func campaignDifficultyKeepsEscalatingFromEarthThroughMarsAndFutureContent() {
        let openingEarth = CampaignBalance.wave(1, for: GameContent.level(1))
        let earthFinale = CampaignBalance.wave(1, for: GameContent.level(10))
        let openingMoon = CampaignBalance.wave(1, for: GameContent.level(11))
        let moonFinale = CampaignBalance.wave(1, for: GameContent.level(20))
        let openingMars = CampaignBalance.wave(1, for: GameContent.level(21))
        let marsFinale = CampaignBalance.wave(1, for: GameContent.level(30))
        let futureLevel = LevelDefinition(
            number: 40,
            world: .mars,
            worldLevel: 10,
            name: "Future Balance Probe",
            subtitle: "",
            duration: 120,
            spawnInterval: 1,
            enemies: [.marsColossus],
            objects: [.artifactVault],
            hasBoss: true,
            firstClearBonus: 1,
            replayBonus: 1
        )
        let futureWorldFinale = CampaignBalance.wave(1, for: futureLevel)

        #expect(earthFinale.healthMultiplier > openingEarth.healthMultiplier)
        #expect(openingMoon.healthMultiplier > earthFinale.healthMultiplier)
        #expect(moonFinale.healthMultiplier > openingMoon.healthMultiplier)
        #expect(openingMars.healthMultiplier > moonFinale.healthMultiplier)
        #expect(marsFinale.healthMultiplier > openingMars.healthMultiplier)
        #expect(futureWorldFinale.healthMultiplier > marsFinale.healthMultiplier)
        #expect(futureWorldFinale.damageMultiplier > marsFinale.damageMultiplier)
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
        openingWave.setCampaignWaveForTesting(1, elapsed: level.waveDuration * 0.75)

        _ = openingWave.update(delta: 0.05)

        #expect(openingWave.snapshot.targets.allSatisfy { $0.bossTier == .standard })

        let finalWave = GameSimulation(
            level: level,
            progress: .newPlayer,
            assistMode: true,
            seed: 88
        )
        finalWave.setCampaignWaveForTesting(
            level.waveCount,
            elapsed: level.waveDuration * 0.75
        )

        _ = finalWave.update(delta: 0.05)

        #expect(finalWave.snapshot.targets.contains { $0.bossTier == .miniBoss })
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

    @Test func characterAbilityChainExplosionDoesNotRechargeAbility() {
        var progress = PlayerProgress.newPlayer
        progress.selectedCharacter = .ace
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
                position: .init(x: 0.13, y: 0.19),
                hitPoints: 1,
                maximumHitPoints: 1,
                phase: 0
            ),
            TargetState(
                id: 9_202,
                kind: .enemy(.coneRunner),
                position: .init(x: 0.22, y: 0.23),
                hitPoints: 1,
                maximumHitPoints: 1,
                phase: 0
            )
        ])
        simulation.fullyChargeCharacterAbilityForTesting()

        _ = simulation.activateCharacterAbility()
        _ = simulation.update(delta: 0.05)

        #expect(simulation.snapshot.targetsDefeated == 1)
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
        #expect(events.contains { event in
            if case .impact = event { return true }
            return false
        })
        #expect(simulation.snapshot.projectiles.count == 3)
        #expect(simulation.snapshot.projectiles.contains {
            $0.characterProjectile == .pinballBlitz && $0.contactedTargetIDs.contains(robot.id)
        })
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

        for _ in 0..<19 {
            _ = simulation.update(delta: 0.05)
        }

        let collateralHealth = simulation.snapshot.targets
            .first(where: { $0.id == collateralTarget.id })?
            .hitPoints ?? 500
        #expect(collateralHealth < 500)
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
            #expect(rig != nil)
            #expect(rig?.childNode(withName: "body-sprite") != nil)
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
            let sprite = rig?.childNode(withName: "body-sprite") as? SKSpriteNode

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
        let body = rig?.childNode(withName: "body-sprite") as? SKSpriteNode
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
        let simulation = GameSimulation(mode: .endless(world: .earth), progress: progress, assistMode: true, seed: 9)
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

    @Test func earthBonusesFundEarlyRanksWhileLaterWorldsExtendProgression() {
        let earthCampaign = GameContent.levels(in: .earth).reduce(0) { $0 + $1.firstClearBonus }
        let fullCampaign = GameContent.levels.reduce(0) { $0 + $1.firstClearBonus }
        let firstTwoRanksAcrossAllTracks = UpgradeTrack.allCases.count * (UpgradeRules.costs[0] + UpgradeRules.costs[1])
        let masteryBuild = UpgradeTrack.allCases.count * UpgradeRules.costs.reduce(0, +)
        #expect(earthCampaign >= firstTwoRanksAcrossAllTracks)
        #expect(earthCampaign < masteryBuild)
        #expect(fullCampaign > earthCampaign)
    }

    @Test func comboBuildsOnDefeatsAndResetsOnDamage() {
        let simulation = GameSimulation(mode: .endless(world: .earth), progress: .newPlayer, assistMode: true, seed: 5)
        simulation.apply(.oneTwo)
        simulation.apply(.powerDrive)
        var sawCombo = false
        var sawReset = false
        for _ in 0..<2_000 where !sawReset {
            if let target = simulation.snapshot.targets.first {
                simulation.setPlayerTarget(x: target.position.x)
            }
            for event in simulation.update(delta: 0.05) {
                if case .comboChanged(let count) = event, count >= 2 { sawCombo = true }
                if case .comboChanged(0) = event, sawCombo { sawReset = true }
            }
        }
        #expect(sawCombo)
        #expect(simulation.snapshot.bestCombo >= 2)
        #expect(simulation.snapshot.targetsDefeated >= simulation.snapshot.bestCombo)
    }

    @Test func comboResetsWithinSecondsWithoutDefeats() {
        let simulation = GameSimulation(mode: .endless(world: .earth), progress: .newPlayer, assistMode: true, seed: 5)
        simulation.apply(.powerDrive)
        var builtCombo = false
        for _ in 0..<1_200 where !builtCombo {
            if let target = simulation.snapshot.targets.first {
                simulation.setPlayerTarget(x: target.position.x)
            }
            builtCombo = simulation.update(delta: 0.05).contains { event in
                if case .comboChanged(let count) = event { return count >= 1 }
                return false
            }
        }
        #expect(builtCombo)
        // Stop aiming. The 3 s window lapses, or an enemy reaches the line and
        // deals damage — either way the combo must reset within 20 simulated seconds.
        var reset = false
        for _ in 0..<400 where !reset {
            _ = simulation.update(delta: 0.05)
            reset = simulation.snapshot.combo == 0
        }
        #expect(reset)
        #expect(simulation.snapshot.comboFraction == 0)
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

    @Test func everyWaveSchedulesAZigZagPowerTarget() {
        let simulation = GameSimulation(level: GameContent.level(1), progress: .newPlayer, assistMode: false, seed: 3)
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
                if case .impact(_, _, .ice, _) = event { true } else { false }
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
                    if case .impact(_, _, let eventFlavor, _) = event {
                        eventFlavor == flavor
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
        #expect(CampaignBalance.bossHealthMultiplier(tier: .miniBoss, wave: 5)
                > CampaignBalance.bossHealthMultiplier(tier: .miniBoss, wave: 1))
    }

    @Test func bossHUDIdentifiesBossAndPublishesItsHealth() {
        let boss = TargetState(
            id: 9_500,
            kind: .enemy(.ballLauncher),
            position: .init(x: 0, y: 0.82),
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

        let hud = HUDState(snapshot: snapshot)

        #expect(hud.bossActive)
        #expect(hud.bossName == "Ball Launcher")
        #expect(hud.bossHealthFraction == 0.75)
        #expect(hud.bossTier == .miniBoss)
    }
}
