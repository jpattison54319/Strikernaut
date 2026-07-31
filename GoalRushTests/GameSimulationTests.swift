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

    @Test(
        arguments: [
            RunMode.campaign(level: 1),
            RunMode.endless,
        ]
    )
    func hostileProjectileHitTimingMatchesTheRenderedPlayerCore(mode: RunMode) {
        func simulation(seed: UInt64) -> GameSimulation {
            GameSimulation(
                mode: mode,
                progress: .newPlayer,
                assistMode: false,
                seed: seed
            )
        }

        let earlyVerticalGraze = simulation(seed: 7_201)
        earlyVerticalGraze.spawnHostileProjectileForTesting(
            x: earlyVerticalGraze.snapshot.playerX,
            y: 0.18
        )
        let earlyEvents = earlyVerticalGraze.update(delta: 0.05)

        #expect(
            earlyVerticalGraze.snapshot.stamina
                == earlyVerticalGraze.snapshot.maxStamina
        )
        #expect(!earlyEvents.contains(.damage))

        let lateralGraze = simulation(seed: 7_202)
        lateralGraze.spawnHostileProjectileForTesting(
            x: lateralGraze.snapshot.playerX + 0.095,
            y: 0.139
        )
        let lateralEvents = lateralGraze.update(delta: 0.05)

        #expect(lateralGraze.snapshot.stamina == lateralGraze.snapshot.maxStamina)
        #expect(!lateralEvents.contains(.damage))

        let coreHit = simulation(seed: 7_203)
        coreHit.spawnHostileProjectileForTesting(
            x: coreHit.snapshot.playerX + 0.07,
            y: 0.139
        )
        let hitEvents = coreHit.update(delta: 0.05)

        #expect(coreHit.snapshot.stamina < coreHit.snapshot.maxStamina)
        #expect(hitEvents.contains(.damage))
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
        #expect(
            simulation.kickInterval(atAbilityRank: 40)
                < simulation.kickInterval(atAbilityRank: 39)
        )
        #expect(
            simulation.kickInterval(atAbilityRank: 40)
                > EndlessAbilityRules.minimumRenderedKickInterval
        )
        #expect(
            simulation.quickReleaseDamageMultiplier(atAbilityRank: 100)
                > simulation.quickReleaseDamageMultiplier(atAbilityRank: 99)
        )
    }

    @Test func endlessContinuousUpgradesDiminishAfterRankFiveWithoutDeadRanks() {
        let ranks = [0, 1, 5, 6, 10, 30, 100]
        let effectiveRanks = ranks.map(EndlessAbilityRules.effectiveRank)
        #expect(effectiveRanks == effectiveRanks.sorted())
        #expect(effectiveRanks[2] == 5)
        #expect(abs(effectiveRanks[4] - 8.465_736) < 0.000_001)
        #expect(abs(effectiveRanks[5] - 13.958_797) < 0.000_001)

        for rank in 1...100 {
            #expect(
                EndlessAbilityRules.effectiveRank(rank)
                    > EndlessAbilityRules.effectiveRank(rank - 1)
            )
            #expect(
                EndlessAbilityRules.powerDriveMultiplier(rank: rank)
                    > EndlessAbilityRules.powerDriveMultiplier(rank: rank - 1)
            )
            #expect(
                EndlessAbilityRules.theoreticalKickInterval(
                    base: 1.12,
                    rank: rank
                ) < EndlessAbilityRules.theoreticalKickInterval(
                    base: 1.12,
                    rank: rank - 1
                )
            )
            #expect(
                EndlessAbilityRules.curlerTurnRate(rank: rank)
                    > EndlessAbilityRules.curlerTurnRate(rank: rank - 1)
            )
            #expect(
                EndlessAbilityRules.meteorDamageMultiplier(rank: rank)
                    > EndlessAbilityRules.meteorDamageMultiplier(rank: rank - 1)
            )
            #expect(
                EndlessAbilityRules.secondWindImmediateRecovery(rank: rank)
                    > EndlessAbilityRules.secondWindImmediateRecovery(
                        rank: rank - 1
                    )
            )
        }

        let firstDiminishedGain = EndlessAbilityRules.effectiveRank(6)
            - EndlessAbilityRules.effectiveRank(5)
        let deepGain = EndlessAbilityRules.effectiveRank(30)
            - EndlessAbilityRules.effectiveRank(29)
        #expect(firstDiminishedGain < 1)
        #expect(deepGain < firstDiminishedGain)
    }

    @Test func endlessWideVolleyKeepsAddingBallsWhileMasteryDiminishes() {
        for rank in 4...100 {
            #expect(
                EndlessAbilityRules.wideVolleySecondaryMastery(rank: rank)
                    > EndlessAbilityRules.wideVolleySecondaryMastery(
                        rank: rank - 1
                    )
            )
        }

        let rankFiveGain = EndlessAbilityRules
            .wideVolleySecondaryMastery(rank: 5)
            - EndlessAbilityRules.wideVolleySecondaryMastery(rank: 4)
        let rankThirtyGain = EndlessAbilityRules
            .wideVolleySecondaryMastery(rank: 30)
            - EndlessAbilityRules.wideVolleySecondaryMastery(rank: 29)
        #expect(rankThirtyGain < rankFiveGain)

        let simulation = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: false,
            seed: 2
        )
        for _ in 0..<30 { simulation.apply(.oneTwo) }
        for _ in 0..<23 { _ = simulation.update(delta: 0.05) }
        #expect(simulation.snapshot.projectiles.filter { !$0.hostile }.count == 31)
    }

    @Test func endlessDraftPoolContainsTenCoreAndTenNonRedundantBallTracks() {
        let pool = RunUpgradeChoice.endlessPool
        let ballChoices = pool.compactMap { choice -> TemporaryBallAbility? in
            if case .specialBall(let ability) = choice { return ability }
            return nil
        }

        #expect(pool.count == 20)
        #expect(Set(pool).count == pool.count)
        #expect(
            ballChoices
                == [.volt, .ice, .fire, .reverse, .explosive, .split,
                    .gravityWell, .ringReturn, .polarLink, .undertow]
        )
        #expect(!ballChoices.contains(.rapidFire))
        #expect(!ballChoices.contains(.heatSeeking))
        #expect(!ballChoices.contains(.orbitShot))
        #expect(!ballChoices.contains(.solarPierce))
    }

    @Test func endlessSpecialBallEffectsRollIndependentlyAndReachCertainty() {
        #expect(EndlessSpecialBallRules.triggerChance(rank: 0) == 0)
        #expect(EndlessSpecialBallRules.triggerChance(rank: 1) == 0.10)
        #expect(EndlessSpecialBallRules.triggerChance(rank: 5) == 0.50)
        #expect(EndlessSpecialBallRules.triggerChance(rank: 10) == 1)
        #expect(EndlessSpecialBallRules.triggerChance(rank: 10_000) == 1)

        let effects = EndlessSpecialBallRules.triggeredEffects(
            ranks: [.ice: 1, .fire: 5, .split: 10],
            rolls: [.ice: 0.09, .fire: 0.51, .split: 0.999_999]
        )
        #expect(effects == [.ice, .split])

        let simultaneous = EndlessSpecialBallRules.triggeredEffects(
            ranks: [.ice: 4, .fire: 4, .reverse: 4],
            rolls: [.ice: 0.12, .fire: 0.22, .reverse: 0.32]
        )
        #expect(simultaneous == [.ice, .fire, .reverse])
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
        #expect(
            EndlessSpecialBallRules.ringReturnDamageMultiplier(rank: 10_001)
                > EndlessSpecialBallRules.ringReturnDamageMultiplier(rank: 10_000)
        )

        #expect(abs(EndlessSpecialBallRules.iceDuration(rank: 5) - 1.7) < 0.000_001)
        #expect(abs(EndlessSpecialBallRules.fireDuration(rank: 5) - 4) < 0.000_001)
        #expect(abs(EndlessSpecialBallRules.reverseDuration(rank: 5) - 2.8) < 0.000_001)
        #expect(abs(EndlessSpecialBallRules.explosionDamageMultiplier(rank: 5) - 0.55) < 0.000_001)
        #expect(abs(EndlessSpecialBallRules.explosionRadius(rank: 5) - 0.28) < 0.000_001)
        #expect(EndlessSpecialBallRules.splitProjectileCount(rank: 5, isCritical: false) == 5)
        #expect(EndlessSpecialBallRules.splitProjectileCount(rank: 5, isCritical: true) == 8)
        #expect(abs(EndlessSpecialBallRules.splitDamageMultiplier(rank: 5) - 0.42) < 0.000_001)
        #expect(
            abs(
                EndlessSpecialBallRules.voltDamageMultiplier(
                    recipientOffset: 0,
                    recipientCount: 9,
                    rank: 5
                ) - 0.55
            ) < 0.000_001
        )
        #expect(
            EndlessSpecialBallRules.voltDamageMultiplier(
                recipientOffset: 1,
                recipientCount: 9,
                rank: 5
            ) < EndlessSpecialBallRules.voltDamageMultiplier(
                recipientOffset: 0,
                recipientCount: 9,
                rank: 5
            )
        )
        #expect(
            EndlessSpecialBallRules.voltDamageMultiplier(
                recipientOffset: 100,
                recipientCount: 101,
                rank: 5
            ) > 0
        )
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

    @Test func rankTenEndlessVolleyCanApplyEveryBallEffectTogether() {
        let simulation = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: false,
            seed: 97
        )
        for ability in EndlessSpecialBallRules.abilities {
            for _ in 0..<10 {
                simulation.apply(.specialBall(ability))
            }
        }
        for _ in 0..<9 {
            simulation.apply(.ability(.oneTwo))
        }

        var sawKick = false
        for _ in 0..<30 where !sawKick {
            sawKick = simulation.update(delta: 0.05).contains(.kick)
        }

        let friendly = simulation.snapshot.projectiles.filter { !$0.hostile }
        #expect(sawKick)
        #expect(friendly.count == EndlessSpecialBallRules.abilities.count)
        #expect(friendly.allSatisfy { $0.temporaryAbility == nil })
        #expect(friendly.allSatisfy {
            $0.ballEffects == Set(EndlessSpecialBallRules.abilities)
        })
    }

    @Test func meteorStrikeCountsAllKicksAndLaunchesATargetedAreaAttack() {
        let simulation = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: false,
            seed: 99
        )
        for _ in 0..<4 {
            simulation.apply(.ability(.meteorStrike))
        }
        simulation.replaceTargetsForTesting([
            TargetState(
                id: 9_900,
                kind: .enemy(.titanKeeper),
                position: .init(x: 0, y: 0.62),
                hitPoints: 1_000_000,
                maximumHitPoints: 1_000_000,
                phase: 0
            )
        ])

        var kicks = 0
        var meteorLaunchEvents = 0
        for _ in 0..<100 where meteorLaunchEvents == 0 {
            let events = simulation.update(delta: 0.05)
            kicks += events.count { $0 == .kick }
            meteorLaunchEvents += events.count { $0 == .meteorKick }
        }

        #expect(kicks == 3)
        #expect(meteorLaunchEvents == 1)
        #expect(simulation.snapshot.characterAttacks.contains {
            $0.kind == .meteor
                && $0.targetID == 9_900
                && $0.awardsAbilityCharge
        })

        var sawImpact = false
        for _ in 0..<30 where !sawImpact {
            sawImpact = simulation.update(delta: 0.05).contains {
                if case .characterMeteorImpact = $0 { true } else { false }
            }
        }
        #expect(sawImpact)
        #expect(
            (simulation.snapshot.targets.first(where: { $0.id == 9_900 })?
                .hitPoints ?? 1_000_000) < 1_000_000
        )
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
        #expect(GameContent.levels.count == 70)
        #expect(GameContent.worlds.count == 7)
        #expect(WorldID.allCases.allSatisfy { GameContent.levels(in: $0).count == 10 })
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

    @Test func campaignWaveLoadOutgrowsTheReferenceDraftAdjustedDPS() {
        for level in GameContent.levels {
            var previous = CampaignBalance.wave(1, for: level)
            let averageBaseHealth = level.enemies
                .map { CombatBalance.baseHealth($0) }
                .reduce(0, +) / Double(level.enemies.count)
            var previousLoad = previous.healthMultiplier
                * averageBaseHealth
                * Double(CampaignBalance.enemyPackSize(wave: 1, for: level))
                / previous.spawnInterval
            for waveNumber in 2...level.waveCount {
                let wave = CampaignBalance.wave(waveNumber, for: level)
                #expect(wave.healthMultiplier > previous.healthMultiplier)
                #expect(wave.damageMultiplier > previous.damageMultiplier)
                #expect(wave.damageMultiplier.isFinite)
                #expect(wave.speedMultiplier > previous.speedMultiplier)
                #expect(
                    CampaignBalance.attackCadenceMultiplier(
                        level: level,
                        wave: waveNumber
                    ) < CampaignBalance.attackCadenceMultiplier(
                        level: level,
                        wave: waveNumber - 1
                    )
                )
                #expect(
                    CampaignBalance.hostileProjectileSpeedMultiplier(
                        level: level,
                        wave: waveNumber
                    ) > CampaignBalance.hostileProjectileSpeedMultiplier(
                        level: level,
                        wave: waveNumber - 1
                    )
                )

                let load = wave.healthMultiplier
                    * averageBaseHealth
                    * Double(
                        CampaignBalance.enemyPackSize(
                            wave: waveNumber,
                            for: level
                        )
                    )
                    / wave.spawnInterval
                    / CampaignBalance.expectedOffenseMultiplier(
                        afterUpgradeCount: waveNumber - 1
                    )
                let priorDraftAdjustedLoad = previousLoad
                    / CampaignBalance.expectedOffenseMultiplier(
                        afterUpgradeCount: waveNumber - 2
                )
                #expect(load > priorDraftAdjustedLoad)
                previousLoad = wave.healthMultiplier
                    * averageBaseHealth
                    * Double(
                        CampaignBalance.enemyPackSize(
                            wave: waveNumber,
                            for: level
                        )
                    )
                    / wave.spawnInterval
                previous = wave
            }
        }
    }

    private func averageEnemyHitPoints(
        _ wave: CampaignWaveDefinition,
        level: LevelDefinition
    ) -> Double {
        let averageBaseHealth = level.enemies
            .map { CombatBalance.baseHealth($0) }
            .reduce(0, +) / Double(level.enemies.count)
        return wave.healthMultiplier * averageBaseHealth
    }

    private func effectiveRunnerContactDamage(
        _ wave: CampaignWaveDefinition,
        maxStamina: Double
    ) -> Double {
        CombatBalance.effectiveIncomingDamage(
            rawDamage: 9 * wave.damageMultiplier,
            maxStamina: maxStamina
        )
    }

    @Test func everyCampaignLevelRaisesAllContinuousPressureAxes() {
        let fixedMoonReadyStamina = 140.0
        var previousLevel = GameContent.levels[0]
        var previousWave = CampaignBalance.wave(1, for: previousLevel)

        for level in GameContent.levels.dropFirst() {
            let wave = CampaignBalance.wave(1, for: level)

            #expect(
                CampaignBalance.targetPermanentRank(for: level)
                    > CampaignBalance.targetPermanentRank(for: previousLevel),
                "Level \(level.number) must require more permanent power."
            )
            #expect(
                averageEnemyHitPoints(wave, level: level)
                    > averageEnemyHitPoints(previousWave, level: previousLevel),
                "Level \(level.number) must raise average enemy durability."
            )
            #expect(
                effectiveRunnerContactDamage(
                    wave,
                    maxStamina: fixedMoonReadyStamina
                ) > effectiveRunnerContactDamage(
                    previousWave,
                    maxStamina: fixedMoonReadyStamina
                ),
                "Level \(level.number) must deal more damage to the same build."
            )
            #expect(
                wave.speedMultiplier > previousWave.speedMultiplier,
                "Level \(level.number) must move enemies faster."
            )
            #expect(
                wave.spawnInterval
                    / Double(CampaignBalance.enemyPackSize(wave: 1, for: level))
                    < previousWave.spawnInterval
                        / Double(
                            CampaignBalance.enemyPackSize(
                                wave: 1,
                                for: previousLevel
                            )
                        ),
                "Level \(level.number) must increase effective spawn pressure."
            )
            #expect(
                wave.enemyQuota > previousWave.enemyQuota,
                "Level \(level.number) must increase the opening workload."
            )
            #expect(
                CampaignBalance.attackCadenceMultiplier(level: level, wave: 1)
                    < CampaignBalance.attackCadenceMultiplier(
                        level: previousLevel,
                        wave: 1
                    ),
                "Level \(level.number) must accelerate hostile attacks."
            )
            #expect(
                CampaignBalance.hostileProjectileSpeedMultiplier(
                    level: level,
                    wave: 1
                ) > CampaignBalance.hostileProjectileSpeedMultiplier(
                    level: previousLevel,
                    wave: 1
                ),
                "Level \(level.number) must accelerate hostile projectiles."
            )

            previousLevel = level
            previousWave = wave
        }
    }

    @Test func levelsFiveEightAndTenCreatePersistentLandmarkStepsInEveryWorld() {
        for world in WorldID.allCases {
            let levels = GameContent.levels(in: world)
            let fourth = CampaignBalance.wave(1, for: levels[3])
            let fifth = CampaignBalance.wave(1, for: levels[4])
            let seventh = CampaignBalance.wave(1, for: levels[6])
            let eighth = CampaignBalance.wave(1, for: levels[7])
            let ninth = CampaignBalance.wave(1, for: levels[8])
            let finale = CampaignBalance.wave(1, for: levels[9])

            #expect(CampaignBalance.landmarkTier(worldLevel: levels[3].worldLevel) == 0)
            #expect(CampaignBalance.landmarkTier(worldLevel: levels[4].worldLevel) == 1)
            #expect(CampaignBalance.landmarkTier(worldLevel: levels[7].worldLevel) == 2)
            #expect(
                CampaignBalance.cumulativeLandmarkCount(for: levels[4])
                    == CampaignBalance.cumulativeLandmarkCount(for: levels[3]) + 1
            )
            #expect(
                CampaignBalance.cumulativeLandmarkCount(for: levels[7])
                    == CampaignBalance.cumulativeLandmarkCount(for: levels[6]) + 1
            )
            #expect(
                CampaignBalance.cumulativeLandmarkCount(for: levels[9])
                    == CampaignBalance.cumulativeLandmarkCount(for: levels[8]) + 1
            )
            #expect(averageEnemyHitPoints(fifth, level: levels[4])
                    > averageEnemyHitPoints(fourth, level: levels[3]))
            #expect(averageEnemyHitPoints(eighth, level: levels[7])
                    > averageEnemyHitPoints(seventh, level: levels[6]))
            #expect(averageEnemyHitPoints(finale, level: levels[9])
                    > averageEnemyHitPoints(ninth, level: levels[8]))
            #expect(fifth.damageMultiplier > fourth.damageMultiplier)
            #expect(eighth.damageMultiplier > seventh.damageMultiplier)
            #expect(finale.damageMultiplier > ninth.damageMultiplier)
            #expect(
                fifth.spawnInterval
                    / Double(CampaignBalance.enemyPackSize(wave: 1, for: levels[4]))
                    < fourth.spawnInterval
                        / Double(CampaignBalance.enemyPackSize(wave: 1, for: levels[3]))
            )
            #expect(
                eighth.spawnInterval
                    / Double(CampaignBalance.enemyPackSize(wave: 1, for: levels[7]))
                    < seventh.spawnInterval
                        / Double(CampaignBalance.enemyPackSize(wave: 1, for: levels[6]))
            )
            #expect(
                finale.spawnInterval
                    / Double(CampaignBalance.enemyPackSize(wave: 1, for: levels[9]))
                    < ninth.spawnInterval
                        / Double(CampaignBalance.enemyPackSize(wave: 1, for: levels[8]))
            )
        }
    }

    @Test func moonReadyBuildTakesSevereDamageWhenItSkipsToUranus() {
        var moonReadyProgress = PlayerProgress.newPlayer
        for track in UpgradeTrack.allCases {
            moonReadyProgress.setRank(5, for: track)
        }

        func escapedEnemyDamage(levelNumber: Int, id: Int) -> Double {
            let level = GameContent.level(levelNumber)
            let simulation = GameSimulation(
                level: level,
                progress: moonReadyProgress,
                assistMode: false,
                seed: UInt64(levelNumber)
            )
            let startingStamina = simulation.snapshot.stamina
            simulation.replaceTargetsForTesting([
                TargetState(
                    id: id,
                    kind: .enemy(level.enemies[0]),
                    position: .init(x: 0.70, y: 0.121),
                    hitPoints: 10_000,
                    maximumHitPoints: 10_000,
                    phase: 0,
                    waveRole: .quota
                )
            ])
            _ = simulation.update(delta: 0.05)
            return startingStamina - simulation.snapshot.stamina
        }

        let moonDamage = escapedEnemyDamage(levelNumber: 11, id: 20_011)
        let uranusDamage = escapedEnemyDamage(levelNumber: 51, id: 20_051)

        #expect(uranusDamage > moonDamage * 2)
        #expect(uranusDamage > 13.5)
    }

    @Test func campaignEnemyQuotasScaleAcrossWavesLevelsAndWorlds() {
        #expect(CampaignBalance.wave(1, for: GameContent.level(1)).enemyQuota == 18)
        #expect(CampaignBalance.wave(1, for: GameContent.level(11)).enemyQuota == 41)
        #expect(CampaignBalance.wave(1, for: GameContent.level(21)).enemyQuota == 64)
        #expect(CampaignBalance.wave(1, for: GameContent.level(30)).enemyQuota == 82)
        #expect(CampaignBalance.wave(1, for: GameContent.level(70)).enemyQuota == 174)

        var previousOpeningQuota = 0
        for level in GameContent.levels {
            let openingQuota = CampaignBalance.wave(1, for: level).enemyQuota
            #expect(openingQuota > previousOpeningQuota)
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

    @Test func campaignPacksAndActiveCapsGrowIntoBoundedHordes() {
        #expect(CampaignBalance.enemyPackSize(
            wave: 1,
            for: GameContent.level(1)
        ) == 1)
        #expect(CampaignBalance.enemyPackSize(
            wave: 1,
            for: GameContent.level(5)
        ) == 2)
        #expect(CampaignBalance.enemyPackSize(
            wave: 1,
            for: GameContent.level(20)
        ) == 5)
        #expect(CampaignBalance.enemyPackSize(
            wave: 1,
            for: GameContent.level(51)
        ) == 6)
        #expect(CampaignBalance.enemyPackSize(
            wave: 4,
            for: GameContent.level(70)
        ) == 13)

        #expect(CampaignBalance.maximumActiveEnemies(
            wave: 1,
            for: GameContent.level(1)
        ) == 6)
        #expect(CampaignBalance.maximumActiveEnemies(
            wave: 5,
            for: GameContent.level(10)
        ) == 20)
        #expect(CampaignBalance.maximumActiveEnemies(
            wave: 5,
            for: GameContent.level(30)
        ) == 30)
        #expect(CampaignBalance.maximumActiveEnemies(
            wave: 5,
            for: GameContent.level(70)
        ) == 48)
        #expect(CampaignBalance.maximumHostileProjectiles(
            wave: 1,
            for: GameContent.level(1)
        ) == 3)
        #expect(CampaignBalance.maximumHostileProjectiles(
            wave: 1,
            for: GameContent.level(51)
        ) == 6)
        #expect(CampaignBalance.maximumHostileProjectiles(
            wave: 5,
            for: GameContent.level(70)
        ) == 10)

        #expect(EndlessRules.maximumActiveEnemies(wave: 1) == 7)
        #expect(EndlessRules.maximumActiveEnemies(wave: 21) == 13)
        #expect(EndlessRules.maximumActiveEnemies(wave: 100) == 24)
        #expect(EndlessRules.maximumHostileProjectiles(wave: 1) == 4)
        #expect(EndlessRules.maximumHostileProjectiles(wave: 30) == 9)
        #expect(EndlessRules.maximumHostileProjectiles(wave: 100) == 12)
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

    @Test func campaignHostileProjectilesRespectTheReadableHordeCap() {
        let level = GameContent.level(70)
        let simulation = GameSimulation(
            level: level,
            progress: .newPlayer,
            assistMode: false,
            seed: 103
        )
        simulation.setCampaignWaveForTesting(level.waveCount)
        let cap = CampaignBalance.maximumHostileProjectiles(
            wave: level.waveCount,
            for: level
        )

        for index in 0..<(cap + 5) {
            simulation.spawnHostileProjectileForTesting(
                x: Double(index).truncatingRemainder(dividingBy: 3) * 0.2,
                y: 0.80
            )
        }

        #expect(simulation.snapshot.projectiles.count(where: \.hostile) == cap)
    }

    @Test func lateCampaignSpawningStreamsOneEnemyAtATime() {
        let level = GameContent.level(51)
        let simulation = GameSimulation(
            level: level,
            progress: .newPlayer,
            assistMode: false,
            seed: 102
        )
        let interval = CampaignBalance.wave(1, for: level).spawnInterval
        #expect(interval > CampaignBalance.maximumEmptyFieldSpawnDelay)

        for _ in 0..<Int(
            (CampaignBalance.maximumEmptyFieldSpawnDelay / 0.05).rounded(.up)
        ) + 2 {
            _ = simulation.update(delta: 0.05)
        }

        let quotaEnemies = simulation.snapshot.targets.filter {
            if case .enemy = $0.kind { $0.waveRole == .quota } else { false }
        }
        #expect(
            quotaEnemies.count == 1
        )
        for _ in 0..<Int(
            (CampaignBalance.enemyStaggerInterval / 0.05).rounded(.up)
        ) {
            _ = simulation.update(delta: 0.05)
        }
        #expect(simulation.snapshot.targets.count {
            if case .enemy = $0.kind { $0.waveRole == .quota } else { false }
        } == 2)
    }

    @Test func powerfulCampaignBuildNeverWaitsLongOnAnEmptyField() {
        let level = GameContent.level(10)
        let simulation = GameSimulation(
            level: level,
            progress: .newPlayer,
            assistMode: false,
            seed: 10
        )
        let interval = CampaignBalance.wave(1, for: level).spawnInterval
        #expect(interval > CampaignBalance.maximumEmptyFieldSpawnDelay)

        let allowedFrames = Int(
            (CampaignBalance.maximumEmptyFieldSpawnDelay / 0.05).rounded(.up)
        ) + 2
        for _ in 0..<8 {
            simulation.replaceTargetsForTesting([])
            var emptyFrames = 0
            while emptyFrames < allowedFrames,
                  !simulation.snapshot.targets.contains(where: {
                      if case .enemy = $0.kind { $0.waveRole == .quota } else { false }
                  }) {
                _ = simulation.update(delta: 0.05)
                emptyFrames += 1
            }
            #expect(emptyFrames <= allowedFrames)
            #expect(simulation.snapshot.targets.count {
                if case .enemy = $0.kind { $0.waveRole == .quota } else { false }
            } == 1)
        }
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

        let events = simulation.update(delta: 0.05)

        #expect(simulation.snapshot.targetsDefeated == 1)
        #expect(simulation.snapshot.waveDefeats == 0)
        #expect(simulation.snapshot.remainingEnemies == simulation.snapshot.waveEnemyQuota)
        #expect(simulation.snapshot.tokens == 0)
        #expect(simulation.snapshot.score > 0)
        #expect(simulation.snapshot.combo == 1)
        #expect(!events.contains {
            if case .reward = $0 { true } else { false }
        })
    }

    @Test func endlessQuotasGrowAndEveryFifthWaveUsesABossObjective() {
        #expect(EndlessRules.enemyQuota(wave: 1) == 18)
        #expect(EndlessRules.enemyQuota(wave: 11) == 36)
        #expect(EndlessRules.enemyQuota(wave: 21) == 54)
        #expect(EndlessRules.enemyQuota(wave: 30) == 67)
        #expect(EndlessRules.enemyQuota(wave: 31) == 72)
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
        #expect(EndlessRules.world(for: 31) == .jupiter)
        #expect(EndlessRules.world(for: 41) == .saturn)
        #expect(EndlessRules.world(for: 51) == .uranus)
        #expect(EndlessRules.world(for: 61) == .neptune)
        #expect(EndlessRules.world(for: 70) == .neptune)
        #expect(EndlessRules.world(for: 71) == .earth)
        #expect(EndlessRules.waveInWorld(for: 31) == 1)
        #expect(EndlessRules.chapterIndex(for: 31) == 3)
        #expect(EndlessRules.worldTransition(after: 9) == nil)
        #expect(EndlessRules.worldTransition(after: 10)?.from == .earth)
        #expect(EndlessRules.worldTransition(after: 10)?.to == .moon)
        #expect(EndlessRules.worldTransition(after: 30)?.to == .jupiter)
        #expect(EndlessRules.worldTransition(after: 70)?.to == .earth)
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

    @Test func campaignBossReinforcementsContinuouslyRefillAndNeverCount() {
        let level = GameContent.level(10)
        let simulation = GameSimulation(
            level: level,
            progress: .newPlayer,
            assistMode: false,
            seed: 107
        )
        simulation.setCampaignWaveForTesting(level.waveCount)

        _ = simulation.update(delta: 0.01)
        guard var boss = simulation.snapshot.targets.first(where: {
            $0.waveRole == .boss
        }) else {
            Issue.record("Expected the world boss to spawn immediately")
            return
        }
        boss.maximumHitPoints = 1_000_000_000
        boss.hitPoints = 1_000_000_000
        boss.freezeRemaining = 30
        simulation.replaceTargetsForTesting([boss])

        for _ in 0..<35 {
            _ = simulation.update(delta: 0.05)
        }
        #expect(simulation.snapshot.targets.contains {
            $0.waveRole == .reinforcement
        })
        #expect(simulation.snapshot.waveDefeats == 0)
        #expect(simulation.snapshot.remainingEnemies == 1)

        guard let currentBoss = simulation.snapshot.targets.first(where: {
            $0.waveRole == .boss
        }) else {
            Issue.record("Expected the boss to remain active")
            return
        }
        simulation.replaceTargetsForTesting([currentBoss])
        var refillFramesRemaining = 80
        while refillFramesRemaining > 0,
              !simulation.snapshot.targets.contains(where: {
                  $0.waveRole == .reinforcement
              }) {
            _ = simulation.update(delta: 0.05)
            refillFramesRemaining -= 1
        }
        #expect(simulation.snapshot.targets.contains {
            $0.waveRole == .reinforcement
        })
        #expect(simulation.snapshot.remainingEnemies == 1)
    }

    @Test func endlessBossReinforcementsArriveInFiniteHealthTriggeredWaves() {
        let simulation = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: false,
            seed: 108
        )
        simulation.setEndlessWaveForTesting(5)
        _ = simulation.update(delta: 0.01)
        guard var boss = simulation.snapshot.targets.first(where: {
            $0.waveRole == .boss
        }) else {
            Issue.record("Expected the Endless boss to spawn immediately")
            return
        }
        boss.maximumHitPoints = 1_000_000_000
        boss.hitPoints = 1_000_000_000
        boss.freezeRemaining = 60
        simulation.replaceTargetsForTesting([boss])

        for _ in 0..<35 {
            _ = simulation.update(delta: 0.05)
        }
        #expect(
            simulation.snapshot.targets.count(where: {
                $0.waveRole == .reinforcement
            }) == EndlessRules.bossReinforcementWaveSize(wave: 5)
        )

        guard var currentBoss = simulation.snapshot.targets.first(where: {
            $0.waveRole == .boss
        }) else {
            Issue.record("Expected the Endless boss to remain active")
            return
        }
        simulation.replaceTargetsForTesting([currentBoss])
        for _ in 0..<120 {
            _ = simulation.update(delta: 0.05)
        }
        #expect(!simulation.snapshot.targets.contains {
            $0.waveRole == .reinforcement
        })

        currentBoss.hitPoints = currentBoss.maximumHitPoints * 0.65
        simulation.replaceTargetsForTesting([currentBoss])
        _ = simulation.update(delta: 0.05)
        _ = simulation.update(delta: 0.05)
        #expect(
            simulation.snapshot.targets.count(where: {
                $0.waveRole == .reinforcement
            }) == EndlessRules.bossReinforcementWaveSize(wave: 5)
        )
        #expect(simulation.snapshot.waveDefeats == 0)
        #expect(simulation.snapshot.remainingEnemies == 1)
    }

    @Test func bossReinforcementsSpawnAcrossTheFieldInsteadOfCenterLane() {
        let level = GameContent.level(10)
        let simulation = GameSimulation(
            level: level,
            progress: .newPlayer,
            assistMode: false,
            seed: 8_701
        )
        simulation.setCampaignWaveForTesting(level.waveCount)
        _ = simulation.update(delta: 0.01)
        guard var boss = simulation.snapshot.targets.first(where: {
            $0.waveRole == .boss
        }) else {
            Issue.record("Expected the world boss to spawn immediately")
            return
        }
        boss.maximumHitPoints = 1_000_000_000
        boss.hitPoints = 1_000_000_000
        boss.freezeRemaining = 60
        simulation.replaceTargetsForTesting([boss])

        var observedIDs = Set<Int>()
        var observedSpawnXs: [Double] = []
        for _ in 0..<700 {
            _ = simulation.update(delta: 0.05)
            for target in simulation.snapshot.targets
                where target.waveRole == .reinforcement
                    && !observedIDs.contains(target.id) {
                observedIDs.insert(target.id)
                observedSpawnXs.append(target.position.x)
            }
            simulation.replaceTargetsForTesting(
                simulation.snapshot.targets.filter {
                    $0.waveRole != .reinforcement
                }
            )
        }

        #expect(observedSpawnXs.count >= 12)
        #expect(observedSpawnXs.allSatisfy { (-0.77...0.77).contains($0) })
        #expect((observedSpawnXs.min() ?? 0) < -0.40)
        #expect((observedSpawnXs.max() ?? 0) > 0.40)
        #expect(
            Set(observedSpawnXs.map { Int(($0 * 100).rounded()) }).count >= 8
        )
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

        func removeBossSupport() {
            simulation.replaceTargetsForTesting(
                simulation.snapshot.targets.filter {
                    $0.waveRole != .reinforcement
                }
            )
        }

        for _ in 0..<139 {
            _ = simulation.update(delta: 0.05)
            removeBossSupport()
        }
        #expect(!simulation.snapshot.targets.contains {
            if case .powerUp = $0.kind { true } else { false }
        })

        let firstSpawnEvents = simulation.update(delta: 0.05)
        removeBossSupport()
        let firstPowerUpAppeared = simulation.snapshot.targets.contains {
            if case .powerUp = $0.kind { true } else { false }
        } || firstSpawnEvents.contains {
            if case .temporaryAbilityActivated = $0 { true } else { false }
        }
        #expect(firstPowerUpAppeared)

        guard let currentBoss = simulation.snapshot.targets.first(where: { $0.waveRole == .boss }) else {
            #expect(Bool(false), "Expected the boss to remain active")
            return
        }
        simulation.replaceTargetsForTesting([currentBoss])

        var earlyIntervalEvents: [SimulationEvent] = []
        for _ in 0..<319 {
            earlyIntervalEvents.append(contentsOf: simulation.update(delta: 0.05))
            removeBossSupport()
        }
        #expect(!simulation.snapshot.targets.contains {
            if case .powerUp = $0.kind { true } else { false }
        })
        #expect(!earlyIntervalEvents.contains {
            if case .temporaryAbilityActivated = $0 { true } else { false }
        })

        var secondSpawnEvents: [SimulationEvent] = []
        for _ in 0..<2 {
            secondSpawnEvents.append(contentsOf: simulation.update(delta: 0.05))
            removeBossSupport()
        }
        let secondPowerUpAppeared = simulation.snapshot.targets.contains {
            if case .powerUp = $0.kind { true } else { false }
        } || secondSpawnEvents.contains {
            if case .temporaryAbilityActivated = $0 { true } else { false }
        }
        #expect(secondPowerUpAppeared)
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

    @Test func everyOuterWorldHazardActivatesFromArenaCadence() {
        let cases: [(level: Int, rule: WorldRule, hazard: BossAttackKind)] = [
            (31, .windShear, .windRail),
            (41, .ringSweep, .ringSegment),
            (51, .cryoDrift, .frozenRail),
            (61, .pressureTide, .pressureWall),
        ]

        for item in cases {
            var progress = PlayerProgress.newPlayer
            progress.setRank(100, for: .conditioning)
            let simulation = GameSimulation(
                level: GameContent.level(item.level),
                progress: progress,
                assistMode: false,
                seed: UInt64(item.level)
            )
            var events: [SimulationEvent] = []
            for _ in 0..<360 where
                !events.contains(where: {
                    if case .worldEffectActivated(let rule, _) = $0 {
                        rule == item.rule
                    } else {
                        false
                    }
                }) {
                events.append(contentsOf: simulation.update(delta: 0.05))
                simulation.replaceTargetsForTesting(
                    simulation.snapshot.targets.filter {
                        if case .enemy = $0.kind { false } else { true }
                    }
                )
            }

            #expect(events.contains(where: {
                if case .worldEffectActivated(let rule, _) = $0 {
                    rule == item.rule
                } else {
                    false
                }
            }))
            #expect(simulation.snapshot.bossHazards.contains { $0.kind == item.hazard })
        }
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

        for _ in 0..<205 where !simulation.snapshot.bossHazards.contains(where: {
            $0.kind == .lunarDebris
        }) {
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
            Issue.record("Expected lunar debris at the level-scaled cadence")
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

    @Test func moonAcceleratesHostileProjectilesWithoutHazardSlowdown() {
        let level = GameContent.level(11)
        let moon = GameSimulation(
            level: level,
            progress: .newPlayer,
            assistMode: false,
            seed: 21
        )
        moon.spawnHostileProjectileForTesting(x: 0.8, y: 0.60)
        _ = moon.update(delta: 0.05)

        let expectedY = 0.60
            - 0.38
                * CampaignBalance.hostileProjectileSpeedMultiplier(
                    level: level,
                    wave: 1
                )
                * 0.05
        #expect(abs((moon.snapshot.projectiles.first?.position.y ?? 0) - expectedY) < 0.0001)
        #expect(expectedY < 0.581)
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

    @Test func campaignReferenceBuildAndBossPressureEscalateAcrossAllWorlds() {
        let expectedFinalRanks = [4.0, 5, 7, 9, 11, 13, 15]
        var previousFinalRank = 0.0
        var previousBossHealth = 0.0
        for (index, world) in WorldID.allCases.enumerated() {
            let levels = GameContent.levels(in: world)
            let opening = levels[0]
            let finale = levels[9]
            let finalRank = CampaignBalance.targetPermanentRank(for: finale)
            let bossHealth = CampaignBalance.bossHitPoints(
                tier: .megaBoss,
                wave: finale.waveCount,
                for: finale
            )

            #expect(finalRank == expectedFinalRanks[index])
            #expect(finalRank > previousFinalRank)
            #expect(bossHealth > previousBossHealth)
            #expect(CampaignBalance.referenceSingleTargetDPS(for: finale)
                    > CampaignBalance.referenceSingleTargetDPS(for: opening))
            if index > 0 {
                #expect(CampaignBalance.targetPermanentRank(for: opening)
                        > previousFinalRank)
            }
            previousFinalRank = finalRank
            previousBossHealth = bossHealth
        }
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

    @Test func zeroStaminaDefeatPrecedesASameFrameBossClear() {
        let level = GameContent.level(8)
        let simulation = GameSimulation(
            level: level,
            progress: .newPlayer,
            assistMode: true,
            seed: 90
        )
        simulation.setCampaignWaveForTesting(level.waveCount)
        simulation.replaceTargetsForTesting([
            TargetState(
                id: 9_702,
                kind: .enemy(.ballLauncher),
                position: .init(x: 0, y: 0.21),
                hitPoints: 1,
                maximumHitPoints: 1,
                phase: 0,
                bossTier: .miniBoss
            ),
        ])
        simulation.setStaminaForTesting(0.5)
        simulation.spawnFriendlyProjectileForTesting(pierce: 0)
        simulation.spawnHostileProjectileForTesting(
            x: simulation.snapshot.playerX,
            y: 0.16,
            damage: 100
        )

        let events = simulation.update(delta: 0.05)

        #expect(simulation.snapshot.stamina == 0)
        #expect(events.contains(.finished(false)))
        #expect(!events.contains(.finished(true)))
        #expect(!events.contains(.waveCompleted(level.waveCount)))
    }

    @Test func endlessDifficultyContinuesGrowingAtHighWaves() {
        #expect(EndlessRules.healthMultiplier(wave: 100) > EndlessRules.healthMultiplier(wave: 10))
        #expect(EndlessRules.healthMultiplier(wave: 1_000) > EndlessRules.healthMultiplier(wave: 100))
        #expect(EndlessRules.damageMultiplier(wave: 1_000) > EndlessRules.damageMultiplier(wave: 100))
        #expect(EndlessRules.speedMultiplier(wave: 1_000) > EndlessRules.speedMultiplier(wave: 100))
        #expect(
            EndlessRules.attackCadenceMultiplier(wave: 1_000)
                < EndlessRules.attackCadenceMultiplier(wave: 100)
        )
        #expect(
            EndlessRules.hostileProjectileSpeedMultiplier(wave: 1_000)
                > EndlessRules.hostileProjectileSpeedMultiplier(wave: 100)
        )
        #expect(EndlessRules.spawnInterval(wave: 10_000) == 0.22)
        #expect(EndlessRules.packSize(wave: 10_000) == 6)
        #expect(EndlessRules.maximumActiveEnemies(wave: 10_000) == 24)
        #expect(EndlessRules.maximumHostileProjectiles(wave: 10_000) == 12)
    }

    @Test func endlessWaveThirtyKeepsCrowdPressureWithSofterDurability() {
        let health = EndlessRules.healthMultiplier(wave: 30)
        let damage = EndlessRules.damageMultiplier(wave: 30)

        #expect(abs(health - 17.001) < 0.002)
        #expect(abs(damage - 3.344) < 0.002)
        #expect(EndlessRules.healthMultiplier(wave: 31) > health)
        #expect(EndlessRules.damageMultiplier(wave: 31) > damage)
        #expect(EndlessRules.enemyQuota(wave: 30) == 67)
        #expect(EndlessRules.maximumActiveEnemies(wave: 30) == 16)
        #expect(EndlessRules.maximumHostileProjectiles(wave: 30) == 9)
        #expect(EndlessRules.packSize(wave: 30) == 5)
        #expect(EndlessRules.spawnInterval(wave: 30) < 0.34)
        #expect(EndlessRules.attackCadenceMultiplier(wave: 30) < 0.58)
        #expect(EndlessRules.hostileProjectileSpeedMultiplier(wave: 30) > 1.52)
    }

    @Test func endlessBossDurabilityStartsFairAndContinuesScaling() {
        #expect(abs(EndlessRules.bossHealthMultiplier(wave: 5) - 0.70) < 0.000_001)
        #expect(
            EndlessRules.bossHealthMultiplier(wave: 30)
                > EndlessRules.bossHealthMultiplier(wave: 5)
        )
        #expect(
            EndlessRules.bossHealthMultiplier(wave: 1_000)
                > EndlessRules.bossHealthMultiplier(wave: 100)
        )
        #expect(EndlessRules.bossReinforcementWaveSize(wave: 5) == 2)
        #expect(EndlessRules.bossDirectDamageWindow(wave: 5) == 5)

        let simulation = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: false,
            seed: 5
        )
        simulation.setEndlessWaveForTesting(5)
        _ = simulation.update(delta: 0.01)

        let boss = simulation.snapshot.targets.first {
            $0.waveRole == .boss
        }
        let expectedHealth = CombatBalance.baseHealth(.titanKeeper)
            * EndlessRules.healthMultiplier(wave: 5)
            * EndlessRules.bossHealthMultiplier(wave: 5)
        #expect(abs((boss?.maximumHitPoints ?? 0) - expectedHealth) < 0.001)
        #expect((boss?.maximumHitPoints ?? .infinity) < 1_000)
    }

    @Test func endlessHostileProjectilesRespectTheReadableWaveCap() {
        let simulation = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: false,
            seed: 1_930
        )
        simulation.setEndlessWaveForTesting(30)

        for index in 0..<20 {
            simulation.spawnHostileProjectileForTesting(
                x: Double(index) * 0.01,
                y: 0.80
            )
        }

        #expect(
            simulation.snapshot.projectiles.count(where: \.hostile)
                == EndlessRules.maximumHostileProjectiles(wave: 30)
        )
    }

    @Test func endlessStartingPowerOnlyPartiallyCountersPermanentUpgrades() {
        let baseline = PlayerStats(progress: .newPlayer, mode: .endless)
        var progress = PlayerProgress.newPlayer
        for track in UpgradeTrack.allCases {
            progress.setRank(5, for: track)
        }
        let upgraded = PlayerStats(progress: progress, mode: .endless)

        let baselineOffense = EndlessRules.startingOffenseFactor(stats: baseline)
        let upgradedOffense = EndlessRules.startingOffenseFactor(stats: upgraded)
        let rawOffenseRatio = (
            (upgraded.ballDamage / baseline.ballDamage)
                * ((1 + upgraded.criticalChance) / (1 + baseline.criticalChance))
                * (baseline.kickCooldown / upgraded.kickCooldown)
        )
        let upgradedSurvival = EndlessRules.startingSurvivalFactor(
            stats: upgraded
        )

        #expect(abs(baselineOffense - 1) < 0.000_001)
        #expect(upgradedOffense > 1)
        #expect(upgradedOffense < rawOffenseRatio)
        #expect(abs(upgradedOffense * upgradedOffense - rawOffenseRatio) < 0.000_001)
        #expect(upgradedSurvival > 1)
        #expect(upgradedSurvival < upgraded.maxStamina / baseline.maxStamina)

        let baselineWave30 = EndlessRules.healthMultiplier(wave: 30)
        let upgradedWave30 = EndlessRules.healthMultiplier(
            wave: 30,
            startingOffenseFactor: upgradedOffense
        )
        #expect(abs(upgradedWave30 / baselineWave30 - upgradedOffense) < 0.000_001)
    }

    @Test func upgradedWaveThirtyBuildCannotClearWhileStandingStill() {
        let relicID = UUID(uuidString: "F2411AB8-9AB3-4FE9-8B51-68CCDB35D130")!
        let relic = EndlessRelic(
            id: relicID,
            acquiredAt: Date(timeIntervalSince1970: 0),
            sourceWaveMilestone: 30,
            rarity: .rare,
            primaryStat: .attackDamage,
            affixes: [
                .init(stat: .attackDamage, basisPoints: 1_000),
                .init(stat: .maximumStamina, basisPoints: 1_000),
            ]
        )
        var progress = PlayerProgress.newPlayer
        for track in UpgradeTrack.allCases {
            progress.setRank(5, for: track)
        }
        progress.endlessRecord.relics = [relic]
        progress.endlessRecord.equippedRelicID = relicID

        let simulation = GameSimulation(
            mode: .endless,
            progress: progress,
            assistMode: false,
            seed: 30
        )
        let coreRanks: [(AbilityKind, Int)] = [
            (.powerDrive, 4),
            (.quickRelease, 4),
            (.throughBall, 2),
            (.curler, 2),
            (.oneTwo, 3),
            (.cleanSheet, 1),
            (.secondWind, 1),
            (.gravityBoots, 1),
            (.meteorStrike, 2),
        ]
        for (ability, rank) in coreRanks {
            for _ in 0..<rank { simulation.apply(ability) }
        }
        for ability in EndlessSpecialBallRules.abilities {
            simulation.apply(.specialBall(ability))
        }
        simulation.setEndlessWaveForTesting(30)

        var clearedWaveThirty = false
        var wasDefeated = false
        for _ in 0..<2_400 where !clearedWaveThirty && !wasDefeated {
            let events = simulation.update(delta: 0.05)
            clearedWaveThirty = events.contains(.waveCompleted(30))
            wasDefeated = events.contains(.finished(false))
        }

        #expect(wasDefeated)
        #expect(!clearedWaveThirty)
    }

    @Test func endlessTokenGrowthIsUncappedSublinearAndGoldenGoalDiminishes() {
        let wave10 = EconomyBalance.endlessWaveRewardMultiplier(wave: 10)
        let wave100 = EconomyBalance.endlessWaveRewardMultiplier(wave: 100)
        let wave1_000 = EconomyBalance.endlessWaveRewardMultiplier(wave: 1_000)
        #expect(wave10 > 1)
        #expect(wave100 > wave10)
        #expect(wave1_000 > wave100)
        #expect(wave100 / wave10 < 10)

        let golden1 = EconomyBalance.goldenGoalMultiplier(rank: 1)
        let golden5 = EconomyBalance.goldenGoalMultiplier(rank: 5)
        let golden100 = EconomyBalance.goldenGoalMultiplier(rank: 100)
        #expect(golden1 > 1)
        #expect(golden5 > golden1)
        #expect(golden100 > golden5)
        #expect(golden5 - golden1 > golden100 - EconomyBalance.goldenGoalMultiplier(rank: 96))

        let through10 = EconomyBalance.expectedEndlessTokens(throughWave: 10)
        let through20 = EconomyBalance.expectedEndlessTokens(throughWave: 20)
        let through30 = EconomyBalance.expectedEndlessTokens(throughWave: 30)
        let through100 = EconomyBalance.expectedEndlessTokens(throughWave: 100)
        #expect(through10 >= 1_600 && through10 <= 1_800)
        #expect(through20 >= 4_500 && through20 <= 5_000)
        #expect(through30 > through10)
        #expect(through100 > through30)
        #expect(EconomyBalance.expectedEndlessTokens(
            throughWave: 30,
            goldenGoalRank: 5
        ) > through30)
    }

    @Test func endlessEnemyTokensStepAtWorldsAndWorldClearsPayMeaningfully() {
        func lowEnemyReward(wave: Int) -> Int {
            EconomyBalance.enemyTokenReward(
                baseValue: 2,
                isEndless: true,
                wave: wave,
                campaignLevel: 1,
                campaignCycle: 0,
                goldenGoalRank: 0
            )
        }

        #expect(lowEnemyReward(wave: 10) == 2)
        #expect(lowEnemyReward(wave: 11) == 3)
        #expect(lowEnemyReward(wave: 21) == 4)
        #expect(EndlessRules.waveClearTokenBase(wave: 9) == 18)
        #expect(EndlessRules.waveClearTokenBase(wave: 10) == 345)
        #expect(EndlessRules.waveClearTokenBase(wave: 20) == 365)
    }

    @Test func campaignEnemyTokensFollowContentPressureInsteadOfOwnedRanks() {
        let earthOpening = EconomyBalance.campaignEnemyRewardMultiplier(
            levelNumber: 1,
            cycle: 0
        )
        let marsTrial = EconomyBalance.campaignEnemyRewardMultiplier(
            levelNumber: 29,
            cycle: 0
        )
        let newGamePlusOpening = EconomyBalance.campaignEnemyRewardMultiplier(
            levelNumber: 1,
            cycle: 1
        )

        #expect(earthOpening == 1)
        #expect(marsTrial > earthOpening)
        #expect(newGamePlusOpening > marsTrial)
        #expect(
            EconomyBalance.enemyTokenReward(
                baseValue: 8,
                isEndless: false,
                wave: 1,
                campaignLevel: 70,
                campaignCycle: 0,
                goldenGoalRank: 0
            ) > 8
        )
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

    @Test func characterAbilityChargeIsQuotaNormalized() {
        for quota in [18, 99, 255] {
            let enemyCharge = CharacterAbilityChargeBalance.enemyDefeatCharge(
                referenceQuota: quota
            )
            #expect(abs(
                enemyCharge * Double(quota)
                    - CharacterAbilityChargeBalance.fullCharge
                        * CharacterAbilityChargeBalance.targetChargesPerWave
            ) < 0.001)
            #expect(abs(
                CharacterAbilityChargeBalance.fieldObjectDefeatCharge(
                    referenceQuota: quota
                )
                    - enemyCharge
                        * CharacterAbilityChargeBalance.fieldObjectChargeFraction
            ) < 0.001)
        }

        #expect(abs(
            CharacterAbilityChargeBalance.bossDamageCharge(
                damage: 40,
                maximumHitPoints: 100
            ) - 20
        ) < 0.001)
        #expect(abs(
            CharacterAbilityChargeBalance.bossDamageCharge(
                damage: 150,
                maximumHitPoints: 100
            ) - CharacterAbilityChargeBalance.bossDamageChargeBudget
        ) < 0.001)
    }

    @Test func enemyObjectReinforcementAndBossAllContributeCharge() {
        func chargeAfterDefeating(_ target: TargetState) -> Double {
            let simulation = GameSimulation(
                level: GameContent.level(1),
                progress: .newPlayer,
                assistMode: false,
                seed: 801
            )
            simulation.replaceTargetsForTesting([target])
            simulation.spawnFriendlyProjectileForTesting(pierce: 0)
            _ = simulation.update(delta: 0.01)
            return simulation.snapshot.characterAbilityCharge
        }

        let enemyCharge = chargeAfterDefeating(TargetState(
            id: 18_001,
            kind: .enemy(.coneRunner),
            position: .init(x: 0, y: 0.18),
            hitPoints: 1,
            maximumHitPoints: 1,
            phase: 0
        ))
        let objectCharge = chargeAfterDefeating(TargetState(
            id: 18_002,
            kind: .fieldObject(.ballCart),
            position: .init(x: 0, y: 0.18),
            hitPoints: 1,
            maximumHitPoints: 1,
            phase: 0
        ))
        let reinforcementCharge = chargeAfterDefeating(TargetState(
            id: 18_003,
            kind: .enemy(.coneRunner),
            position: .init(x: 0, y: 0.18),
            hitPoints: 1,
            maximumHitPoints: 1,
            phase: 0,
            waveRole: .reinforcement
        ))

        let expectedEnemyCharge =
            CharacterAbilityChargeBalance.enemyDefeatCharge(referenceQuota: 18)
        #expect(abs(enemyCharge - expectedEnemyCharge) < 0.001)
        #expect(abs(
            objectCharge
                - expectedEnemyCharge
                    * CharacterAbilityChargeBalance.fieldObjectChargeFraction
        ) < 0.001)
        #expect(abs(reinforcementCharge - expectedEnemyCharge) < 0.001)

        let bossCharge = chargeAfterDefeating(TargetState(
            id: 18_004,
            kind: .enemy(.titanKeeper),
            position: .init(x: 0, y: 0.18),
            hitPoints: 10,
            maximumHitPoints: 10,
            phase: 0,
            bossTier: .megaBoss,
            waveRole: .boss
        ))
        #expect(abs(
            bossCharge - CharacterAbilityChargeBalance.bossDamageChargeBudget
        ) < 0.001)
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
            #expect(simulation.snapshot.characterAbilityDefeats == 1)
            #expect(simulation.snapshot.characterAbilityCharge == 0)
            #expect(!simulation.snapshot.characterAbilityReady)
        }
    }

    @Test func everyCharacterPowerCreditsActualEnemyDefeats() {
        let cases: [(CharacterID, Vector2, Int)] = [
            (.ace, .init(x: -0.07, y: 0.18), 2),
            (.volt, .init(x: 0.60, y: 0.55), 115),
            (.nova, .init(x: 0.60, y: 0.55), 35),
            (.aegis, .init(x: 0, y: 0.20), 8),
            (.gale, .init(x: 0.52, y: 0.24), 10),
            (.halo, .init(x: 0.72, y: 0.18), 60),
            (.flux, .init(x: 0.60, y: 0.52), 120),
            (.surge, .init(x: 0.60, y: 0.50), 60),
        ]

        for (index, abilityCase) in cases.enumerated() {
            let (characterID, position, updateCount) = abilityCase
            var progress = PlayerProgress.newPlayer
            progress.selectedCharacter = characterID
            progress.unlockedCharacters.insert(characterID)
            let simulation = GameSimulation(
                level: GameContent.level(1),
                progress: progress,
                assistMode: false,
                seed: UInt64(9_500 + index)
            )
            var enemy = TargetState(
                id: 9_500 + index,
                kind: .enemy(.coneRunner),
                position: position,
                hitPoints: 1,
                maximumHitPoints: 1,
                phase: 0
            )
            enemy.waveRole = .reinforcement
            enemy.freezeRemaining = 30
            simulation.replaceTargetsForTesting([enemy])
            simulation.fullyChargeCharacterAbilityForTesting()

            _ = simulation.activateCharacterAbility()
            for _ in 0..<updateCount {
                _ = simulation.update(delta: 0.05)
            }

            #expect(
                simulation.snapshot.characterAbilityDefeats >= 1,
                "\(characterID.rawValue) did not receive defeat credit"
            )
        }
    }

    @Test func characterPowerDoesNotCreditDestroyedFieldObjectsAsEnemyDefeats() {
        var progress = PlayerProgress.newPlayer
        progress.selectedCharacter = .aegis
        progress.unlockedCharacters.insert(.aegis)
        let simulation = GameSimulation(
            level: GameContent.level(1),
            progress: progress,
            assistMode: false,
            seed: 9_600
        )
        let fieldObject = TargetState(
            id: 9_600,
            kind: .fieldObject(.ballCart),
            position: .init(x: 0, y: 0.20),
            hitPoints: 1,
            maximumHitPoints: 1,
            phase: 0
        )
        simulation.replaceTargetsForTesting([fieldObject])
        simulation.fullyChargeCharacterAbilityForTesting()

        _ = simulation.activateCharacterAbility()
        for _ in 0..<8 {
            _ = simulation.update(delta: 0.05)
        }

        #expect(simulation.snapshot.targetsDefeated == 1)
        #expect(simulation.snapshot.characterAbilityDefeats == 0)
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

        simulation.spawnHostileProjectileForTesting(x: 0.72, y: 0.82)
        let hostileStart = simulation.snapshot.projectiles
            .first(where: \.hostile)?
            .position
        _ = simulation.update(delta: 0.05)
        #expect(
            simulation.snapshot.projectiles.first(where: \.hostile)?.position
                == hostileStart
        )

        var sawShatter = false
        for _ in 0..<110 {
            let updateEvents = simulation.update(delta: 0.05)
            sawShatter = sawShatter || updateEvents.contains {
                if case .characterAbilityEffect(.timeShatter(_)) = $0 {
                    return true
                }
                return false
            }
        }
        #expect(sawShatter)
        #expect(!simulation.snapshot.projectiles.contains { $0.hostile })
        #expect(
            (simulation.snapshot.targets.first(where: { $0.id == robot.id })?
                .hitPoints ?? 500) < 500
        )
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
        #expect(simulation.snapshot.characterAttacks.count == 7)
        #expect(simulation.snapshot.characterAttacks.allSatisfy {
            $0.kind == .meteor
        })
        #expect(simulation.snapshot.characterAttacks.first?.targetID == robot.id)

        var sawImpact = false
        for _ in 0..<35 {
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

    @Test func galeLaunchesFiveBouncersAndUsesOrbitersOnSeparateEnemies() {
        var progress = PlayerProgress.newPlayer
        progress.selectedCharacter = .gale
        progress.unlockedCharacters.insert(.gale)
        let simulation = GameSimulation(
            level: GameContent.level(31),
            progress: progress,
            assistMode: false,
            seed: 861
        )
        simulation.replaceTargetsForTesting([])
        simulation.setPlayerTarget(x: -0.78)
        for _ in 0..<20 {
            _ = simulation.update(delta: 0.05)
        }
        #expect(simulation.snapshot.playerX < -0.65)
        let enemies = [-0.52, 0.0, 0.52].enumerated().map { index, x in
            TargetState(
                id: 9_100 + index,
                kind: .enemy(.cloudRunner),
                position: .init(x: x, y: 0.24 + Double(index) * 0.01),
                hitPoints: 500,
                maximumHitPoints: 500,
                phase: 0,
                freezeRemaining: 20
            )
        }
        simulation.replaceTargetsForTesting(enemies)
        simulation.spawnHostileProjectileForTesting(x: 0.80, y: 0.68)
        simulation.fullyChargeCharacterAbilityForTesting()

        _ = simulation.activateCharacterAbility()

        #expect(simulation.snapshot.galeBounces.count == 5)
        #expect(Set(simulation.snapshot.galeBounces.map(\.startPosition.x)).count == 1)
        #expect(
            simulation.snapshot.galeBounces.map(\.destinationX)
                == [-0.78, -0.39, 0, 0.39, 0.78]
        )
        #expect(simulation.snapshot.galeOrbitCount == 3)
        #expect(!simulation.snapshot.projectiles.contains {
            !$0.hostile && $0.temporaryAbility == .heatSeeking
        })

        _ = simulation.update(delta: 0.01)
        #expect(simulation.snapshot.galeOrbitCount == 0)
        #expect(simulation.snapshot.galeInterceptors.count == 3)
        #expect(
            Set(simulation.snapshot.galeInterceptors.map(\.targetID))
                == Set(enemies.map(\.id))
        )
        #expect(simulation.snapshot.projectiles.contains { $0.hostile })

        var landingCount = 0
        for _ in 0..<8 {
            landingCount += simulation.update(delta: 0.05).count {
                if case .characterAbilityEffect(.galeLanding(_, _)) = $0 {
                    return true
                }
                return false
            }
        }
        let centeredLaunchXs = simulation.snapshot.galeBounces.map(\.position.x)
        #expect(centeredLaunchXs.allSatisfy { abs($0) < 0.20 })
        #expect((centeredLaunchXs.max() ?? 0) - (centeredLaunchXs.min() ?? 0) > 0.20)
        for _ in 0..<80 {
            let events = simulation.update(delta: 0.05)
            landingCount += events.count {
                if case .characterAbilityEffect(.galeLanding(_, _)) = $0 {
                    return true
                }
                return false
            }
        }

        #expect(landingCount == 20)
        #expect(simulation.snapshot.galeBounces.isEmpty)
        for enemy in enemies {
            let updated = simulation.snapshot.targets.first {
                $0.id == enemy.id
            }
            #expect((updated?.hitPoints ?? 500) < 500)
            #expect((updated?.position.y ?? 0) >= 0.42)
        }

        simulation.fullyChargeCharacterAbilityForTesting()
        _ = simulation.activateCharacterAbility()
        #expect(simulation.snapshot.galeOrbitCount == 3)
        #expect(simulation.snapshot.galeBounces.count == 5)
    }

    @Test func haloSweepsTheArenaAsOneProjectileClearingRing() {
        var progress = PlayerProgress.newPlayer
        progress.selectedCharacter = .halo
        progress.unlockedCharacters.insert(.halo)
        let simulation = GameSimulation(
            level: GameContent.level(41),
            progress: progress,
            assistMode: false,
            seed: 862
        )
        simulation.replaceTargetsForTesting([])
        simulation.setPlayerTarget(x: -0.78)
        for _ in 0..<20 {
            _ = simulation.update(delta: 0.05)
        }
        #expect(simulation.snapshot.playerX < -0.65)
        let robots = [-0.72, 0.0, 0.72].enumerated().map { index, x in
            TargetState(
                id: 9_201 + index,
                kind: .enemy(.ringRunner),
                position: .init(x: x, y: 0.52),
                hitPoints: 1_000,
                maximumHitPoints: 1_000,
                phase: 0,
                freezeRemaining: 20
            )
        }
        simulation.replaceTargetsForTesting(robots)
        simulation.fullyChargeCharacterAbilityForTesting()

        _ = simulation.activateCharacterAbility()

        #expect(simulation.snapshot.haloRings.count == 1)
        #expect(simulation.snapshot.haloRings.first?.radius == 0.80)
        #expect((simulation.snapshot.haloRings.first?.startX ?? 0) < -0.65)
        for _ in 0..<60 {
            _ = simulation.update(delta: 0.05)
        }
        let ring = simulation.snapshot.haloRings.first
        #expect(abs(ring?.center.x ?? 1) < 0.02)
        for robot in robots {
            #expect((ring?.targetHitCounts[robot.id] ?? 0) >= 1)
            #expect(
                (simulation.snapshot.targets.first(where: { $0.id == robot.id })?
                    .hitPoints ?? 1_000) < 1_000
            )
        }
    }

    @Test func fluxThrowsSixTrapsThatPinAndDamageSeparateEnemies() {
        var progress = PlayerProgress.newPlayer
        progress.selectedCharacter = .flux
        progress.unlockedCharacters.insert(.flux)
        let simulation = GameSimulation(
            level: GameContent.level(51),
            progress: progress,
            assistMode: false,
            seed: 863
        )
        let positions: [Vector2] = [
            .init(x: -0.06, y: 0.48),
            .init(x: -0.03, y: 0.50),
            .init(x: 0, y: 0.52),
            .init(x: 0.03, y: 0.88),
            .init(x: 0.06, y: 0.90),
            .init(x: 0, y: 0.92),
        ]
        let enemies = positions.enumerated().map { index, position in
            TargetState(
                id: 9_300 + index,
                kind: .enemy(.frostSprinter),
                position: position,
                hitPoints: 500,
                maximumHitPoints: 500,
                phase: 0,
                freezeRemaining: 20
            )
        }
        simulation.replaceTargetsForTesting(enemies)
        simulation.spawnHostileProjectileForTesting(x: 0.82, y: 0.82)
        let projectileIDs = simulation.snapshot.projectiles.map(\.id)
        simulation.fullyChargeCharacterAbilityForTesting()

        _ = simulation.activateCharacterAbility()

        #expect(simulation.snapshot.magneticTraps.count == 6)
        #expect(simulation.snapshot.projectiles.map(\.id) == projectileIDs)
        #expect(
            Set(simulation.snapshot.magneticTraps.compactMap(\.targetID))
                == Set(enemies.map(\.id))
        )
        let landingPositions = simulation.snapshot.magneticTraps.map(\.landingPosition)
        #expect((landingPositions.map(\.x).min() ?? 0) <= -0.75)
        #expect((landingPositions.map(\.x).max() ?? 0) >= 0.75)
        let pairwiseDistances = landingPositions.indices.flatMap { first in
            landingPositions.indices.compactMap { second -> Double? in
                guard first < second else { return nil }
                return hypot(
                    landingPositions[first].x - landingPositions[second].x,
                    landingPositions[first].y - landingPositions[second].y
                )
            }
        }
        #expect((pairwiseDistances.min() ?? 0) >= 0.36)

        var snapCount = 0
        for _ in 0..<22 {
            snapCount += simulation.update(delta: 0.05).count {
                if case .characterAbilityEffect(.magneticTrapSnap(_)) = $0 {
                    return true
                }
                return false
            }
        }
        let visiblyPullingEnemy = simulation.snapshot.targets.first {
            $0.id == enemies[0].id
        }
        #expect((visiblyPullingEnemy?.position.x ?? 0) < -0.20)
        #expect((visiblyPullingEnemy?.position.x ?? -1) > -0.70)
        #expect(
            simulation.snapshot.magneticTraps.first {
                $0.targetID == enemies[0].id
            }?.captureRemaining == 0
        )
        for _ in 0..<120 {
            if snapCount == 6 { break }
            snapCount += simulation.update(delta: 0.05).count {
                if case .characterAbilityEffect(.magneticTrapSnap(_)) = $0 {
                    return true
                }
                return false
            }
        }
        #expect(snapCount == 6)
        for _ in 0..<10 {
            _ = simulation.update(delta: 0.05)
        }
        for enemy in enemies {
            #expect(
                (simulation.snapshot.targets.first(where: { $0.id == enemy.id })?
                    .hitPoints ?? 500) < 500
            )
        }
    }

    @Test func fluxTrapRejectsPassedEnemyAndCompletesAForwardPull() {
        var progress = PlayerProgress.newPlayer
        progress.selectedCharacter = .flux
        progress.unlockedCharacters.insert(.flux)
        let simulation = GameSimulation(
            level: GameContent.level(51),
            progress: progress,
            assistMode: false,
            seed: 865
        )
        let passedEnemy = TargetState(
            id: 9_400,
            kind: .enemy(.frostSprinter),
            position: .init(x: 0, y: 0.34),
            hitPoints: 10_000,
            maximumHitPoints: 10_000,
            phase: 0
        )
        let forwardEnemy = TargetState(
            id: 9_401,
            kind: .enemy(.frostSprinter),
            position: .init(x: 0, y: 0.72),
            hitPoints: 10_000,
            maximumHitPoints: 10_000,
            phase: 0
        )
        simulation.replaceTargetsForTesting([passedEnemy, forwardEnemy])
        simulation.fullyChargeCharacterAbilityForTesting()

        _ = simulation.activateCharacterAbility()

        #expect(
            !simulation.snapshot.magneticTraps
                .compactMap(\.targetID)
                .contains(passedEnemy.id)
        )

        var snappedForwardEnemy = false
        for _ in 0..<80 {
            let events = simulation.update(delta: 0.05)
            snappedForwardEnemy = snappedForwardEnemy || events.contains {
                if case .characterAbilityEffect(.magneticTrapSnap(_)) = $0 {
                    return true
                }
                return false
            }
            if snappedForwardEnemy { break }
        }

        #expect(snappedForwardEnemy)
        #expect(
            simulation.snapshot.magneticTraps.contains {
                $0.targetID == forwardEnemy.id && $0.captureRemaining > 0
            }
        )
        #expect(
            !simulation.snapshot.magneticTraps
                .compactMap(\.targetID)
                .contains(passedEnemy.id)
        )
    }

    @Test func surgeLaunchesThreeFullFieldTsunamisInOrder() {
        var progress = PlayerProgress.newPlayer
        progress.selectedCharacter = .surge
        progress.unlockedCharacters.insert(.surge)
        let simulation = GameSimulation(
            level: GameContent.level(61),
            progress: progress,
            assistMode: false,
            seed: 864
        )
        let enemies = [-0.60, 0.0, 0.60].enumerated().map { index, x in
            TargetState(
                id: 9_400 + index,
                kind: .enemy(.mistRunner),
                position: .init(x: x, y: 0.50),
                hitPoints: 500,
                maximumHitPoints: 500,
                phase: 0,
                freezeRemaining: 20
            )
        }
        simulation.replaceTargetsForTesting(enemies)
        for x in [-0.60, 0.0, 0.60] {
            simulation.spawnHostileProjectileForTesting(x: x, y: 0.50)
        }
        simulation.fullyChargeCharacterAbilityForTesting()

        _ = simulation.activateCharacterAbility()

        #expect(simulation.snapshot.tidalWaves.count == 3)
        #expect(simulation.snapshot.tidalWaves.map(\.lane)
            == [.middle, .middle, .middle])
        #expect(simulation.snapshot.tidalWaves.map(\.round)
            == [1, 2, 3])
        #expect(simulation.snapshot.tidalWaves.allSatisfy {
            $0.halfWidth >= 0.90
        })

        var launches: [(TidalLane, Int)] = []
        for _ in 0..<56 {
            let events = simulation.update(delta: 0.05)
            for event in events {
                if case .characterAbilityEffect(
                    .tidalLaunch(let lane, let round, _)
                ) = event {
                    launches.append((lane, round))
                }
            }
        }

        #expect(launches.map(\.0) == [.middle, .middle, .middle])
        #expect(launches.map(\.1) == [1, 2, 3])
        #expect(!simulation.snapshot.projectiles.contains { $0.hostile })
        for enemy in enemies {
            let updated = simulation.snapshot.targets.first {
                $0.id == enemy.id
            }
            #expect((updated?.hitPoints ?? 500) < 500)
            #expect((updated?.position.y ?? 0.50) > 0.50)
        }
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

    @Test func campaignOnlyBallsHaveDistinctProjectileSignatures() {
        let cases: [(TemporaryBallAbility, String)] = [
            (.heatSeeking, "heat-seeking-signature"),
            (.orbitShot, "orbit-shot-signature"),
            (.solarPierce, "solar-pierce-signature"),
        ]

        for (ability, signatureName) in cases {
            let node = GameNodeFactory.projectile(hostile: false)
            GameNodeFactory.configureProjectile(
                node,
                hostile: false,
                critical: false,
                temporaryAbility: ability
            )
            #expect(node.childNode(withName: "//\(signatureName)") != nil)
        }
    }

    @Test func endlessBallDisplaysEveryTriggeredEffectMarker() {
        let node = GameNodeFactory.projectile(hostile: false)
        let effects = Set(EndlessSpecialBallRules.abilities)
        GameNodeFactory.configureProjectile(
            node,
            hostile: false,
            critical: false,
            temporaryAbility: nil,
            endlessEffects: effects
        )

        for ability in EndlessSpecialBallRules.abilities {
            #expect(node.childNode(withName: "//effect-\(ability.rawValue)") != nil)
        }
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

    @Test func overlappingStatusesRenderAllEffectLayersTogether() {
        var target = TargetState(
            id: 2,
            kind: .enemy(.titanKeeper),
            position: .init(x: 0, y: 0.5),
            hitPoints: 10,
            maximumHitPoints: 10,
            phase: 0
        )
        target.burnRemaining = 3
        target.freezeRemaining = 2
        target.reverseRemaining = 2.5
        target.stunRemaining = 1
        target.magnetRemaining = 1.4
        target.undertowSlowRemaining = 0.55
        let node = GameNodeFactory.target(target)

        GameNodeFactory.updateStatus(
            on: node,
            target: target,
            reducedMotion: false
        )

        #expect(node.childNode(withName: "//status-fire-front")?.alpha == 1)
        #expect(node.childNode(withName: "//status-ice-crystals")?.alpha == 1)
        #expect(
            abs(
                (node.childNode(withName: "//status-reverse-trail")?.alpha ?? 0)
                    - 0.88
            ) < 0.001
        )
        #expect(node.childNode(withName: "//status-stun-arcs")?.alpha == 1)
        #expect(node.childNode(withName: "//status-magnet-mark")?.alpha == 1)
        #expect(node.childNode(withName: "//status-undertow")?.alpha == 1)
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

    @Test func completionBonusesAndEndlessRunsCreateTheIntendedProgressionGap() {
        let expectedFirstClearTotals = [
            1_310, 2_030, 3_140, 4_865, 7_545, 11_705, 18_145,
        ]
        #expect(GameContent.level(1).firstClearBonus >= UpgradeRules.cost(forNextRank: 0))
        #expect(GameContent.levels.allSatisfy { $0.replayBonus < $0.firstClearBonus })

        for (worldIndex, world) in WorldID.allCases.enumerated() {
            let worldBonus = GameContent.levels(in: world).reduce(0) {
                $0 + $1.firstClearBonus
            }
            #expect(worldBonus == expectedFirstClearTotals[worldIndex])

            let finalLevel = GameContent.world(world).finalLevel
            let targetRank = Int(
                CampaignBalance.targetPermanentRank(
                    for: GameContent.level(finalLevel)
                )
            )
            let targetBalancedBuild = UpgradeTrack.allCases.count
                * UpgradePrestigeRules.totalInvestment(toReachRank: targetRank)
            let expectedCampaignIncome = EconomyBalance.expectedCampaignTokens(
                throughLevel: finalLevel
            )

            let gap = Double(targetBalancedBuild) - expectedCampaignIncome
            let reachableEndlessWave = max(
                EndlessRules.wavesPerWorld,
                worldIndex * EndlessRules.wavesPerWorld
            )
            let expectedEndlessRun = EconomyBalance.expectedEndlessTokens(
                throughWave: reachableEndlessWave
            )
            #expect(gap > 0)
            #expect(gap < expectedEndlessRun * 5)
        }
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

    @Test func incomingDamageUsesASmoothBaselineStaminaAsymptote() {
        let smallHit = CombatBalance.effectiveIncomingDamage(
            rawDamage: 1,
            maxStamina: 100
        )
        let mediumHit = CombatBalance.effectiveIncomingDamage(
            rawDamage: 25,
            maxStamina: 100
        )
        let hugeHit = CombatBalance.effectiveIncomingDamage(
            rawDamage: 10_000,
            maxStamina: 100
        )
        #expect(smallHit > 0.98 && smallHit < 1)
        #expect(mediumHit > smallHit && mediumHit < 25)
        #expect(hugeHit == 25)
        #expect(
            CombatBalance.effectiveIncomingDamage(
                rawDamage: 10_000,
                maxStamina: 200
            ) == 25
        )

        func simulation(isEndless: Bool, seed: UInt64) -> GameSimulation {
            if isEndless {
                GameSimulation(
                    mode: .endless,
                    progress: .newPlayer,
                    assistMode: false,
                    seed: seed
                )
            } else {
                GameSimulation(
                    level: GameContent.level(1),
                    progress: .newPlayer,
                    assistMode: false,
                    seed: seed
                )
            }
        }

        for (index, isEndless) in [false, true].enumerated() {
            let singleHit = simulation(
                isEndless: isEndless,
                seed: 5_001 + UInt64(index)
            )
            singleHit.spawnHostileProjectileForTesting(
                x: singleHit.snapshot.playerX,
                y: 0.16,
                damage: 10_000
            )
            _ = singleHit.update(delta: 0.05)
            #expect(
                singleHit.snapshot.stamina
                    == singleHit.snapshot.maxStamina * 0.75
            )

            let fourHits = simulation(
                isEndless: isEndless,
                seed: 5_101 + UInt64(index)
            )
            var events: [SimulationEvent] = []
            for _ in 0..<4 {
                fourHits.spawnHostileProjectileForTesting(
                    x: fourHits.snapshot.playerX,
                    y: 0.16,
                    damage: 10_000
                )
                events += fourHits.update(delta: 0.05)
            }
            #expect(fourHits.snapshot.stamina == 0)
            #expect(events.contains(.finished(false)))
        }
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
        let expectedForgivingHP = CombatBalance.baseHealth(.coneRunner)
            * CampaignBalance.wave(1, for: GameContent.level(1)).healthMultiplier
        #expect(forgivingHP < standardHP)
        #expect(abs(forgivingHP - expectedForgivingHP) < 0.0001)
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
            #expect(!powers.contains(.volt))
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
            let reverseOffset = chain.arcs.count - offset - 1
            let expectedDamage = 10
                * (0.15 + Double(reverseOffset) * 0.05)
            #expect(abs(arc.damage - expectedDamage) < 0.000_001)
        }
        #expect(
            zip(chain.arcs.map(\.damage), chain.arcs.map(\.damage).dropFirst())
                .allSatisfy { $0 > $1 }
        )
        #expect(Set(chain.arcs.map(\.targetID)).isDisjoint(with: excluded.map(\.id)))
    }

    @Test func voltChainHasNoRecipientCap() throws {
        let simulation = GameSimulation(
            level: GameContent.level(10),
            progress: .newPlayer,
            assistMode: false,
            seed: 608
        )
        let origin = TargetState(
            id: 10_200,
            kind: .enemy(.dummyDefender),
            position: .init(x: 0, y: 0.18),
            hitPoints: 1_000,
            maximumHitPoints: 1_000,
            phase: 0
        )
        let recipients = (0..<40).map { offset in
            TargetState(
                id: 10_201 + offset,
                kind: .enemy(.tackleBot),
                position: .init(
                    x: Double((offset % 9) - 4) * 0.09,
                    y: 0.28 + Double(offset) * 0.012
                ),
                hitPoints: 1_000,
                maximumHitPoints: 1_000,
                phase: 0
            )
        }
        simulation.replaceTargetsForTesting([origin] + recipients)
        simulation.spawnFriendlyProjectileForTesting(
            pierce: 0,
            temporaryAbility: .volt
        )

        let events = simulation.update(delta: 0.01)
        let chain = try #require(events.compactMap { event -> VoltChainEvent? in
            if case .voltChain(let chain) = event { return chain }
            return nil
        }.first)

        #expect(chain.arcs.count == recipients.count)
        #expect(Set(chain.arcs.map(\.targetID)) == Set(recipients.map(\.id)))
        #expect(chain.arcs.allSatisfy { $0.damage > 0 })
        #expect(
            zip(chain.arcs.map(\.damage), chain.arcs.map(\.damage).dropFirst())
                .allSatisfy { $0 > $1 }
        )
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
                // The landmark health wall keeps status-bearing targets alive
                // long enough to observe the effect after the direct hit.
                level: GameContent.level(5),
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

    @Test func freezeAndReverseControlFieldObjectMovement() {
        let frozen = GameSimulation(
            level: GameContent.level(4),
            progress: .newPlayer,
            assistMode: true,
            seed: 309
        )
        var frozenObject = TargetState(
            id: 9_800,
            kind: .fieldObject(.ballCart),
            position: .init(x: 0, y: 0.50),
            hitPoints: 100,
            maximumHitPoints: 100,
            phase: 0
        )
        frozenObject.freezeRemaining = 1
        frozen.replaceTargetsForTesting([frozenObject])
        _ = frozen.update(delta: 0.10)

        let reversed = GameSimulation(
            level: GameContent.level(4),
            progress: .newPlayer,
            assistMode: true,
            seed: 310
        )
        var reversedObject = TargetState(
            id: 9_801,
            kind: .fieldObject(.ballCart),
            position: .init(x: 0, y: 0.50),
            hitPoints: 100,
            maximumHitPoints: 100,
            phase: 0
        )
        reversedObject.reverseRemaining = 1
        reversed.replaceTargetsForTesting([reversedObject])
        _ = reversed.update(delta: 0.10)

        #expect(abs((frozen.snapshot.targets.first?.position.y ?? 0) - 0.50) < 0.000_001)
        #expect((reversed.snapshot.targets.first?.position.y ?? 0) > 0.50)
    }

    @Test func campaignAndEndlessFireScaleBurnFromDeliveredBallDamage() {
        for isEndless in [false, true] {
            let simulation = isEndless
                ? GameSimulation(
                    mode: .endless,
                    progress: .newPlayer,
                    assistMode: true,
                    seed: 312
                )
                : GameSimulation(
                    level: GameContent.level(4),
                    progress: .newPlayer,
                    assistMode: true,
                    seed: 312
                )
            if isEndless {
                for _ in 0..<5 {
                    simulation.apply(.specialBall(.fire))
                }
            }
            simulation.replaceTargetsForTesting([
                TargetState(
                    id: isEndless ? 9_811 : 9_810,
                    kind: .enemy(.dummyDefender),
                    position: .init(x: 0, y: 0.18),
                    hitPoints: 1_000,
                    maximumHitPoints: 1_000,
                    phase: 0
                )
            ])
            simulation.spawnFriendlyProjectileForTesting(
                pierce: 0,
                damage: 50,
                temporaryAbility: isEndless ? nil : .fire,
                endlessEffects: isEndless ? [.fire] : []
            )
            _ = simulation.update(delta: 0.01)

            #expect(
                abs(
                    (simulation.snapshot.targets.first?.burnTickDamage ?? 0)
                        - 9
                ) < 0.000_001
            )
        }
    }

    @Test func orbitAndSolarBallsEmitTheirOwnImpactFeedback() {
        let orbit = GameSimulation(
            level: GameContent.level(4),
            progress: .newPlayer,
            assistMode: true,
            seed: 313
        )
        orbit.replaceTargetsForTesting([
            TargetState(
                id: 9_820,
                kind: .enemy(.dummyDefender),
                position: .init(x: 0, y: 0.18),
                hitPoints: 1_000,
                maximumHitPoints: 1_000,
                phase: 0
            ),
            TargetState(
                id: 9_821,
                kind: .enemy(.dummyDefender),
                position: .init(x: 0.24, y: 0.32),
                hitPoints: 1_000,
                maximumHitPoints: 1_000,
                phase: 0
            ),
        ])
        orbit.spawnFriendlyProjectileForTesting(
            pierce: 0,
            temporaryAbility: .orbitShot
        )
        let orbitEvents = orbit.update(delta: 0.01)

        let solar = GameSimulation(
            level: GameContent.level(4),
            progress: .newPlayer,
            assistMode: true,
            seed: 314
        )
        solar.replaceTargetsForTesting([
            TargetState(
                id: 9_822,
                kind: .enemy(.dummyDefender),
                position: .init(x: 0, y: 0.18),
                hitPoints: 1_000,
                maximumHitPoints: 1_000,
                phase: 0
            )
        ])
        solar.spawnFriendlyProjectileForTesting(
            pierce: 0,
            temporaryAbility: .solarPierce
        )
        let solarEvents = solar.update(delta: 0.01)

        #expect(orbitEvents.contains {
            if case .specialBallEffect(.orbitRedirect) = $0 { true } else { false }
        })
        #expect(solarEvents.contains {
            if case .specialBallEffect(.solarPierce) = $0 { true } else { false }
        })
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
        var directImpactsByTarget: [Int: ImpactEvent] = [:]

        for _ in 0..<600 where directImpact == nil || damageOverTimeImpact == nil {
            if let target = simulation.snapshot.targets.first {
                simulation.setPlayerTarget(x: target.position.x)
            }
            for event in simulation.update(delta: 0.05) {
                guard case .impact(let impact) = event, impact.flavor == .fire else { continue }
                if impact.delivery == .direct {
                    directImpactsByTarget[impact.targetID] = impact
                } else if impact.delivery == .damageOverTime,
                          let matchingDirectImpact = directImpactsByTarget[impact.targetID] {
                    directImpact = matchingDirectImpact
                    damageOverTimeImpact = impact
                }
            }
        }

        #expect(directImpact?.delivery == .direct)
        #expect(damageOverTimeImpact?.delivery == .damageOverTime)
        #expect(damageOverTimeImpact?.impulse == .init(x: 0, y: 0))
        #expect(damageOverTimeImpact?.isCritical == false)
        #expect(damageOverTimeImpact?.targetID == directImpact?.targetID)
    }

    @Test func fireIceAndReverseRemainStackedWhileVoltStrikes() {
        let simulation = GameSimulation(
            level: GameContent.level(4),
            progress: .newPlayer,
            assistMode: true,
            seed: 47
        )
        simulation.replaceTargetsForTesting([
            TargetState(
                id: 9_910,
                kind: .enemy(.titanKeeper),
                position: .init(x: 0, y: 0.28),
                hitPoints: 1_000_000,
                maximumHitPoints: 1_000_000,
                phase: 0
            ),
            TargetState(
                id: 9_911,
                kind: .enemy(.dummyDefender),
                position: .init(x: 0.35, y: 0.40),
                hitPoints: 1_000_000,
                maximumHitPoints: 1_000_000,
                phase: 0
            )
        ])

        for ability in [
            TemporaryBallAbility.fire,
            .ice,
            .reverse,
        ] {
            simulation.spawnFriendlyProjectileForTesting(
                pierce: 0,
                temporaryAbility: ability
            )
            for _ in 0..<5 {
                _ = simulation.update(delta: 0.05)
            }
        }

        guard let stacked = simulation.snapshot.targets.first(where: {
            $0.id == 9_910
        }) else {
            Issue.record("Expected the stacked target to remain alive")
            return
        }
        #expect(stacked.burnRemaining > 0)
        #expect(stacked.freezeRemaining > 0)
        #expect(stacked.reverseRemaining > 0)

        simulation.spawnFriendlyProjectileForTesting(
            pierce: 0,
            temporaryAbility: .volt
        )
        var sawVolt = false
        for _ in 0..<5 where !sawVolt {
            sawVolt = simulation.update(delta: 0.05).contains {
                if case .voltChain = $0 { true } else { false }
            }
        }

        #expect(sawVolt)
        let afterVolt = simulation.snapshot.targets.first(where: {
            $0.id == 9_910
        })
        #expect((afterVolt?.burnRemaining ?? 0) > 0)
        #expect((afterVolt?.freezeRemaining ?? 0) > 0)
        #expect((afterVolt?.reverseRemaining ?? 0) > 0)
    }

    @Test func oneEndlessBallCanApplyMultipleElementalStatuses() {
        let simulation = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: true,
            seed: 481
        )
        for ability in [
            TemporaryBallAbility.fire,
            .ice,
            .reverse,
        ] {
            for _ in 0..<5 {
                simulation.apply(.specialBall(ability))
            }
        }
        simulation.replaceTargetsForTesting([
            TargetState(
                id: 9_920,
                kind: .enemy(.dummyDefender),
                position: .init(x: 0, y: 0.30),
                hitPoints: 1_000_000,
                maximumHitPoints: 1_000_000,
                phase: 0
            )
        ])
        simulation.spawnFriendlyProjectileForTesting(
            pierce: 0,
            endlessEffects: [.fire, .ice, .reverse]
        )

        for _ in 0..<12 {
            _ = simulation.update(delta: 0.05)
        }

        guard let target = simulation.snapshot.targets.first else {
            Issue.record("Expected the multi-effect target to remain alive")
            return
        }
        #expect(target.burnRemaining > 0)
        #expect(target.freezeRemaining > 0)
        #expect(target.reverseRemaining > 0)
    }

    @Test func gravityVortexPullsDamagesAndEmitsDedicatedFeedback() {
        for isEndless in [false, true] {
            let simulation = isEndless
                ? GameSimulation(
                    mode: .endless,
                    progress: .newPlayer,
                    assistMode: true,
                    seed: 482
                )
                : GameSimulation(
                    level: GameContent.level(4),
                    progress: .newPlayer,
                    assistMode: true,
                    seed: 482
                )
            if isEndless {
                for _ in 0..<5 {
                    simulation.apply(.specialBall(.gravityWell))
                }
            }
            simulation.replaceTargetsForTesting([
                TargetState(
                    id: 9_930,
                    kind: .enemy(.dummyDefender),
                    position: .init(x: 0, y: 0.30),
                    hitPoints: 1_000_000,
                    maximumHitPoints: 1_000_000,
                    phase: 0
                ),
                TargetState(
                    id: 9_931,
                    kind: .enemy(.dummyDefender),
                    position: .init(x: 0.36, y: 0.30),
                    hitPoints: 1_000_000,
                    maximumHitPoints: 1_000_000,
                    phase: 0
                ),
            ])
            simulation.spawnFriendlyProjectileForTesting(
                pierce: 0,
                temporaryAbility: isEndless ? nil : .gravityWell,
                endlessEffects: isEndless ? [.gravityWell] : []
            )

            var sawVortex = false
            for _ in 0..<12 where !sawVortex {
                sawVortex = simulation.update(delta: 0.05).contains {
                    if case .specialBallEffect(.gravityVortex) = $0 {
                        true
                    } else {
                        false
                    }
                }
            }
            let pullWasScheduled = simulation.snapshot.targets.first {
                $0.id == 9_931
            }?.gravityPullRemaining ?? 0
            for _ in 0..<9 {
                _ = simulation.update(delta: 0.05)
            }

            let secondary = simulation.snapshot.targets.first {
                $0.id == 9_931
            }
            #expect(sawVortex)
            #expect(pullWasScheduled > 0)
            #expect(abs(secondary?.position.x ?? 1) < 0.08)
            #expect((secondary?.hitPoints ?? 1_000_000) < 1_000_000)
        }
    }

    @Test func magnetMarkPersistsAndGuidesFollowingBalls() {
        let simulation = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: true,
            seed: 483
        )
        for _ in 0..<5 {
            simulation.apply(.specialBall(.polarLink))
        }
        simulation.replaceTargetsForTesting([
            TargetState(
                id: 9_940,
                kind: .enemy(.dummyDefender),
                position: .init(x: 0, y: 0.30),
                hitPoints: 1_000_000,
                maximumHitPoints: 1_000_000,
                phase: 0
            )
        ])
        simulation.spawnFriendlyProjectileForTesting(
            pierce: 0,
            endlessEffects: [.polarLink]
        )

        var sawMark = false
        for _ in 0..<12 where !sawMark {
            sawMark = simulation.update(delta: 0.05).contains {
                if case .specialBallEffect(.magnetMark) = $0 {
                    true
                } else {
                    false
                }
            }
        }
        guard var markedTarget = simulation.snapshot.targets.first else {
            Issue.record("Expected the marked target to remain alive")
            return
        }
        #expect(sawMark)
        #expect(markedTarget.magnetRemaining > 0)

        markedTarget.position = .init(x: 0.52, y: 0.72)
        simulation.replaceTargetsForTesting([markedTarget])
        simulation.spawnFriendlyProjectileForTesting(pierce: 0)
        _ = simulation.update(delta: 0.05)

        let followingBall = simulation.snapshot.projectiles.first {
            !$0.hostile && $0.endlessEffects.isEmpty
        }
        #expect((followingBall?.velocity.x ?? 0) > 0)
    }

    @Test func tidalPushSlowsWithoutFreezingRegularEnemies() {
        let simulation = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: true,
            seed: 484
        )
        for _ in 0..<5 {
            simulation.apply(.specialBall(.undertow))
        }
        simulation.replaceTargetsForTesting([
            TargetState(
                id: 9_950,
                kind: .enemy(.dummyDefender),
                position: .init(x: 0, y: 0.30),
                hitPoints: 1_000_000,
                maximumHitPoints: 1_000_000,
                phase: 0
            )
        ])
        simulation.spawnFriendlyProjectileForTesting(
            pierce: 0,
            endlessEffects: [.undertow]
        )

        var sawPush = false
        for _ in 0..<12 where !sawPush {
            sawPush = simulation.update(delta: 0.05).contains {
                if case .specialBallEffect(.tidalPush) = $0 {
                    true
                } else {
                    false
                }
            }
        }

        guard let target = simulation.snapshot.targets.first else {
            Issue.record("Expected the pushed target to remain alive")
            return
        }
        #expect(sawPush)
        #expect(target.position.y > 0.30)
        #expect(target.undertowSlowRemaining > 0)
        #expect(target.freezeRemaining == 0)
    }

    @Test func returnShotSurvivesImpactTurnsAndHitsAgain() {
        let simulation = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: true,
            seed: 485
        )
        for _ in 0..<5 {
            simulation.apply(.specialBall(.ringReturn))
        }
        simulation.replaceTargetsForTesting([
            TargetState(
                id: 9_960,
                kind: .enemy(.dummyDefender),
                position: .init(x: 0, y: 0.58),
                hitPoints: 1_000_000,
                maximumHitPoints: 1_000_000,
                phase: 0
            )
        ])
        simulation.spawnFriendlyProjectileForTesting(
            pierce: 0,
            endlessEffects: [.ringReturn]
        )

        var directHits = 0
        var sawReturn = false
        for _ in 0..<90 where directHits < 2 || !sawReturn {
            for event in simulation.update(delta: 0.05) {
                if case .impact(let impact) = event,
                   impact.targetID == 9_960,
                   impact.delivery == .direct {
                    directHits += 1
                }
                if case .specialBallEffect(.returnShot) = event {
                    sawReturn = true
                }
            }
        }

        #expect(sawReturn)
        #expect(directHits >= 2)
    }

    @Test func auditedSpecialBallsHaveUniqueArtAndPlainLanguageNames() {
        let presentations = EndlessSpecialBallRules.abilities.map {
            SpecialBallPresentation.presentation(for: $0, currentRank: 0)
        }
        #expect(Set(presentations.map(\.artAsset)).count == presentations.count)
        #expect(TemporaryAbilityRules.title(for: .gravityWell) == "Gravity Vortex")
        #expect(TemporaryAbilityRules.title(for: .ringReturn) == "Return Shot")
        #expect(TemporaryAbilityRules.title(for: .polarLink) == "Magnet Mark")
        #expect(TemporaryAbilityRules.title(for: .undertow) == "Tidal Push")
        #expect(presentations.allSatisfy {
            $0.effect.chanceCurrent == "Off"
                && $0.effect.chanceNext == "10%"
        })
    }

    @Test func bossMovementIsDeliberatelySlowAndMegaBossesAreLargest() {
        #expect(CampaignBalance.bossMovementRate(tier: .megaBoss)
                < CampaignBalance.bossMovementRate(tier: .miniBoss))
        #expect(CampaignBalance.bossMovementRate(tier: .miniBoss)
                < CampaignBalance.bossMovementRate(tier: .standard))
        #expect(CampaignBalance.bossScale(tier: .megaBoss)
                > CampaignBalance.bossScale(tier: .miniBoss))
        #expect(CampaignBalance.bossScale(tier: .miniBoss) >= 1.5)
        var previousBossHealth = 0.0
        for world in WorldID.allCases {
            let level = GameContent.level(GameContent.world(world).finalLevel)
            let bossHealth = CampaignBalance.bossHitPoints(
                tier: .megaBoss,
                wave: level.waveCount,
                for: level
            )
            #expect(bossHealth > previousBossHealth)
            previousBossHealth = bossHealth
        }
    }

    @Test func frozenBossesHoldTheirWorldPositionInCampaignAndEndless() {
        let campaignLevel = GameContent.level(10)
        let campaign = GameSimulation(
            level: campaignLevel,
            progress: .newPlayer,
            assistMode: false,
            seed: 4_010
        )
        campaign.setCampaignWaveForTesting(campaignLevel.waveCount)

        let endless = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: false,
            seed: 4_011
        )
        endless.setEndlessWaveForTesting(5)

        for simulation in [campaign, endless] {
            _ = simulation.update(delta: 0.05)
            _ = simulation.update(delta: 0.05)
            guard var boss = simulation.snapshot.targets.first(where: {
                $0.waveRole == .boss
            }) else {
                Issue.record("Expected a boss")
                continue
            }
            boss.freezeRemaining = 0.60
            simulation.replaceTargetsForTesting([boss])
            let frozenPosition = boss.position

            for _ in 0..<10 {
                _ = simulation.update(delta: 0.05)
                let currentPosition = simulation.snapshot.targets.first(where: {
                    $0.id == boss.id
                })?.position
                #expect(currentPosition == frozenPosition)
            }
        }
    }

    @Test func reverseChangesBossDirectionWithoutMirroringAcrossArena() {
        let campaignLevel = GameContent.level(10)
        let campaign = GameSimulation(
            level: campaignLevel,
            progress: .newPlayer,
            assistMode: false,
            seed: 4_012
        )
        campaign.setCampaignWaveForTesting(campaignLevel.waveCount)

        let endless = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: false,
            seed: 4_013
        )
        endless.setEndlessWaveForTesting(5)

        for simulation in [campaign, endless] {
            for _ in 0..<100 {
                _ = simulation.update(delta: 0.025)
            }
            guard var boss = simulation.snapshot.targets.first(where: {
                $0.waveRole == .boss
            }) else {
                Issue.record("Expected a boss")
                continue
            }

            let positionBeforeReverse = boss.position.x
            boss.reverseRemaining = 0.50
            simulation.replaceTargetsForTesting([boss])
            _ = simulation.update(delta: 0.01)

            guard var reversedBoss = simulation.snapshot.targets.first(where: {
                $0.id == boss.id
            }) else {
                Issue.record("Expected the reversed boss")
                continue
            }
            #expect(abs(reversedBoss.position.x - positionBeforeReverse) < 0.02)
            #expect(reversedBoss.position.x < positionBeforeReverse)

            reversedBoss.reverseRemaining = 0.005
            simulation.replaceTargetsForTesting([reversedBoss])
            let positionBeforeExpiration = reversedBoss.position.x
            _ = simulation.update(delta: 0.01)

            guard let recoveredBoss = simulation.snapshot.targets.first(where: {
                $0.id == boss.id
            }) else {
                Issue.record("Expected the recovered boss")
                continue
            }
            #expect(abs(recoveredBoss.position.x - positionBeforeExpiration) < 0.02)
            #expect(recoveredBoss.position.x > positionBeforeExpiration)
        }
    }

    @Test func endlessEnemyShieldCurvesStartLateAndKeepScaling() {
        #expect(EndlessRules.regularShieldSpawnChance(wave: 10) == 0)
        #expect(EndlessRules.regularShieldHealthFraction(wave: 10) == 0)
        #expect(EndlessRules.bossShieldSpawnChance(wave: 24) == 0)
        #expect(EndlessRules.bossShieldHealthFraction(wave: 24) == 0)

        let wave30Chance = EndlessRules.regularShieldSpawnChance(wave: 30)
        let wave30Health = EndlessRules.regularShieldHealthFraction(wave: 30)
        #expect(abs(wave30Chance - 0.4405) < 0.001)
        #expect(abs(wave30Health - 0.4361) < 0.001)
        #expect(EndlessRules.regularShieldSpawnChance(wave: 100) > wave30Chance)
        #expect(EndlessRules.regularShieldHealthFraction(wave: 100) > wave30Health)
        #expect(EndlessRules.bossShieldSpawnChance(wave: 30) < wave30Chance)
        #expect(
            EndlessRules.bossShieldHealthFraction(wave: 30)
                < wave30Health
        )
    }

    @Test func shieldAbsorbsDamageAndBreakingHitCannotApplyBallEffects() {
        let simulation = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: false,
            seed: 4_020
        )
        simulation.apply(.specialBall(.fire))
        simulation.apply(.specialBall(.ice))
        simulation.apply(.specialBall(.reverse))
        simulation.replaceTargetsForTesting([
            TargetState(
                id: 20_001,
                kind: .enemy(.coneRunner),
                position: .init(x: 0, y: 0.18),
                hitPoints: 100,
                maximumHitPoints: 100,
                shieldHitPoints: 5,
                maximumShieldHitPoints: 5,
                phase: 0
            )
        ])
        let effects: Set<TemporaryBallAbility> = [.fire, .ice, .reverse]
        simulation.spawnFriendlyProjectileForTesting(
            pierce: 0,
            damage: 10,
            endlessEffects: effects
        )

        let breakingEvents = simulation.update(delta: 0.01)
        guard let afterBreak = simulation.snapshot.targets.first else {
            Issue.record("Expected shielded target to survive")
            return
        }
        #expect(afterBreak.shieldHitPoints == 0)
        #expect(afterBreak.hitPoints == 95)
        #expect(afterBreak.burnRemaining == 0)
        #expect(afterBreak.freezeRemaining == 0)
        #expect(afterBreak.reverseRemaining == 0)
        #expect(breakingEvents.contains {
            if case .enemyShieldBroken = $0 { true } else { false }
        })

        simulation.spawnFriendlyProjectileForTesting(
            pierce: 0,
            damage: 1,
            endlessEffects: effects
        )
        for _ in 0..<20 {
            _ = simulation.update(delta: 0.01)
            if simulation.snapshot.targets.contains(where: {
                $0.id == afterBreak.id
                    && $0.burnRemaining > 0
                    && $0.freezeRemaining > 0
                    && $0.reverseRemaining > 0
            }) {
                break
            }
        }
        guard let afterFollowUp = simulation.snapshot.targets.first else {
            Issue.record("Expected target after follow-up")
            return
        }
        #expect(afterFollowUp.burnRemaining > 0)
        #expect(afterFollowUp.freezeRemaining > 0)
        #expect(afterFollowUp.reverseRemaining > 0)
    }

    @Test func onlyLateEndlessSpawnsReceiveEnemyShields() {
        let endless = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: false,
            seed: 4_022
        )
        endless.setEndlessWaveForTesting(99)
        for _ in 0..<300 {
            _ = endless.update(delta: 0.01)
        }
        let shieldedEnemies = endless.snapshot.targets.filter {
            if case .enemy = $0.kind { $0.maximumShieldHitPoints > 0 } else { false }
        }
        #expect(!shieldedEnemies.isEmpty)
        for enemy in shieldedEnemies {
            let expectedShield = enemy.maximumHitPoints
                * EndlessRules.regularShieldHealthFraction(wave: 99)
            #expect(
                abs(enemy.maximumShieldHitPoints - expectedShield)
                    < max(0.001, expectedShield * 0.000_001)
            )
        }

        let campaign = GameSimulation(
            level: GameContent.level(70),
            progress: .newPlayer,
            assistMode: false,
            seed: 4_022
        )
        for _ in 0..<300 {
            _ = campaign.update(delta: 0.01)
        }
        #expect(campaign.snapshot.targets.allSatisfy {
            $0.maximumShieldHitPoints == 0
        })
    }

    @Test func shieldedBossRefreshesAndCleansesAtEachNewPhase() {
        let simulation = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: false,
            seed: 4_021
        )
        simulation.setEndlessWaveForTesting(25)
        _ = simulation.update(delta: 0.01)
        guard var boss = simulation.snapshot.targets.first(where: {
            $0.waveRole == .boss
        }) else {
            Issue.record("Expected Endless boss")
            return
        }
        boss.hitPoints = boss.maximumHitPoints * 0.60
        boss.maximumShieldHitPoints = 40
        boss.shieldHitPoints = 0
        boss.burnRemaining = 4
        boss.freezeRemaining = 3
        boss.reverseRemaining = 3
        boss.stunRemaining = 2
        boss.tidalSlowRemaining = 2
        boss.undertowSlowRemaining = 2
        boss.magnetRemaining = 2
        boss.gravityPullCenter = .init(x: 0, y: 0.5)
        boss.gravityPullRemaining = 1
        boss.gravityPullStrength = 4
        simulation.replaceTargetsForTesting([boss])

        let events = simulation.update(delta: 0.01)
        guard let refreshed = simulation.snapshot.targets.first else {
            Issue.record("Expected refreshed boss")
            return
        }
        #expect(refreshed.shieldHitPoints == 40)
        #expect(refreshed.burnRemaining == 0)
        #expect(refreshed.freezeRemaining == 0)
        #expect(refreshed.reverseRemaining == 0)
        #expect(refreshed.stunRemaining == 0)
        #expect(refreshed.tidalSlowRemaining == 0)
        #expect(refreshed.undertowSlowRemaining == 0)
        #expect(refreshed.magnetRemaining == 0)
        #expect(refreshed.gravityPullRemaining == 0)
        #expect(events.contains {
            if case .enemyShieldRefreshed = $0 { true } else { false }
        })
    }

    @Test func enemyShieldPresentationTracksRegularAndBossTargets() {
        var regular = TargetState(
            id: 20_010,
            kind: .enemy(.coneRunner),
            position: .init(x: 0, y: 0.5),
            hitPoints: 100,
            maximumHitPoints: 100,
            shieldHitPoints: 50,
            maximumShieldHitPoints: 100,
            phase: 0
        )
        let node = GameNodeFactory.target(regular, world: .earth)
        let aura = node.childNode(withName: "enemy-shield-aura")
        let regularBar = node.childNode(withName: "enemy-shield-regular")
        let bossBar = node.childNode(withName: "enemy-shield-boss")
        let regularFill = regularBar?.childNode(withName: "enemy-shield-fill")
        #expect(aura?.isHidden == false)
        #expect(regularBar?.isHidden == false)
        #expect(bossBar?.isHidden == true)
        #expect(abs((regularFill?.xScale ?? 0) - 0.5) < 0.001)

        regular.bossTier = .megaBoss
        regular.waveRole = .boss
        GameNodeFactory.configureTarget(node, target: regular, world: .earth)
        let bossFill = bossBar?.childNode(withName: "enemy-shield-fill")
        #expect(regularBar?.isHidden == true)
        #expect(bossBar?.isHidden == false)
        #expect(abs((bossFill?.xScale ?? 0) - 0.5) < 0.001)

        regular.shieldHitPoints = 0
        GameNodeFactory.configureTarget(node, target: regular, world: .earth)
        #expect(aura?.isHidden == true)
        #expect(bossBar?.isHidden == true)
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
