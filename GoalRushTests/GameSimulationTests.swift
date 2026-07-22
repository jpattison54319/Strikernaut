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

    @Test func wideVolleyCreatesVisibleMultiLaneSpread() {
        let simulation = GameSimulation(level: GameContent.level(1), progress: .newPlayer, assistMode: false, seed: 7)
        simulation.apply(.oneTwo)
        for _ in 0..<23 { _ = simulation.update(delta: 0.05) }

        let friendly = simulation.snapshot.projectiles.filter { !$0.hostile }
        #expect(friendly.count == 3)
        #expect(friendly.map(\.velocity.x).min() ?? 0 < -0.30)
        #expect(friendly.map(\.velocity.x).max() ?? 0 > 0.30)
        #expect(friendly.contains { abs($0.velocity.x) < 0.001 })
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
        #expect(GameContent.levels.count == 20)
        #expect(GameContent.worlds.count == 2)
        #expect(GameContent.levels(in: .earth).count == 10)
        #expect(GameContent.levels(in: .mars).count == 10)
        for level in GameContent.levels {
            #expect(!level.enemies.isEmpty)
            #expect(!level.objects.isEmpty)
            #expect(level.duration > 60)
            #expect(level.firstClearBonus > level.replayBonus)
        }
        #expect(GameContent.level(10).hasBoss)
        #expect(GameContent.level(20).hasBoss)
        #expect(GameContent.level(11).world == .mars)
    }

    @Test func endlessDifficultyContinuesGrowingAtHighWaves() {
        #expect(EndlessRules.healthMultiplier(wave: 100) > EndlessRules.healthMultiplier(wave: 10))
        #expect(EndlessRules.healthMultiplier(wave: 1_000) > EndlessRules.healthMultiplier(wave: 100))
        #expect(EndlessRules.damageMultiplier(wave: 1_000) > EndlessRules.damageMultiplier(wave: 100))
        #expect(EndlessRules.speedMultiplier(wave: 1_000) > EndlessRules.speedMultiplier(wave: 100))
        #expect(EndlessRules.spawnInterval(wave: 10_000) == 0.32)
        #expect(EndlessRules.packSize(wave: 10_000) == 4)
    }

    @Test func equippedGearChangesPermanentStatsAndSetBonuses() {
        var earth = PlayerProgress.newPlayer
        let earthItems = GearCatalog.items(for: .earth)
        earth.unlockedGear = Set(earthItems.map(\.id))
        earth.equippedGear = Dictionary(uniqueKeysWithValues: earthItems.map { ($0.slot, $0.id) })
        let earthStats = PlayerStats(progress: earth)
        #expect(abs(earthStats.maxStamina - 110) < 0.001)
        #expect(abs(earthStats.movementResponse - 8.64) < 0.001)
        #expect(abs(earthStats.kickCooldown - 1.0528) < 0.001)
        #expect(abs(earthStats.ballSpeed - 0.9504) < 0.001)
        #expect(abs(earthStats.criticalChance - 0.07) < 0.001)
        #expect(earthStats.startingShields == 1)

        var mars = PlayerProgress.newPlayer
        let marsItems = GearCatalog.items(for: .mars)
        mars.unlockedGear = Set(marsItems.map(\.id))
        mars.equippedGear = Dictionary(uniqueKeysWithValues: marsItems.map { ($0.slot, $0.id) })
        let marsStats = PlayerStats(progress: mars)
        #expect(abs(marsStats.ballDamage - 11.5) < 0.001)
        #expect(abs(marsStats.kickCooldown - 1.0304) < 0.001)
        #expect(abs(marsStats.criticalChance - 0.10) < 0.001)
        #expect(marsStats.homingStrength > 0)
        #expect(marsStats.extraPierce == 1)
    }

    @Test func equippedGearReplacesItsBaseBodyPartVisual() {
        for id in GearID.allCases {
            let slot = GearCatalog.item(id).slot
            let player = GameNodeFactory.player(loadout: GearLoadout(equipped: [slot: id]))
            let body = player.childNode(withName: "body")

            switch slot {
            case .head, .torso, .hands:
                let slotNode = body?.childNode(withName: "slot-\(slot.rawValue)")
                #expect(slotNode?.childNode(withName: "variant-\(id.rawValue)") != nil)
                #expect(slotNode?.childNode(withName: "variant-base") == nil)
                #expect(slotNode?.children.count == 1)
            case .legs, .feet:
                let joint = body?
                    .childNode(withName: "slot-legs")?
                    .childNode(withName: "kicking-leg")
                let prefix = slot == .legs ? "leg" : "foot"
                #expect(joint?.childNode(withName: "\(prefix)-variant-\(id.rawValue)") != nil)
                #expect(joint?.childNode(withName: "\(prefix)-variant-base") == nil)
            }
        }
    }

    @Test func replacedLegVisualsStillRunTheKickAnimation() {
        let loadout = GearLoadout(equipped: [.legs: .marsGuards, .feet: .marsBoots])
        let player = GameNodeFactory.player(loadout: loadout)
        GameNodeFactory.animateKick(on: player, reducedMotion: false)
        let legs = player.childNode(withName: "body")?.childNode(withName: "slot-legs")
        #expect(legs?.childNode(withName: "kicking-leg")?.action(forKey: "kick-leg") != nil)
        #expect(legs?.childNode(withName: "plant-leg")?.action(forKey: "plant-leg") != nil)
    }

    @Test func everyEnemyHasAnArticulatedPresentationRig() {
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
            if enemy == .coneRunner {
                #expect(rig?.childNode(withName: "left-leg") == nil)
                #expect(rig?.childNode(withName: "right-leg") == nil)
            } else {
                #expect(rig?.childNode(withName: "left-leg") != nil)
                #expect(rig?.childNode(withName: "right-leg") != nil)
                #expect(rig?.childNode(withName: "left-arm") != nil)
                #expect(rig?.childNode(withName: "right-arm") != nil)
            }
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
        let startingLegRotation = node.childNode(withName: "motion-body/left-leg")?.zRotation

        GameNodeFactory.animateTarget(on: node, kind: target.kind, phase: 0.17, reducedMotion: false)

        #expect(node.position == startingRootPosition)
        #expect(node.childNode(withName: "motion-body/left-leg")?.zRotation != startingLegRotation)
        #expect(node.childNode(withName: "health-background")?.position.y == 43)
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

    @Test func firstEndlessWaveClearsAndOffersAnotherDraft() {
        var progress = PlayerProgress.newPlayer
        for track in UpgradeTrack.allCases { progress.setRank(5, for: track) }
        let items = GearCatalog.items(for: .earth)
        progress.unlockedGear = Set(items.map(\.id))
        progress.equippedGear = Dictionary(uniqueKeysWithValues: items.map { ($0.slot, $0.id) })
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
        let simulation = GameSimulation(level: GameContent.level(2), progress: .newPlayer, assistMode: true, seed: 8)
        var sawCheckpoint = false
        for _ in 0..<800 {
            let events = simulation.update(delta: 0.05)
            if events.contains(where: { if case .checkpoint = $0 { true } else { false } }) {
                sawCheckpoint = true
                break
            }
        }
        #expect(sawCheckpoint)
    }

    @Test func campaignBonusesFundEarlyRanksButNotMaximumBuild() {
        let campaign = GameContent.levels.reduce(0) { $0 + $1.firstClearBonus }
        let firstTwoRanksAcrossAllTracks = UpgradeTrack.allCases.count * (UpgradeRules.costs[0] + UpgradeRules.costs[1])
        let maximumBuild = UpgradeTrack.allCases.count * UpgradeRules.costs.reduce(0, +)
        #expect(campaign >= firstTwoRanksAcrossAllTracks)
        #expect(campaign < maximumBuild)
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
        for _ in 0..<600 {
            _ = forgiving.update(delta: 0.05)
            _ = standard.update(delta: 0.05)
        }
        let forgivingHP = forgiving.snapshot.targets.map(\.maximumHitPoints).max() ?? 0
        let standardHP = standard.snapshot.targets.map(\.maximumHitPoints).max() ?? 0
        // Level 2 scales up +8% per level while Level 1 scales down 15%.
        #expect(forgivingHP < standardHP)
    }

    @Test func levelOneCheckpointRestoresStamina() {
        let simulation = GameSimulation(level: GameContent.level(1), progress: .newPlayer, assistMode: false, seed: 3)
        // Drain stamina by standing still while enemies reach the line.
        var sawCheckpoint = false
        for _ in 0..<3_000 where !sawCheckpoint {
            sawCheckpoint = simulation.update(delta: 0.05).contains { event in
                if case .checkpoint = event { return true }
                return false
            }
        }
        #expect(sawCheckpoint)
        #expect(simulation.snapshot.stamina > 0)
    }
}
