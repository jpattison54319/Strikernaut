import Foundation

final class GameSimulation {
    private struct TargetDamageResolution {
        let shieldDamage: Double
        let healthDamage: Double
        let wasShielded: Bool
        let brokeShield: Bool

        var appliedDamage: Double { shieldDamage + healthDamage }
        var blocksEffects: Bool { wasShielded }
    }

    private(set) var snapshot: SimulationSnapshot
    private let mode: RunMode
    private let level: LevelDefinition?
    private let stats: PlayerStats
    private let character: CharacterDefinition
    private let assistMode: Bool
    private var random: SeededGenerator
    private var targetPlayerX = 0.0
    private var spawnClock = 0.0
    private var pendingCampaignEnemySpawns = 0
    private var campaignEnemyStaggerClock = 0.0
    private var kickClock = 0.0
    private var nextIdentifier = 1
    private var abilities: [AbilityKind: Int] = [:]
    private var specialBallRanks: [TemporaryBallAbility: Int] = [:]
    private var finished = false
    private var deathSaveDamageGraceRemaining = 0.0
    private var bossSpawned = false
    private var bossDefeated = false
    private var bossPhase = 1
    private var powerUpSpawned = false
    private var nextPowerUpDefeat = 0
    private var bossPowerUpClock = 7.0
    private var bossSignatureClock = 6.0
    private var pendingReinforcementPhases: [Int] = []
    private var reinforcementQuietClock = 0.0
    private var bossSupportSpawnClock = 1.5
    private var endlessInitialBossSupportSpawned = false
    private var endlessBossReinforcementsWereActive = false
    private var pendingMeteorMarkers = 0
    private var meteorMarkerClock = 0.0
    private var kickCount = 0
    private static let comboMilestones: Set<Int> = [5, 10, 15, 25, 50, 100]
    private var comboCount = 0
    private var removedTargetIDs = Set<Int>()
    private var removedProjectileIDs = Set<Int>()
    private var hitTargetIDs = Set<Int>()
    private var statusEffectPreview: TemporaryBallAbility?
    private var fieldObjectPreview: FieldObjectKind?
    private var fieldObjectPreviewSpawned = false
    private var shockwaveBurstsRemaining = 0
    private var shockwaveBurstClock = 0.0
    private var worldEffectElapsed = 0.0
    private var nextLunarEffectTime = 10.0
    private var pendingLunarDebrisStrikes = 0
    private var lunarDebrisClock = 0.0
    private var marsDefeatCount = 0
    private var pendingVolatileCorePositions: [Vector2] = []
    private var worldHazardDelayRemaining = 0.0
    private var worldHazardActiveRemaining = 0.0
    private var worldHazardDirection = 0.0
    private var playerDriftVelocity = 0.0
    private var characterAnchorRemaining = 0.0
    private var timeBreakRemaining = 0.0
    private var timeBreakTargetIDs = Set<Int>()
    private var galeLandingHitCounts: [Int: [Int: Int]] = [:]
    private var world: WorldID { snapshot.world }

    convenience init(level: LevelDefinition, progress: PlayerProgress, assistMode: Bool, seed: UInt64) {
        self.init(mode: .campaign(level: level.number), progress: progress, assistMode: assistMode, seed: seed)
    }

    init(
        mode: RunMode,
        progress: PlayerProgress,
        assistMode: Bool,
        seed: UInt64,
        checkpoint: RunSimulationCheckpoint? = nil
    ) {
        self.mode = mode
        self.level = mode.campaignLevel.map(GameContent.level)
        if let checkpoint, checkpoint.mode == mode {
            self.stats = checkpoint.stats
            self.character = CharacterCatalog.character(checkpoint.characterID)
            self.assistMode = checkpoint.assistMode
            self.random = checkpoint.random
            self.snapshot = checkpoint.snapshot.simulationSnapshot
            targetPlayerX = checkpoint.targetPlayerX
            kickClock = checkpoint.kickClock
            nextIdentifier = checkpoint.nextIdentifier
            abilities = checkpoint.abilities
            specialBallRanks = checkpoint.specialBallRanks
            deathSaveDamageGraceRemaining = checkpoint.deathSaveDamageGraceRemaining
            nextPowerUpDefeat = checkpoint.nextPowerUpDefeat
            kickCount = checkpoint.kickCount
            comboCount = checkpoint.comboCount
            worldEffectElapsed = checkpoint.worldEffectElapsed
            nextLunarEffectTime = checkpoint.nextLunarEffectTime
            pendingLunarDebrisStrikes = checkpoint.pendingLunarDebrisStrikes
            lunarDebrisClock = checkpoint.lunarDebrisClock
            marsDefeatCount = checkpoint.marsDefeatCount
            characterAnchorRemaining = checkpoint.characterAnchorRemaining
            return
        }
        self.stats = PlayerStats(progress: progress, mode: mode)
        self.character = CharacterCatalog.character(progress.selectedCharacter)
        self.assistMode = assistMode
        self.random = SeededGenerator(seed: seed)
        let openingWorld = level?.world ?? EndlessRules.world(for: 1)
        let waveCount = level?.waveCount ?? Int.max
        let openingBossWave = level.map {
            CampaignBalance.wave(1, for: $0).isBossWave
        } ?? EndlessRules.isBossWave(1)
        let openingQuota = level.map {
            CampaignBalance.wave(1, for: $0).enemyQuota
        } ?? EndlessRules.enemyQuota(wave: 1)
        self.snapshot = SimulationSnapshot(
            world: openingWorld,
            playerX: 0,
            stamina: stats.maxStamina,
            maxStamina: stats.maxStamina,
            elapsed: 0,
            tokens: 0,
            targets: [],
            projectiles: [],
            characterAttacks: [],
            galeBounces: [],
            galeInterceptors: [],
            haloRings: [],
            magneticTraps: [],
            tidalWaves: [],
            bossHazards: [],
            galeOrbitCount: 0,
            shieldCharges: stats.startingShields,
            wave: 1,
            waveElapsed: 0,
            waveDefeats: 0,
            waveEnemyQuota: openingBossWave ? 1 : openingQuota,
            isBossWave: openingBossWave,
            score: 0,
            isEndless: mode.isEndless,
            combo: 0,
            comboFraction: 0,
            bestCombo: 0,
            targetsDefeated: 0,
            characterAbilityDefeats: 0,
            bossesDefeated: 0,
            waveCount: waveCount,
            activeTemporaryAbility: nil,
            temporaryAbilityRemaining: 0,
            temporaryAbilityDuration: 0,
            characterAbilityCharge: 0,
            characterAbilityReady: false
        )
        scheduleWavePowerUp()
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let previewIndex = arguments.firstIndex(of: "--status-effect-preview"),
           arguments.indices.contains(previewIndex + 1) {
            statusEffectPreview = TemporaryBallAbility(rawValue: arguments[previewIndex + 1])
        }
        if let previewIndex = arguments.firstIndex(of: "--field-object-preview"),
           arguments.indices.contains(previewIndex + 1) {
            fieldObjectPreview = FieldObjectKind(rawValue: arguments[previewIndex + 1])
            powerUpSpawned = true
        }
        if let level,
           let waveArgumentIndex = arguments.firstIndex(of: "--campaign-wave"),
           arguments.indices.contains(waveArgumentIndex + 1),
           let requestedWave = Int(arguments[waveArgumentIndex + 1]) {
            snapshot.wave = min(max(requestedWave, 1), level.waveCount)
            configureWaveObjective()
        }
        if mode.isEndless,
           let waveArgumentIndex = arguments.firstIndex(of: "--endless-wave"),
           arguments.indices.contains(waveArgumentIndex + 1),
           let requestedWave = Int(arguments[waveArgumentIndex + 1]) {
            snapshot.wave = max(1, requestedWave)
            snapshot.world = EndlessRules.world(for: snapshot.wave)
            configureWaveObjective()
        }
        if let comboArgumentIndex = arguments.firstIndex(of: "--combo-preview"),
           arguments.indices.contains(comboArgumentIndex + 1),
           let requestedCombo = Int(arguments[comboArgumentIndex + 1]) {
            comboCount = max(0, requestedCombo)
            snapshot.combo = comboCount
            snapshot.comboFraction = comboCount > 0 ? 1 : 0
        }
        if level != nil, arguments.contains("--boss-preview") {
            powerUpSpawned = true
        } else if level != nil, arguments.contains("--wave-complete-preview") {
            snapshot.waveDefeats = snapshot.waveEnemyQuota
            powerUpSpawned = true
        } else if arguments.contains("--power-up-preview") {
            nextPowerUpDefeat = 0
            bossPowerUpClock = 0
        }
        if arguments.contains("--enemy-swarm-preview") {
            let enemyPool = level?.enemies ?? [.coneRunner]
            let positions: [Vector2] = [
                .init(x: -0.66, y: 0.80),
                .init(x: -0.24, y: 0.76),
                .init(x: 0.24, y: 0.76),
                .init(x: 0.66, y: 0.80),
                .init(x: -0.46, y: 0.58),
                .init(x: 0, y: 0.54),
                .init(x: 0.46, y: 0.58),
            ]
            for (index, position) in positions.enumerated() {
                spawnEnemy(
                    enemyPool[index % max(1, enemyPool.count)],
                    x: position.x,
                    y: position.y
                )
            }
        }
#endif
        bossSignatureClock = 6 * activeAttackCadenceMultiplier
        nextLunarEffectTime = 10 * activeAttackCadenceMultiplier
    }

    func makeRunCheckpoint() -> RunSimulationCheckpoint {
        RunSimulationCheckpoint(
            mode: mode,
            stats: stats,
            characterID: character.id,
            assistMode: assistMode,
            random: random,
            targetPlayerX: targetPlayerX,
            kickClock: kickClock,
            nextIdentifier: nextIdentifier,
            abilities: abilities,
            specialBallRanks: specialBallRanks,
            deathSaveDamageGraceRemaining: deathSaveDamageGraceRemaining,
            nextPowerUpDefeat: nextPowerUpDefeat,
            kickCount: kickCount,
            comboCount: comboCount,
            worldEffectElapsed: worldEffectElapsed,
            nextLunarEffectTime: nextLunarEffectTime,
            pendingLunarDebrisStrikes: pendingLunarDebrisStrikes,
            lunarDebrisClock: lunarDebrisClock,
            marsDefeatCount: marsDefeatCount,
            characterAnchorRemaining: characterAnchorRemaining,
            snapshot: RunWaveSnapshot(snapshot: snapshot)
        )
    }

    func setPlayerTarget(x: Double) {
        targetPlayerX = min(0.92, max(-0.92, x))
    }

    @discardableResult
    func reviveAfterDeathSave() -> Double? {
        guard finished, snapshot.stamina <= 0 else { return nil }

        finished = false
        let restoredStamina = snapshot.maxStamina * DeathSaveRules.restoredStaminaFraction
        snapshot.stamina = restoredStamina
        deathSaveDamageGraceRemaining = DeathSaveRules.damageGracePeriod

        snapshot.projectiles.removeAll(where: \.hostile)
        snapshot.bossHazards.removeAll()
        pendingMeteorMarkers = 0
        meteorMarkerClock = 0
        pendingLunarDebrisStrikes = 0
        lunarDebrisClock = 0
        pendingVolatileCorePositions.removeAll(keepingCapacity: true)
        worldHazardDelayRemaining = 0
        worldHazardActiveRemaining = 0
        worldHazardDirection = 0
        playerDriftVelocity = 0
        nextLunarEffectTime = max(
            nextLunarEffectTime,
            worldEffectElapsed + DeathSaveRules.damageGracePeriod
        )
        bossSignatureClock = max(
            bossSignatureClock,
            DeathSaveRules.damageGracePeriod
        )

        return restoredStamina
    }

    func apply(_ ability: AbilityKind) {
        let maximum = mode.isEndless ? Int.max : 3
        let newRank = min(maximum, abilities[ability, default: 0] + 1)
        abilities[ability] = newRank
        if ability == .cleanSheet {
            snapshot.shieldCharges += 1
        }
        if ability == .secondWind {
            let recovery = mode.isEndless
                ? EndlessAbilityRules.secondWindImmediateRecovery(rank: newRank)
                : 10 + Double(newRank) * 4
            snapshot.stamina = min(
                snapshot.maxStamina,
                snapshot.stamina + recovery
            )
        }
    }

    func apply(_ choice: RunUpgradeChoice) {
        switch choice {
        case .ability(let ability):
            apply(ability)
        case .specialBall(let ability):
            guard mode.isEndless, EndlessSpecialBallRules.isAvailable(ability) else { return }
            specialBallRanks[ability, default: 0] += 1
        }
    }

    func abilityRank(_ ability: AbilityKind) -> Int { abilities[ability, default: 0] }
    func specialBallRank(_ ability: TemporaryBallAbility) -> Int {
        specialBallRanks[ability, default: 0]
    }

#if DEBUG
    func fullyChargeCharacterAbilityForTesting() {
        snapshot.characterAbilityCharge = CharacterAbilityChargeBalance.fullCharge
        snapshot.characterAbilityReady = true
    }

    func replaceTargetsForTesting(_ targets: [TargetState]) {
        snapshot.targets = targets
    }

    func setCampaignWaveForTesting(_ wave: Int, elapsed: Double = 0) {
        guard let level else { return }
        snapshot.wave = min(max(wave, 1), level.waveCount)
        resetWaveRuntime()
        snapshot.waveElapsed = max(0, elapsed)
    }

    func setEndlessWaveForTesting(_ wave: Int) {
        guard mode.isEndless else { return }
        snapshot.wave = max(1, wave)
        snapshot.world = EndlessRules.world(for: snapshot.wave)
        resetWaveRuntime()
    }

    func setWaveDefeatsForTesting(_ defeats: Int) {
        snapshot.waveDefeats = min(max(defeats, 0), snapshot.waveEnemyQuota)
    }

    func forceBossSignatureAttackForTesting() {
        bossSignatureClock = 0
    }

    func completeCurrentWaveForTesting() -> [SimulationEvent] {
        var events: [SimulationEvent] = []
        completeWave(events: &events)
        return events
    }

    func spawnFriendlyProjectileForTesting(
        pierce: Int,
        damage: Double? = nil,
        temporaryAbility: TemporaryBallAbility? = nil,
        endlessEffects: Set<TemporaryBallAbility> = []
    ) {
        spawnProjectile(
            x: snapshot.playerX,
            velocityX: 0,
            damage: damage ?? stats.ballDamage,
            pierce: pierce,
            hostile: false,
            critical: false,
            temporaryAbility: temporaryAbility,
            endlessEffects: endlessEffects
        )
    }

    func spawnHostileProjectileForTesting(
        x: Double,
        y: Double,
        damage: Double = 10
    ) {
        spawnProjectile(
            x: x,
            y: y,
            velocityX: 0,
            damage: damage,
            pierce: 0,
            hostile: true,
            critical: false
        )
    }

    func setTokensForTesting(_ tokens: Int) {
        snapshot.tokens = max(0, tokens)
    }

    func setStaminaForTesting(_ stamina: Double) {
        snapshot.stamina = min(snapshot.maxStamina, max(0, stamina))
    }

    var deathSaveDamageGraceRemainingForTesting: TimeInterval {
        deathSaveDamageGraceRemaining
    }

    func forceDefeatForTesting() -> [SimulationEvent] {
        snapshot.stamina = 0
        finished = false
        var events: [SimulationEvent] = []
        evaluateFinish(events: &events)
        return events
    }
#endif

    func activateTemporaryAbility(_ ability: TemporaryBallAbility) {
        snapshot.activeTemporaryAbility = ability
        snapshot.temporaryAbilityDuration = TemporaryAbilityRules.duration(for: ability)
        snapshot.temporaryAbilityRemaining = snapshot.temporaryAbilityDuration
    }

    @discardableResult
    func activateCharacterAbility() -> [SimulationEvent] {
        guard snapshot.characterAbilityReady else { return [] }
        snapshot.characterAbilityCharge = 0
        snapshot.characterAbilityReady = false
        var events: [SimulationEvent] = [.characterAbilityActivated(character.ability)]

        switch character.ability {
        case .pinballBlitz:
            spawnPinballBlitz()
        case .timeBreak:
            let affectedPositions = snapshot.targets.filter { !isPowerUp($0) }.map(\.position)
            timeBreakTargetIDs = Set(snapshot.targets.filter { !isPowerUp($0) }.map(\.id))
            timeBreakRemaining = 5.5
            for index in snapshot.targets.indices {
                guard !isPowerUp(snapshot.targets[index]),
                      !snapshot.targets[index].isShielded else { continue }
                snapshot.targets[index].freezeRemaining = max(snapshot.targets[index].freezeRemaining, 5.5)
            }
            events.append(.characterAbilityTargets(.timeBreak, affectedPositions))
        case .meteorVolley:
            spawnMeteorVolley()
        case .lastStand:
            let previousStamina = snapshot.stamina
            snapshot.stamina = min(snapshot.maxStamina, snapshot.stamina + snapshot.maxStamina * 0.35)
            snapshot.shieldCharges += 2
            if snapshot.stamina > previousStamina {
                events.append(.heal(snapshot.stamina - previousStamina, .init(x: snapshot.playerX, y: 0.16)))
            }
            shockwaveBurstsRemaining = 3
            shockwaveBurstClock = 0.28
            events.append(spawnShockwaveBurst())
        case .stormbreak:
            characterAnchorRemaining = 5.5
            snapshot.galeOrbitCount = 3
            spawnGaleBounces()
        case .ringRelay:
            spawnHaloRing()
        case .poleShift:
            spawnMagneticTraps()
        case .tidalBreak:
            spawnTidalWaves()
        }
        // Ability defeats do not recharge the same ability and create an
        // immediate loop; only normal combat defeats build the next charge.
        snapshot.characterAbilityCharge = 0
        snapshot.characterAbilityReady = false
        return events
    }

    private func spawnPinballBlitz() {
        let launches: [(x: Double, vx: Double, vy: Double)] = [
            (snapshot.playerX - 0.045, -2.35, 0.21),
            (snapshot.playerX, 2.65, 0.25),
            (snapshot.playerX + 0.045, -2.95, 0.29)
        ]
        for launch in launches {
            snapshot.projectiles.append(ProjectileState(
                id: identifier(),
                position: .init(x: min(0.84, max(-0.84, launch.x)), y: 0.18),
                velocity: .init(x: launch.vx, y: launch.vy),
                damage: stats.ballDamage * 1.65,
                remainingPierces: .max,
                hostile: false,
                isCritical: true,
                temporaryAbility: nil,
                canSplit: false,
                characterProjectile: .pinballBlitz,
                remainingLifetime: 4.4
            ))
        }
    }

    private func spawnGaleBounces() {
        let activationID = identifier()
        galeLandingHitCounts[activationID] = [:]
        let destinations = [-0.78, -0.39, 0, 0.39, 0.78]
        for (lane, destinationX) in destinations.enumerated() {
            let origin = Vector2(x: snapshot.playerX, y: 0.18)
            snapshot.galeBounces.append(GaleBounceState(
                id: identifier(),
                activationID: activationID,
                lane: lane,
                startPosition: origin,
                destinationX: destinationX,
                position: origin,
                previousPosition: origin,
                elapsed: 0,
                duration: 3.8,
                completedLandings: 0
            ))
        }
    }

    private func spawnHaloRing() {
        let center = Vector2(x: snapshot.playerX, y: 0.18)
        snapshot.haloRings.append(HaloRingState(
            id: identifier(),
            startX: snapshot.playerX,
            center: center,
            previousCenter: center,
            elapsed: 0,
            duration: 3.6,
            radius: 0.80,
            damage: stats.ballDamage * 2
        ))
    }

    private func spawnMagneticTraps() {
        let formation: [Vector2] = [
            .init(x: -0.76, y: 0.42),
            .init(x: 0, y: 0.42),
            .init(x: 0.76, y: 0.42),
            .init(x: -0.76, y: 0.79),
            .init(x: 0, y: 0.79),
            .init(x: 0.76, y: 0.79),
        ]
        let enemies = snapshot.targets
            .filter { if case .enemy = $0.kind { true } else { false } }
            .sorted { $0.position.y < $1.position.y }
        var claimedTargetIDs = Set<Int>()

        for index in 0..<6 {
            let landingPosition = formation[index]
            let target = enemies
                .filter {
                    !claimedTargetIDs.contains($0.id)
                        && $0.position.y >= landingPosition.y
                }
                .min {
                    hypot(
                        $0.position.x - landingPosition.x,
                        $0.position.y - landingPosition.y
                    ) < hypot(
                        $1.position.x - landingPosition.x,
                        $1.position.y - landingPosition.y
                    )
                }
            if let target {
                claimedTargetIDs.insert(target.id)
            }
            let origin = Vector2(x: snapshot.playerX, y: 0.16)
            snapshot.magneticTraps.append(MagneticTrapState(
                id: identifier(),
                startPosition: origin,
                landingPosition: landingPosition,
                position: origin,
                targetID: target?.id,
                delayRemaining: Double(index) * 0.12,
                flightElapsed: 0,
                flightDuration: 0.36,
                armedRemaining: 8,
                captureRemaining: 0,
                tickClock: 0,
                ticksRemaining: 8,
                tickDamage: stats.ballDamage * 0.55,
                hasLanded: false
            ))
        }
    }

    private func spawnTidalWaves() {
        for round in 0..<3 {
            snapshot.tidalWaves.append(TidalWaveState(
                id: identifier(),
                lane: .middle,
                round: round + 1,
                positionY: 0.18,
                previousPositionY: 0.18,
                delayRemaining: Double(round) * 0.82,
                elapsed: 0,
                duration: 1.24,
                damage: stats.ballDamage * 1.35,
                push: 0.18
            ))
        }
    }

    private func spawnMeteorVolley() {
        let targets = snapshot.targets
            .filter { !isPowerUp($0) }
            .sorted { $0.position.y < $1.position.y }
            .prefix(7)
        var destinations: [(position: Vector2, targetID: Int?)] = targets.map {
            ($0.position, Optional($0.id))
        }
        let fieldPattern: [Vector2] = [
            .init(x: -0.62, y: 0.42),
            .init(x: 0, y: 0.52),
            .init(x: 0.62, y: 0.42),
            .init(x: -0.38, y: 0.72),
            .init(x: 0.38, y: 0.72),
            .init(x: -0.68, y: 0.90),
            .init(x: 0.68, y: 0.90),
        ]
        var patternIndex = 0
        while destinations.count < 7 {
            let position = fieldPattern[patternIndex % fieldPattern.count]
            let tooCloseToAssignedTarget = destinations.contains {
                hypot(
                    $0.position.x - position.x,
                    $0.position.y - position.y
                ) < 0.22
            }
            patternIndex += 1
            if !tooCloseToAssignedTarget || patternIndex > fieldPattern.count * 2 {
                destinations.append((position, nil))
            }
        }

        for (index, destination) in destinations.enumerated() {
            let lateralOffset = index.isMultiple(of: 2) ? -0.34 : -0.24
            let start = Vector2(
                x: min(0.90, max(-0.90, destination.position.x + lateralOffset)),
                y: 1.58
            )
            snapshot.characterAttacks.append(CharacterAttackState(
                id: identifier(),
                kind: .meteor,
                position: start,
                startPosition: start,
                destination: destination.position,
                targetID: destination.targetID,
                damage: stats.ballDamage * 4.2,
                awardsAbilityCharge: false,
                delayRemaining: Double(index) * 0.11,
                elapsed: 0,
                duration: 0.92,
                width: 0.86
            ))
        }
    }

    private func spawnShockwaveBurst(
        width: Double = 0.18,
        damageMultiplier: Double = 0.80
    ) -> SimulationEvent {
        let origin = Vector2(x: snapshot.playerX, y: 0.18)
        snapshot.characterAttacks.append(CharacterAttackState(
            id: identifier(),
            kind: .shockwave,
            position: origin,
            startPosition: origin,
            destination: .init(x: origin.x, y: 1.08),
            targetID: nil,
            damage: stats.ballDamage * damageMultiplier,
            awardsAbilityCharge: false,
            delayRemaining: 0,
            elapsed: 0,
            duration: 0.90,
            width: width
        ))
        return .characterShockwaveBurst(origin)
    }

    private func updateCharacterAttackSchedule(delta: Double, events: inout [SimulationEvent]) {
        characterAnchorRemaining = max(0, characterAnchorRemaining - delta)
        if timeBreakRemaining > 0 {
            let previous = timeBreakRemaining
            timeBreakRemaining = max(0, timeBreakRemaining - delta)
            if previous > 0, timeBreakRemaining == 0 {
                resolveTimeBreakShatter(events: &events)
            }
        }
        guard shockwaveBurstsRemaining > 0 else { return }
        shockwaveBurstClock -= delta
        if shockwaveBurstClock <= 0 {
            shockwaveBurstsRemaining -= 1
            shockwaveBurstClock += 0.30
            events.append(spawnShockwaveBurst())
        }
    }

    private func resolveTimeBreakShatter(events: inout [SimulationEvent]) {
        var shatteredPositions: [Vector2] = []
        hitTargetIDs.removeAll(keepingCapacity: true)
        for index in snapshot.targets.indices {
            let target = snapshot.targets[index]
            guard timeBreakTargetIDs.contains(target.id),
                  !isPowerUp(target) else { continue }
            let damage = stats.ballDamage * 2
            let resolution = applyTargetDamage(
                damage,
                at: index,
                events: &events
            )
            shatteredPositions.append(target.position)
            events.append(impactEvent(
                for: snapshot.targets[index],
                damage: resolution.appliedDamage,
                flavor: .ice,
                critical: true,
                delivery: .area,
                impulse: .init(x: 0, y: 0.22)
            ))
            registerDefeatIfNeeded(
                at: index,
                awardsAbilityCharge: false,
                characterAbilityCredit: true,
                events: &events
            )
        }
        if !hitTargetIDs.isEmpty {
            snapshot.targets.removeAll { hitTargetIDs.contains($0.id) }
        }
        snapshot.projectiles.removeAll(where: \.hostile)
        timeBreakTargetIDs.removeAll(keepingCapacity: true)
        events.append(.characterAbilityEffect(.timeShatter(shatteredPositions)))
    }

    private func isPowerUp(_ target: TargetState) -> Bool {
        if case .powerUp = target.kind { return true }
        return false
    }

    func kickInterval(atAbilityRank rank: Int) -> Double {
        let safeRank = max(0, rank)
        if mode.isEndless {
            return EndlessAbilityRules.renderedKickInterval(
                base: stats.kickCooldown,
                rank: safeRank
            )
        }
        return max(0.14, stats.kickCooldown * pow(0.82, Double(safeRank)))
    }

    func quickReleaseDamageMultiplier(atAbilityRank rank: Int) -> Double {
        guard mode.isEndless else { return 1 }
        return EndlessAbilityRules.quickReleaseDamageMultiplier(
            base: stats.kickCooldown,
            rank: rank
        )
    }

    func update(delta rawDelta: Double) -> [SimulationEvent] {
        guard !finished else { return [] }
        let delta = min(max(rawDelta, 0), 1.0 / 20.0)
        var events: [SimulationEvent] = []
        if finishAfterStaminaDepletion(events: &events) { return events }
        deathSaveDamageGraceRemaining = max(
            0,
            deathSaveDamageGraceRemaining - delta
        )
        snapshot.elapsed += delta
        snapshot.waveElapsed += delta
        updateTemporaryAbility(delta: delta)
        updateWorldEffect(delta: delta, events: &events)
        if finishAfterStaminaDepletion(events: &events) { return events }
        updatePlayer(delta: delta)
        updateCharacterAttackSchedule(delta: delta, events: &events)
        updateSpawning(delta: delta)
        updateBossSupport(delta: delta)
        updatePowerUpSpawning(delta: delta)
        updateBossAttackSchedule(delta: delta, events: &events)
        updateBossHazards(delta: delta, events: &events)
        updateKicking(delta: delta, events: &events)
        updateGaleInterceptors(delta: delta, events: &events)
        updateMagneticTraps(delta: delta, events: &events)
        updateTargets(delta: delta, events: &events)
        if finishAfterStaminaDepletion(events: &events) { return events }
        if finishBossWaveIfNeeded(events: &events) { return events }
        updateGaleBounces(delta: delta, events: &events)
        updateHaloRings(delta: delta, events: &events)
        updateTidalWaves(delta: delta, events: &events)
        if finishBossWaveIfNeeded(events: &events) { return events }
        updateCharacterAttacks(delta: delta, events: &events)
        if finishBossWaveIfNeeded(events: &events) { return events }
        updateProjectiles(delta: delta, events: &events)
        if finishAfterStaminaDepletion(events: &events) { return events }
        if finishBossWaveIfNeeded(events: &events) { return events }
        spawnPendingVolatileCores(events: &events)
        evaluateWave(events: &events)
        evaluateFinish(events: &events)
        return events
    }

    private func updatePlayer(delta: Double) {
        let difference = targetPlayerX - snapshot.playerX
        if world == .uranus, worldHazardActiveRemaining > 0 {
            playerDriftVelocity += difference * min(1, stats.movementResponse * 0.42 * delta)
            playerDriftVelocity *= pow(0.82, delta)
            snapshot.playerX += playerDriftVelocity * delta
        } else {
            playerDriftVelocity = 0
            snapshot.playerX += difference * min(1, stats.movementResponse * delta)
        }
        if world == .jupiter,
           characterAnchorRemaining == 0,
           worldHazardDelayRemaining == 0,
           worldHazardActiveRemaining > 0 {
            snapshot.playerX += worldHazardDirection * 0.34 * delta
        }
        snapshot.playerX = min(0.88, max(-0.88, snapshot.playerX))
    }

    private func updateTemporaryAbility(delta: Double) {
        guard snapshot.activeTemporaryAbility != nil else { return }
        snapshot.temporaryAbilityRemaining = max(0, snapshot.temporaryAbilityRemaining - delta)
        if snapshot.temporaryAbilityRemaining == 0 {
            snapshot.activeTemporaryAbility = nil
            snapshot.temporaryAbilityDuration = 0
        }
    }

    private func updateWorldEffect(delta: Double, events: inout [SimulationEvent]) {
        guard let definition = GameContent.world(world).hazard else { return }
        worldEffectElapsed += delta
        worldHazardDelayRemaining = max(0, worldHazardDelayRemaining - delta)
        if worldHazardDelayRemaining == 0 {
            worldHazardActiveRemaining = max(0, worldHazardActiveRemaining - delta)
        }

        if world == .moon, pendingLunarDebrisStrikes > 0 {
            lunarDebrisClock -= delta
            if lunarDebrisClock <= 0 {
                pendingLunarDebrisStrikes -= 1
                appendLunarDebris(events: &events)
            }
        }

        guard worldEffectElapsed >= nextLunarEffectTime else { return }
        nextLunarEffectTime += definition.cadence * activeAttackCadenceMultiplier
        switch world {
        case .earth, .mars:
            break
        case .moon:
            appendLunarDebris(events: &events)
            pendingLunarDebrisStrikes += 1
            lunarDebrisClock = 3
        case .jupiter:
            appendWindShear(definition, events: &events)
        case .saturn:
            appendRingSweep(definition, events: &events)
        case .uranus:
            appendCryoDrift(definition, events: &events)
        case .neptune:
            appendPressureTide(definition, events: &events)
        }
    }

    private func appendWindShear(
        _ definition: WorldHazardDefinition,
        events: inout [SimulationEvent]
    ) {
        worldHazardDirection = random.unit() < 0.5 ? -1 : 1
        worldHazardDelayRemaining = definition.telegraphDuration
        worldHazardActiveRemaining = definition.activeDuration
        let railX = worldHazardDirection < 0 ? -0.82 : 0.82
        appendBossHazard(
            kind: .windRail,
            x: railX,
            halfWidth: 0.08,
            telegraphDuration: definition.telegraphDuration,
            activeDuration: definition.activeDuration,
            damage: definition.baseDamage
        )
        events.append(.worldEffectActivated(.windShear, .init(x: worldHazardDirection * 0.56, y: 0.13)))
    }

    private func appendRingSweep(
        _ definition: WorldHazardDefinition,
        events: inout [SimulationEvent]
    ) {
        let lanes = [-0.56, 0.0, 0.56]
        let safeLane = Int(random.next() % UInt64(lanes.count))
        for index in lanes.indices where index != safeLane {
            appendBossHazard(
                kind: .ringSegment,
                x: lanes[index],
                halfWidth: 0.23,
                telegraphDuration: definition.telegraphDuration,
                activeDuration: definition.activeDuration,
                damage: definition.baseDamage
            )
        }
        events.append(.worldEffectActivated(.ringSweep, .init(x: lanes[safeLane], y: 0.13)))
    }

    private func appendCryoDrift(
        _ definition: WorldHazardDefinition,
        events: inout [SimulationEvent]
    ) {
        worldHazardDelayRemaining = definition.telegraphDuration
        worldHazardActiveRemaining = definition.activeDuration
        for railX in [-0.82, 0.82] {
            appendBossHazard(
                kind: .frozenRail,
                x: railX,
                halfWidth: 0.08,
                telegraphDuration: definition.telegraphDuration,
                activeDuration: definition.activeDuration,
                damage: definition.baseDamage
            )
        }
        events.append(.worldEffectActivated(.cryoDrift, .init(x: 0, y: 0.13)))
    }

    private func appendPressureTide(
        _ definition: WorldHazardDefinition,
        events: inout [SimulationEvent]
    ) {
        let safeCenters = [-0.40, 0.0, 0.40]
        let safeCenter = safeCenters[Int(random.next() % UInt64(safeCenters.count))]
        let safeHalfWidth = 0.24
        let leftEdge = safeCenter - safeHalfWidth
        let rightEdge = safeCenter + safeHalfWidth
        let leftHalfWidth = max(0.01, (leftEdge + 0.88) / 2)
        let rightHalfWidth = max(0.01, (0.88 - rightEdge) / 2)
        appendBossHazard(
            kind: .pressureWall,
            x: -0.88 + leftHalfWidth,
            halfWidth: leftHalfWidth,
            telegraphDuration: definition.telegraphDuration,
            activeDuration: definition.activeDuration,
            damage: definition.baseDamage
        )
        appendBossHazard(
            kind: .pressureWall,
            x: rightEdge + rightHalfWidth,
            halfWidth: rightHalfWidth,
            telegraphDuration: definition.telegraphDuration,
            activeDuration: definition.activeDuration,
            damage: definition.baseDamage
        )
        events.append(.worldEffectActivated(.pressureTide, .init(x: safeCenter, y: 0.13)))
    }

    private func appendLunarDebris(events: inout [SimulationEvent]) {
        let lanes = [-0.56, 0.0, 0.56]
        let overlapCounts = lanes.map { lane in
            snapshot.bossHazards.count { hazard in
                abs(hazard.position.x - lane) <= hazard.halfWidth + 0.16
            }
        }
        let greatestOverlap = overlapCounts.max() ?? 0
        let candidates = lanes.indices.filter { overlapCounts[$0] == greatestOverlap }
        let choice = candidates[Int(random.next() % UInt64(max(1, candidates.count)))]
        let lane = lanes[choice]
        appendBossHazard(
            kind: .lunarDebris,
            x: lane,
            halfWidth: 0.18,
            telegraphDuration: 1.25,
            activeDuration: 0.35,
            damage: 16
        )
        events.append(.worldEffectActivated(.lunarCycle, .init(x: lane, y: 0.13)))
    }

    private func updateSpawning(delta: Double) {
        if let fieldObjectPreview {
            if !fieldObjectPreviewSpawned {
                fieldObjectPreviewSpawned = true
                spawnObject(fieldObjectPreview, x: 0, y: 0.62)
            }
            return
        }
        if snapshot.isBossWave {
            spawnBossIfNeeded()
        } else if mode.isEndless {
            updateEndlessQuotaSpawning(delta: delta)
        } else {
            updateCampaignQuotaSpawning(delta: delta)
        }
    }

    private func updateCampaignQuotaSpawning(delta: Double) {
        guard let level else { return }
        let wave = CampaignBalance.wave(snapshot.wave, for: level)
        let activeQuotaEnemies = snapshot.targets.count {
            if case .enemy = $0.kind { $0.waveRole == .quota } else { false }
        }
        guard snapshot.waveDefeats + activeQuotaEnemies < snapshot.waveEnemyQuota,
              activeQuotaEnemies < CampaignBalance.maximumActiveEnemies(
                wave: snapshot.wave,
                for: level
              ) else { return }
        if pendingCampaignEnemySpawns > 0 {
            spawnClock += delta
            campaignEnemyStaggerClock += delta
            guard campaignEnemyStaggerClock >= CampaignBalance.enemyStaggerInterval else {
                return
            }
            campaignEnemyStaggerClock -= CampaignBalance.enemyStaggerInterval
            spawnOneCampaignEnemy(from: level)
            pendingCampaignEnemySpawns -= 1
            if pendingCampaignEnemySpawns == 0 {
                spawnCampaignObjectIfNeeded(from: level)
            }
            return
        }

        if activeQuotaEnemies == 0 {
            spawnClock = max(
                spawnClock,
                wave.spawnInterval - CampaignBalance.maximumEmptyFieldSpawnDelay
            )
        }
        spawnClock += delta
        guard spawnClock >= wave.spawnInterval else { return }
        spawnClock -= wave.spawnInterval
        let remainingSlots = CampaignBalance.maximumActiveEnemies(
            wave: snapshot.wave,
            for: level
        ) - activeQuotaEnemies
        let remainingQuota = snapshot.waveEnemyQuota
            - snapshot.waveDefeats
            - activeQuotaEnemies
        pendingCampaignEnemySpawns = min(
            CampaignBalance.enemyPackSize(wave: snapshot.wave, for: level),
            min(remainingSlots, remainingQuota)
        )
        campaignEnemyStaggerClock = 0
        guard pendingCampaignEnemySpawns > 0 else { return }
        spawnOneCampaignEnemy(from: level)
        pendingCampaignEnemySpawns -= 1
        if pendingCampaignEnemySpawns == 0 {
            spawnCampaignObjectIfNeeded(from: level)
        }
    }

    private func spawnOneCampaignEnemy(from level: LevelDefinition) {
        let enemy = level.enemies[
            Int(random.next() % UInt64(level.enemies.count))
        ]
        let y = 1.04 + random.unit() * 0.10
        spawnEnemy(
            enemy,
            x: randomSpawnX(near: y),
            y: y,
            role: .quota
        )
    }

    private func spawnCampaignObjectIfNeeded(from level: LevelDefinition) {
        if random.unit() < 0.12,
           let object = level.objects.randomElement(using: &random) {
            spawnObject(object, x: randomSpawnX(near: 1.10), y: 1.10)
        }
    }

    private func updateEndlessQuotaSpawning(delta: Double) {
        let activeQuotaEnemies = snapshot.targets.count {
            if case .enemy = $0.kind { $0.waveRole == .quota } else { false }
        }
        let maximumActive = EndlessRules.maximumActiveEnemies(wave: snapshot.wave)
        guard snapshot.waveDefeats + activeQuotaEnemies < snapshot.waveEnemyQuota,
              activeQuotaEnemies < maximumActive else { return }
        spawnClock += delta
        let interval = EndlessRules.spawnInterval(wave: snapshot.wave)
        guard spawnClock >= interval else { return }
        spawnClock -= interval
        let pool = endlessEnemyPool
        let remainingSlots = maximumActive - activeQuotaEnemies
        let remainingQuota = snapshot.waveEnemyQuota - snapshot.waveDefeats - activeQuotaEnemies
        let count = min(
            EndlessRules.packSize(wave: snapshot.wave),
            min(remainingSlots, remainingQuota)
        )
        for _ in 0..<count {
            let enemy = pool[Int(random.next() % UInt64(pool.count))]
            let y = 1.04 + random.unit() * 0.10
            spawnEnemy(enemy, x: randomSpawnX(near: y), y: y, role: .quota)
        }
        if random.unit() < 0.10, let object = endlessObjectPool.randomElement(using: &random) {
            spawnObject(object, x: randomSpawnX(near: 1.12), y: 1.12)
        }
    }

    private func spawnBossIfNeeded() {
        guard !bossSpawned else { return }
        if let level {
            let wave = CampaignBalance.wave(snapshot.wave, for: level)
            guard let boss = wave.boss, let tier = wave.bossTier else { return }
            bossSpawned = true
            spawnEnemy(
                boss,
                x: 0,
                y: CampaignBalance.bossArenaY,
                tier: tier,
                role: .boss
            )
        } else {
            bossSpawned = true
            spawnEnemy(
                GameContent.world(world).boss,
                x: 0,
                y: CampaignBalance.bossArenaY,
                tier: .megaBoss,
                role: .boss
            )
        }
    }

    private func updatePowerUpSpawning(delta: Double) {
        guard !mode.isEndless else { return }
        if snapshot.isBossWave {
            bossPowerUpClock -= delta
            guard bossPowerUpClock <= 0,
                  !snapshot.targets.contains(where: {
                    if case .powerUp = $0.kind { true } else { false }
                  }) else { return }
            bossPowerUpClock = 16
            spawnRandomPowerUp()
            return
        }
        guard !powerUpSpawned, snapshot.waveDefeats >= nextPowerUpDefeat else { return }
        powerUpSpawned = true
        spawnRandomPowerUp()
    }

    private func spawnRandomPowerUp() {
        let power = TemporaryAbilityRules.spawnedAbility(
            worldPowers: GameContent.world(world).temporaryPowers,
            universalRoll: random.unit(),
            worldRoll: random.unit()
        )
        spawnPowerUp(power, x: randomSpawnX(near: 1.08), y: 1.08)
    }

    private func updateBossSupport(delta: Double) {
        guard snapshot.isBossWave,
              snapshot.targets.contains(where: { $0.waveRole == .boss }) else {
            return
        }
        if mode.isEndless {
            updateEndlessBossSupport(delta: delta)
            return
        }

        bossSupportSpawnClock -= delta
        if reinforcementQuietClock > 0 {
            reinforcementQuietClock = max(0, reinforcementQuietClock - delta)
        }

        let activeCount = activeBossReinforcementCount
        let baselineCapacity = bossSupportCapacity
        if reinforcementQuietClock == 0,
           let phase = pendingReinforcementPhases.first {
            let pulse = reinforcements(for: phase)
            let phaseCapacity = max(baselineCapacity, pulse.count)
            let availableSlots = max(
                0,
                phaseCapacity - activeCount
            )
            spawnBossReinforcements(
                Array(pulse.prefix(availableSlots))
            )
            pendingReinforcementPhases.removeFirst()
            reinforcementQuietClock = 1.25
        }

        guard bossSupportSpawnClock <= 0 else { return }
        bossSupportSpawnClock += bossSupportInterval
        let remainingSlots = max(
            0,
            baselineCapacity - activeBossReinforcementCount
        )
        guard remainingSlots > 0 else { return }
        let packCount = min(
            3,
            CampaignBalance.reinforcementPulseSize(
                levelNumber: level?.number ?? 1
            )
        )
        spawnBossReinforcements(
            Array(
                reinforcements(for: bossPhase)
                    .prefix(min(remainingSlots, packCount))
            )
        )
    }

    private func updateEndlessBossSupport(delta: Double) {
        let activeCount = activeBossReinforcementCount
        if activeCount > 0 {
            endlessBossReinforcementsWereActive = true
            return
        }

        if endlessBossReinforcementsWereActive {
            endlessBossReinforcementsWereActive = false
            reinforcementQuietClock = EndlessRules.bossDirectDamageWindow(
                wave: snapshot.wave
            )
            return
        }

        if reinforcementQuietClock > 0 {
            reinforcementQuietClock = max(0, reinforcementQuietClock - delta)
            return
        }

        if !endlessInitialBossSupportSpawned {
            bossSupportSpawnClock -= delta
            guard bossSupportSpawnClock <= 0 else { return }
            endlessInitialBossSupportSpawned = true
            spawnEndlessBossReinforcementWave(phase: 1)
            return
        }

        guard let phase = pendingReinforcementPhases.first else { return }
        pendingReinforcementPhases.removeFirst()
        spawnEndlessBossReinforcementWave(phase: phase)
    }

    private func spawnEndlessBossReinforcementWave(phase: Int) {
        let enemies = reinforcements(for: phase)
        let count = min(
            EndlessRules.bossReinforcementWaveSize(wave: snapshot.wave),
            enemies.count
        )
        guard count > 0 else { return }
        spawnBossReinforcements(Array(enemies.prefix(count)))
        endlessBossReinforcementsWereActive = true
    }

    private var activeBossReinforcementCount: Int {
        snapshot.targets.count {
            if case .enemy = $0.kind {
                $0.waveRole == .reinforcement
            } else {
                false
            }
        }
    }

    private var bossSupportCapacity: Int {
        if let level {
            CampaignBalance.bossSupportCapacity(for: level)
        } else {
            2
        }
    }

    private var bossSupportInterval: TimeInterval {
        if let level {
            CampaignBalance.bossSupportSpawnInterval(
                level: level,
                wave: snapshot.wave
            )
        } else {
            3
        }
    }

    private func spawnBossReinforcements(_ enemies: [EnemyKind]) {
        for kind in enemies {
            let y = 0.88 + random.unit() * 0.12
            spawnEnemy(
                kind,
                x: randomSpawnX(near: y),
                y: y,
                role: .reinforcement
            )
        }
    }

    private func updateBossAttackSchedule(delta: Double, events: inout [SimulationEvent]) {
        guard timeBreakRemaining == 0 else { return }
        guard snapshot.isBossWave,
              let boss = snapshot.targets.first(where: { $0.waveRole == .boss }),
              boss.bossTier == .megaBoss else { return }

        if pendingMeteorMarkers > 0 {
            meteorMarkerClock -= delta
            if meteorMarkerClock <= 0 {
                pendingMeteorMarkers -= 1
                meteorMarkerClock += 0.45
                appendBossHazard(
                    kind: .meteorStrike,
                    x: snapshot.playerX,
                    halfWidth: 0.15,
                    telegraphDuration: 1.4,
                    activeDuration: 0.30,
                    damage: 18
                )
            }
        }

        guard boss.freezeRemaining <= 0, boss.stunRemaining <= 0 else { return }
        bossSignatureClock -= delta
        guard bossSignatureClock <= 0 else { return }

        switch world {
        case .earth:
            appendBossHazard(
                kind: .orbitalLaser,
                x: snapshot.playerX,
                halfWidth: 0.14,
                telegraphDuration: 1.75,
                activeDuration: 1.25,
                damage: 24
            )
            events.append(.bossAttackTelegraphed(.orbitalLaser))
            scheduleBossSignature(after: 10)
        case .moon:
            let lanes = [-0.56, 0.0, 0.56]
            let safeIndex = Int(random.next() % UInt64(lanes.count))
            for index in lanes.indices where index != safeIndex {
                appendBossHazard(
                    kind: .eclipseLane,
                    x: lanes[index],
                    halfWidth: 0.23,
                    telegraphDuration: 1.6,
                    activeDuration: 1.2,
                    damage: 22
                )
            }
            events.append(.bossAttackTelegraphed(.eclipseLane))
            scheduleBossSignature(after: 11)
        case .mars:
            appendBossHazard(
                kind: .meteorStrike,
                x: snapshot.playerX,
                halfWidth: 0.15,
                telegraphDuration: 1.4,
                activeDuration: 0.30,
                damage: 18
            )
            pendingMeteorMarkers = 2
            meteorMarkerClock = 0.45
            events.append(.bossAttackTelegraphed(.meteorStrike))
            scheduleBossSignature(after: 10)
        case .jupiter:
            if let hazard = GameContent.world(world).hazard {
                appendWindShear(hazard, events: &events)
            }
            events.append(.bossAttackTelegraphed(.windRail))
            scheduleBossSignature(after: 9)
        case .saturn:
            if let hazard = GameContent.world(world).hazard {
                appendRingSweep(hazard, events: &events)
            }
            events.append(.bossAttackTelegraphed(.ringSegment))
            scheduleBossSignature(after: 10)
        case .uranus:
            if let hazard = GameContent.world(world).hazard {
                appendCryoDrift(hazard, events: &events)
            }
            events.append(.bossAttackTelegraphed(.frozenRail))
            scheduleBossSignature(after: 10)
        case .neptune:
            if let hazard = GameContent.world(world).hazard {
                appendPressureTide(hazard, events: &events)
            }
            events.append(.bossAttackTelegraphed(.pressureWall))
            scheduleBossSignature(after: 9)
        }
    }

    private func scheduleBossSignature(after baseInterval: TimeInterval) {
        bossSignatureClock = baseInterval * activeAttackCadenceMultiplier
    }

    private func appendBossHazard(
        kind: BossAttackKind,
        x: Double,
        halfWidth: Double,
        telegraphDuration: Double,
        activeDuration: Double,
        damage: Double
    ) {
        snapshot.bossHazards.append(BossHazardState(
            id: identifier(),
            kind: kind,
            position: .init(x: min(0.82, max(-0.82, x)), y: 0.13),
            halfWidth: halfWidth,
            telegraphDuration: telegraphDuration,
            telegraphRemaining: telegraphDuration,
            activeDuration: activeDuration,
            activeRemaining: activeDuration,
            damage: damage
        ))
    }

    private func updateBossHazards(delta: Double, events: inout [SimulationEvent]) {
        guard timeBreakRemaining == 0 else { return }
        guard !snapshot.bossHazards.isEmpty else { return }
        for index in snapshot.bossHazards.indices {
            var hazard = snapshot.bossHazards[index]
            if hazard.telegraphRemaining > 0 {
                let previous = hazard.telegraphRemaining
                hazard.telegraphRemaining = max(0, previous - delta)
                if previous > 0, hazard.telegraphRemaining == 0 {
                    let worldRule: WorldRule? = switch hazard.kind {
                    case .lunarDebris: .lunarCycle
                    case .windRail: .windShear
                    case .ringSegment: .ringSweep
                    case .frozenRail: .cryoDrift
                    case .pressureWall: .pressureTide
                    case .orbitalLaser, .eclipseLane, .meteorStrike: nil
                    }
                    if let worldRule {
                        events.append(.worldEffectImpact(worldRule, hazard.position))
                    } else {
                        events.append(.bossAttackActivated(hazard.kind, hazard.position))
                    }
                }
            } else {
                hazard.activeRemaining = max(0, hazard.activeRemaining - delta)
            }
            if hazard.isActive,
               !hazard.hasDamagedPlayer,
               abs(snapshot.playerX - hazard.position.x) <= hazard.halfWidth {
                hazard.hasDamagedPlayer = true
                applyDamage(hazard.damage * activeDamageMultiplier, events: &events)
            }
            snapshot.bossHazards[index] = hazard
        }
        snapshot.bossHazards.removeAll(where: { $0.isFinished })
    }

    private func updateKicking(delta: Double, events: inout [SimulationEvent]) {
        kickClock += delta
        let quickRank = abilities[.quickRelease, default: 0]
        let baseCooldown = kickInterval(atAbilityRank: quickRank)
        let cooldown = snapshot.activeTemporaryAbility == .rapidFire
            ? max(0.09, baseCooldown * 0.20)
            : baseCooldown
        guard kickClock >= cooldown else { return }
        kickClock -= cooldown
        kickCount += 1

        let powerDriveRank = abilities[.powerDrive, default: 0]
        let powerDriveMultiplier = mode.isEndless
            ? EndlessAbilityRules.powerDriveMultiplier(rank: powerDriveRank)
            : pow(1.35, Double(powerDriveRank))
        var baseDamage = stats.ballDamage * powerDriveMultiplier
        baseDamage *= quickReleaseDamageMultiplier(atAbilityRank: quickRank)
        let meteorRank = abilities[.meteorStrike, default: 0]
        let meteorInterval = max(2, 7 - min(meteorRank, 5))
        let isMeteor = meteorRank > 0 && kickCount.isMultiple(of: meteorInterval)
        let meteorDamageMultiplier = mode.isEndless
            ? EndlessAbilityRules.meteorDamageMultiplier(rank: meteorRank)
            : 1 + Double(meteorRank) * 0.55
        if isMeteor,
           spawnTargetedMeteor(
               damage: baseDamage * meteorDamageMultiplier
           ) {
            events.append(.meteorKick)
        }

        let criticalPower = max(0, stats.criticalChance)
        let guaranteedCriticalTiers = Int(criticalPower.rounded(.down))
        let fractionalCriticalTier = random.unit() < criticalPower.truncatingRemainder(dividingBy: 1) ? 1 : 0
        let criticalTiers = guaranteedCriticalTiers + fractionalCriticalTier
        let critical = criticalTiers > 0
        let damage = baseDamage * Double(1 + criticalTiers)
        let launches = volleyLaunches(rank: abilities[.oneTwo, default: 0])
        let endlessEffects = specialBallEffects(count: launches.count)
        let basePierce = abilities[.throughBall, default: 0] + stats.extraPierce
        for (index, launch) in launches.enumerated() {
            let temporaryAbility = mode.isEndless
                ? nil
                : snapshot.activeTemporaryAbility
            let effects = endlessEffects[index]
            let pierce = effects.contains(.solarPierce)
                || temporaryAbility == .solarPierce
                ? Int.max
                : basePierce
            spawnProjectile(
                x: snapshot.playerX + launch.xOffset,
                velocityX: launch.velocityX,
                damage: damage * launch.damageMultiplier,
                pierce: pierce,
                hostile: false,
                critical: critical,
                temporaryAbility: temporaryAbility,
                endlessEffects: effects
            )
        }
        events.append(.kick)
    }

    private func volleyLaunches(
        rank: Int
    ) -> [(xOffset: Double, velocityX: Double, damageMultiplier: Double)] {
        switch rank {
        case ...0:
            return [(0, 0, 1)]
        case 1:
            return [
                (0, 0, 1),
                (
                    0,
                    kickCount.isMultiple(of: 2) ? -0.34 : 0.34,
                    0.70
                ),
            ]
        case 2:
            return [(0, 0, 1), (-0.025, -0.46, 0.74), (0.025, 0.46, 0.74)]
        case 3:
            return [
                (0, 0, 1),
                (-0.025, -0.38, 0.76),
                (0.025, 0.38, 0.76),
                (
                    0,
                    kickCount.isMultiple(of: 2) ? -0.62 : 0.62,
                    0.68
                ),
            ]
        default:
            guard mode.isEndless else {
                return volleyLaunches(rank: 3)
            }
            let count = rank + 1
            let maximumSpeed = min(0.82, 0.42 + Double(rank) * 0.055)
            let mastery = EndlessAbilityRules
                .wideVolleySecondaryMastery(rank: rank)
            return (0..<count).map { index in
                let fraction = Double(index) / Double(max(1, count - 1))
                let velocity = -maximumSpeed + maximumSpeed * 2 * fraction
                let primaryIndex = count / 2
                return (
                    xOffset: velocity == 0 ? 0 : (velocity < 0 ? -0.025 : 0.025),
                    velocityX: velocity,
                    damageMultiplier: index == primaryIndex ? 1 : 0.76 * mastery
                )
            }
        }
    }

    private func specialBallEffects(
        count: Int
    ) -> [Set<TemporaryBallAbility>] {
        guard mode.isEndless else {
            return Array(repeating: [], count: count)
        }
        let owned = EndlessSpecialBallRules.abilities.filter {
            specialBallRanks[$0, default: 0] > 0
        }
        guard !owned.isEmpty else {
            return Array(repeating: [], count: count)
        }

        return (0..<count).map { _ in
            let rolls = Dictionary(
                uniqueKeysWithValues: owned.map {
                    ($0, random.unit())
                }
            )
            return EndlessSpecialBallRules.triggeredEffects(
                ranks: specialBallRanks,
                rolls: rolls
            )
        }
    }

    @discardableResult
    private func spawnTargetedMeteor(damage: Double) -> Bool {
        guard let target = snapshot.targets
            .filter({
                if case .enemy = $0.kind { true } else { false }
            })
            .min(by: { $0.position.y < $1.position.y }) else {
            return false
        }
        let start = Vector2(
            x: min(0.90, max(-0.90, target.position.x - 0.30)),
            y: 1.58
        )
        snapshot.characterAttacks.append(CharacterAttackState(
            id: identifier(),
            kind: .meteor,
            position: start,
            startPosition: start,
            destination: target.position,
            targetID: target.id,
            damage: damage,
            awardsAbilityCharge: true,
            delayRemaining: 0,
            elapsed: 0,
            duration: 0.78,
            width: 0.70
        ))
        return true
    }

    private func updateGaleInterceptors(
        delta: Double,
        events: inout [SimulationEvent]
    ) {
        let reservedTargetIDs = Set(snapshot.galeInterceptors.map(\.targetID))
        if snapshot.galeOrbitCount > 0 {
            let endangeredTargets = snapshot.targets
                .filter {
                    guard case .enemy = $0.kind else { return false }
                    return $0.position.y <= 0.28
                        && !reservedTargetIDs.contains($0.id)
                }
                .sorted {
                    if abs($0.position.y - $1.position.y) > 0.000_001 {
                        return $0.position.y < $1.position.y
                    }
                    return $0.id < $1.id
                }
                .prefix(snapshot.galeOrbitCount)

            for target in endangeredTargets {
                snapshot.galeOrbitCount -= 1
                snapshot.galeInterceptors.append(GaleInterceptorState(
                    id: identifier(),
                    targetID: target.id,
                    startPosition: .init(x: snapshot.playerX, y: 0.16),
                    position: .init(x: snapshot.playerX, y: 0.16),
                    elapsed: 0,
                    duration: 0.22,
                    damage: stats.ballDamage * 4.5
                ))
                if let index = snapshot.targets.firstIndex(where: { $0.id == target.id }) {
                    if !snapshot.targets[index].isShielded {
                        snapshot.targets[index].stunRemaining = max(
                            snapshot.targets[index].stunRemaining,
                            0.28
                        )
                    }
                }
            }
        }

        guard !snapshot.galeInterceptors.isEmpty else { return }
        var completedIDs = Set<Int>()
        hitTargetIDs.removeAll(keepingCapacity: true)
        for interceptorIndex in snapshot.galeInterceptors.indices {
            var interceptor = snapshot.galeInterceptors[interceptorIndex]
            guard let targetIndex = snapshot.targets.firstIndex(where: {
                $0.id == interceptor.targetID
            }) else {
                snapshot.galeOrbitCount = min(3, snapshot.galeOrbitCount + 1)
                completedIDs.insert(interceptor.id)
                continue
            }

            interceptor.elapsed = min(
                interceptor.duration,
                interceptor.elapsed + delta
            )
            let target = snapshot.targets[targetIndex]
            let progress = interceptor.progress
            let eased = progress * progress * (3 - 2 * progress)
            interceptor.position = .init(
                x: interceptor.startPosition.x
                    + (target.position.x - interceptor.startPosition.x) * eased,
                y: interceptor.startPosition.y
                    + (target.position.y - interceptor.startPosition.y) * eased
            )
            if !snapshot.targets[targetIndex].isShielded {
                snapshot.targets[targetIndex].stunRemaining = max(
                    snapshot.targets[targetIndex].stunRemaining,
                    max(0, interceptor.duration - interceptor.elapsed)
                )
            }

            if progress >= 1 {
                let resolution = applyTargetDamage(
                    interceptor.damage,
                    at: targetIndex,
                    events: &events
                )
                if !resolution.blocksEffects,
                   snapshot.targets[targetIndex].bossTier == .standard {
                    snapshot.targets[targetIndex].position.y = max(
                        0.42,
                        snapshot.targets[targetIndex].position.y
                    )
                } else if !resolution.blocksEffects {
                    snapshot.targets[targetIndex].stunRemaining = max(
                        snapshot.targets[targetIndex].stunRemaining,
                        0.45
                    )
                }
                events.append(impactEvent(
                    for: snapshot.targets[targetIndex],
                    damage: resolution.appliedDamage,
                    flavor: .standard,
                    critical: true,
                    delivery: .direct,
                    impulse: .init(x: 0, y: 1)
                ))
                events.append(.characterAbilityEffect(
                    .galeInterception(snapshot.targets[targetIndex].position)
                ))
                registerDefeatIfNeeded(
                    at: targetIndex,
                    awardsAbilityCharge: false,
                    characterAbilityCredit: true,
                    events: &events
                )
                completedIDs.insert(interceptor.id)
            }
            snapshot.galeInterceptors[interceptorIndex] = interceptor
        }
        snapshot.galeInterceptors.removeAll { completedIDs.contains($0.id) }
        if !hitTargetIDs.isEmpty {
            snapshot.targets.removeAll { hitTargetIDs.contains($0.id) }
        }
    }

    private func updateGaleBounces(
        delta: Double,
        events: inout [SimulationEvent]
    ) {
        guard !snapshot.galeBounces.isEmpty else { return }
        var completedIDs = Set<Int>()
        hitTargetIDs.removeAll(keepingCapacity: true)

        for bounceIndex in snapshot.galeBounces.indices {
            var bounce = snapshot.galeBounces[bounceIndex]
            bounce.previousPosition = bounce.position
            bounce.elapsed = min(bounce.duration, bounce.elapsed + delta)
            bounce.position = galeBouncePosition(bounce, progress: bounce.progress)
            let landingCount = min(4, Int(floor(bounce.progress * 4 + 0.000_001)))
            while bounce.completedLandings < landingCount {
                bounce.completedLandings += 1
                let landingProgress = Double(bounce.completedLandings) / 4
                let landingPosition = galeBouncePosition(
                    bounce,
                    progress: landingProgress
                )
                applyGaleLanding(
                    activationID: bounce.activationID,
                    position: landingPosition,
                    events: &events
                )
                events.append(.characterAbilityEffect(.galeLanding(
                    landingPosition,
                    variant: (bounce.lane + bounce.completedLandings) % 3
                )))
            }
            if bounce.progress >= 1 {
                completedIDs.insert(bounce.id)
            }
            snapshot.galeBounces[bounceIndex] = bounce
        }

        snapshot.galeBounces.removeAll { completedIDs.contains($0.id) }
        if !hitTargetIDs.isEmpty {
            snapshot.targets.removeAll { hitTargetIDs.contains($0.id) }
        }
        let activeActivationIDs = Set(snapshot.galeBounces.map(\.activationID))
        galeLandingHitCounts = galeLandingHitCounts.filter {
            activeActivationIDs.contains($0.key)
        }
    }

    private func galeBouncePosition(
        _ bounce: GaleBounceState,
        progress: Double
    ) -> Vector2 {
        let clamped = min(1, max(0, progress))
        let centeredLaunchX = Double(bounce.lane - 2) * 0.075
        let x: Double
        if clamped <= 0.10 {
            let phase = clamped / 0.10
            let eased = phase * phase * (3 - 2 * phase)
            x = bounce.startPosition.x
                + (centeredLaunchX - bounce.startPosition.x) * eased
        } else if clamped <= 0.25 {
            let phase = (clamped - 0.10) / 0.15
            let eased = phase * phase * (3 - 2 * phase)
            x = centeredLaunchX
                + (bounce.destinationX - centeredLaunchX) * eased
        } else {
            x = bounce.destinationX
        }
        return .init(
            x: min(0.84, max(-0.84, x)),
            y: bounce.startPosition.y + 0.94 * clamped
        )
    }

    private func applyGaleLanding(
        activationID: Int,
        position: Vector2,
        events: inout [SimulationEvent]
    ) {
        var hitCounts = galeLandingHitCounts[activationID, default: [:]]
        for index in snapshot.targets.indices {
            let target = snapshot.targets[index]
            guard !isPowerUp(target),
                  target.hitPoints > 0,
                  !hitTargetIDs.contains(target.id),
                  hitCounts[target.id, default: 0] < 4,
                  hypot(
                      target.position.x - position.x,
                      target.position.y - position.y
                  ) <= 0.20 else { continue }
            let damage = stats.ballDamage * 1.15
            hitCounts[target.id, default: 0] += 1
            let resolution = applyTargetDamage(
                damage,
                at: index,
                events: &events
            )
            if !resolution.blocksEffects {
                snapshot.targets[index].stunRemaining = max(
                    snapshot.targets[index].stunRemaining,
                    0.18
                )
            }
            events.append(impactEvent(
                for: snapshot.targets[index],
                damage: resolution.appliedDamage,
                flavor: .explosive,
                critical: true,
                delivery: .area,
                impulse: .init(
                    x: target.position.x - position.x,
                    y: 0.45
                )
            ))
            registerDefeatIfNeeded(
                at: index,
                awardsAbilityCharge: false,
                characterAbilityCredit: true,
                events: &events
            )
        }
        galeLandingHitCounts[activationID] = hitCounts
    }

    private func updateHaloRings(
        delta: Double,
        events: inout [SimulationEvent]
    ) {
        guard !snapshot.haloRings.isEmpty else { return }
        var completedIDs = Set<Int>()
        hitTargetIDs.removeAll(keepingCapacity: true)
        removedProjectileIDs.removeAll(keepingCapacity: true)

        for ringIndex in snapshot.haloRings.indices {
            var ring = snapshot.haloRings[ringIndex]
            ring.targetContactCooldowns = ring.targetContactCooldowns.mapValues {
                max(0, $0 - delta)
            }
            ring.previousCenter = ring.center
            ring.elapsed = min(ring.duration, ring.elapsed + delta)
            let progress = ring.progress
            let eased = progress * progress * (3 - 2 * progress)
            let centeringProgress = min(1, progress / 0.14)
            let centeringEase = centeringProgress
                * centeringProgress
                * (3 - 2 * centeringProgress)
            ring.center = .init(
                x: ring.startX * (1 - centeringEase),
                y: 0.18 + 0.94 * eased
            )

            for targetIndex in snapshot.targets.indices {
                let target = snapshot.targets[targetIndex]
                guard !isPowerUp(target),
                      target.hitPoints > 0,
                      !hitTargetIDs.contains(target.id),
                      ring.targetHitCounts[target.id, default: 0] < 2,
                      ring.targetContactCooldowns[target.id, default: 0] == 0,
                      haloRingTouches(
                          position: target.position,
                          previousCenter: ring.previousCenter,
                          center: ring.center,
                          radius: ring.radius
                      ) else { continue }
                let resolution = applyTargetDamage(
                    ring.damage,
                    at: targetIndex,
                    events: &events
                )
                ring.targetHitCounts[target.id, default: 0] += 1
                ring.targetContactCooldowns[target.id] = 0.45
                events.append(impactEvent(
                    for: snapshot.targets[targetIndex],
                    damage: resolution.appliedDamage,
                    flavor: .standard,
                    critical: true,
                    delivery: .area,
                    impulse: .init(
                        x: target.position.x - ring.center.x,
                        y: target.position.y - ring.center.y
                    )
                ))
                events.append(.characterAbilityEffect(.haloContact(target.position)))
                registerDefeatIfNeeded(
                    at: targetIndex,
                    awardsAbilityCharge: false,
                    characterAbilityCredit: true,
                    events: &events
                )
            }

            for projectile in snapshot.projectiles where projectile.hostile {
                if haloRingTouches(
                    position: projectile.position,
                    previousCenter: ring.previousCenter,
                    center: ring.center,
                    radius: ring.radius
                ) {
                    removedProjectileIDs.insert(projectile.id)
                }
            }

            if ring.progress >= 1 {
                completedIDs.insert(ring.id)
            }
            snapshot.haloRings[ringIndex] = ring
        }

        snapshot.haloRings.removeAll { completedIDs.contains($0.id) }
        if !hitTargetIDs.isEmpty {
            snapshot.targets.removeAll { hitTargetIDs.contains($0.id) }
        }
        if !removedProjectileIDs.isEmpty {
            snapshot.projectiles.removeAll {
                removedProjectileIDs.contains($0.id)
            }
        }
    }

    private func haloRingTouches(
        position: Vector2,
        previousCenter: Vector2,
        center: Vector2,
        radius: Double
    ) -> Bool {
        let middle = Vector2(
            x: (previousCenter.x + center.x) * 0.5,
            y: (previousCenter.y + center.y) * 0.5
        )
        let verticalRadius = radius * 0.58
        return [previousCenter, middle, center].contains {
            let normalizedDistance = hypot(
                (position.x - $0.x) / radius,
                (position.y - $0.y) / verticalRadius
            )
            return abs(normalizedDistance - 1) <= 0.23
        }
    }

    private func updateMagneticTraps(
        delta: Double,
        events: inout [SimulationEvent]
    ) {
        guard !snapshot.magneticTraps.isEmpty else { return }
        var completedIDs = Set<Int>()
        hitTargetIDs.removeAll(keepingCapacity: true)

        for trapIndex in snapshot.magneticTraps.indices {
            var trap = snapshot.magneticTraps[trapIndex]
            if trap.delayRemaining > 0 {
                trap.delayRemaining = max(0, trap.delayRemaining - delta)
                snapshot.magneticTraps[trapIndex] = trap
                continue
            }

            if !trap.hasLanded {
                trap.flightElapsed = min(
                    trap.flightDuration,
                    trap.flightElapsed + delta
                )
                let progress = trap.flightProgress
                let eased = progress * progress * (3 - 2 * progress)
                trap.position = .init(
                    x: trap.startPosition.x
                        + (trap.landingPosition.x - trap.startPosition.x) * eased,
                    y: trap.startPosition.y
                        + (trap.landingPosition.y - trap.startPosition.y) * eased
                )
                if progress >= 1 {
                    trap.hasLanded = true
                    trap.position = trap.landingPosition
                }
            }

            if trap.hasLanded {
                trap.armedRemaining = max(0, trap.armedRemaining - delta)
                if let targetID = trap.targetID,
                   !snapshot.targets.contains(where: {
                       $0.id == targetID
                           && $0.position.y >= trap.position.y
                   }) {
                    trap.targetID = nil
                    trap.controlBlockedByShield = false
                }
                if trap.targetID == nil {
                    let claimedTargetIDs = Set(
                        snapshot.magneticTraps.compactMap(\.targetID)
                    )
                    trap.targetID = snapshot.targets
                        .filter {
                            guard case .enemy = $0.kind,
                                  !claimedTargetIDs.contains($0.id),
                                  $0.position.y >= trap.position.y else {
                                return false
                            }
                            return hypot(
                                $0.position.x - trap.position.x,
                                $0.position.y - trap.position.y
                            ) <= 0.45
                        }
                        .min {
                            hypot(
                                $0.position.x - trap.position.x,
                                $0.position.y - trap.position.y
                            ) < hypot(
                                $1.position.x - trap.position.x,
                                $1.position.y - trap.position.y
                            )
                        }?
                        .id
                }

                if let targetID = trap.targetID,
                   let targetIndex = snapshot.targets.firstIndex(where: {
                       $0.id == targetID
                   }) {
                    if snapshot.targets[targetIndex].isShielded {
                        trap.controlBlockedByShield = true
                    }
                    let controlBlocked = trap.controlBlockedByShield
                    if trap.captureRemaining == 0, trap.ticksRemaining == 8 {
                        let target = snapshot.targets[targetIndex]
                        if controlBlocked {
                            trap.position = target.position
                            trap.captureRemaining = 3.2
                            trap.tickClock = 0.08
                            events.append(.characterAbilityEffect(
                                .magneticTrapSnap(target.position)
                            ))
                        } else {
                            let offset = Vector2(
                                x: trap.position.x - target.position.x,
                                y: trap.position.y - target.position.y
                            )
                            let distance = hypot(offset.x, offset.y)
                            let pullRate = target.bossTier == .standard ? 2.4 : 0.72
                            let minimumPullSpeed = target.bossTier == .standard ? 0.42 : 0.16
                            let pullDistance = min(
                                distance,
                                max(
                                    distance * (1 - exp(-pullRate * delta)),
                                    minimumPullSpeed * delta
                                )
                            )
                            if distance > 0 {
                                snapshot.targets[targetIndex].position.x +=
                                    offset.x / distance * pullDistance
                                snapshot.targets[targetIndex].position.y +=
                                    offset.y / distance * pullDistance
                            }
                            let pulledTarget = snapshot.targets[targetIndex]
                            let snapDistance = target.bossTier == .standard ? 0.10 : 0.14
                            if hypot(
                                trap.position.x - pulledTarget.position.x,
                                trap.position.y - pulledTarget.position.y
                            ) <= snapDistance {
                                trap.captureRemaining = 3.2
                                trap.tickClock = 0.08
                                snapshot.targets[targetIndex].position = trap.position
                                events.append(.characterAbilityEffect(
                                    .magneticTrapSnap(trap.position)
                                ))
                            }
                        }
                    }
                    if trap.captureRemaining > 0 {
                        trap.captureRemaining = max(0, trap.captureRemaining - delta)
                        if controlBlocked {
                            trap.position = snapshot.targets[targetIndex].position
                        } else {
                            snapshot.targets[targetIndex].position = trap.position
                        }
                        trap.tickClock -= delta
                        while trap.tickClock <= 0, trap.ticksRemaining > 0 {
                            trap.tickClock += 0.40
                            trap.ticksRemaining -= 1
                            let resolution = applyTargetDamage(
                                trap.tickDamage,
                                at: targetIndex,
                                events: &events
                            )
                            events.append(impactEvent(
                                for: snapshot.targets[targetIndex],
                                damage: resolution.appliedDamage,
                                flavor: .standard,
                                critical: false,
                                delivery: .damageOverTime,
                                impulse: .init(x: 0, y: 0)
                            ))
                            registerDefeatIfNeeded(
                                at: targetIndex,
                                awardsAbilityCharge: false,
                                characterAbilityCredit: true,
                                events: &events
                            )
                            if hitTargetIDs.contains(targetID) { break }
                        }
                    }
                    if (trap.captureRemaining == 0 && trap.ticksRemaining < 8)
                        || (trap.armedRemaining == 0 && trap.ticksRemaining == 8)
                        || hitTargetIDs.contains(targetID) {
                        completedIDs.insert(trap.id)
                    }
                } else if trap.armedRemaining == 0 {
                    completedIDs.insert(trap.id)
                }
            }
            snapshot.magneticTraps[trapIndex] = trap
        }

        snapshot.magneticTraps.removeAll { completedIDs.contains($0.id) }
        if !hitTargetIDs.isEmpty {
            snapshot.targets.removeAll { hitTargetIDs.contains($0.id) }
        }
    }

    private func updateTidalWaves(
        delta: Double,
        events: inout [SimulationEvent]
    ) {
        guard !snapshot.tidalWaves.isEmpty else { return }
        var completedIDs = Set<Int>()
        hitTargetIDs.removeAll(keepingCapacity: true)
        removedProjectileIDs.removeAll(keepingCapacity: true)

        for waveIndex in snapshot.tidalWaves.indices {
            var wave = snapshot.tidalWaves[waveIndex]
            if wave.delayRemaining > 0 {
                wave.delayRemaining = max(0, wave.delayRemaining - delta)
                snapshot.tidalWaves[waveIndex] = wave
                continue
            }

            if !wave.hasLaunched {
                wave.hasLaunched = true
                events.append(.characterAbilityEffect(.tidalLaunch(
                    wave.lane,
                    round: wave.round,
                    position: .init(x: wave.centerX, y: wave.positionY)
                )))
            }
            wave.previousPositionY = wave.positionY
            wave.elapsed = min(wave.duration, wave.elapsed + delta)
            let eased = 1 - pow(1 - wave.progress, 1.35)
            wave.positionY = 0.18 + 0.94 * eased
            let lowerY = min(wave.previousPositionY, wave.positionY) - 0.07
            let upperY = max(wave.previousPositionY, wave.positionY) + 0.07

            for targetIndex in snapshot.targets.indices {
                let target = snapshot.targets[targetIndex]
                guard case .enemy = target.kind,
                      target.hitPoints > 0,
                      !hitTargetIDs.contains(target.id),
                      !wave.contactedTargetIDs.contains(target.id),
                      target.position.y >= lowerY,
                      target.position.y <= upperY,
                      abs(target.position.x - wave.centerX) <= wave.halfWidth else {
                    continue
                }
                wave.contactedTargetIDs.insert(target.id)
                let resolution = applyTargetDamage(
                    wave.damage,
                    at: targetIndex,
                    events: &events
                )
                if !resolution.blocksEffects,
                   target.bossTier == .standard {
                    snapshot.targets[targetIndex].position.y = min(
                        1.12,
                        snapshot.targets[targetIndex].position.y + wave.push
                    )
                    snapshot.targets[targetIndex].stunRemaining = max(
                        snapshot.targets[targetIndex].stunRemaining,
                        0.24
                    )
                } else if !resolution.blocksEffects {
                    snapshot.targets[targetIndex].position.y = min(
                        1.12,
                        snapshot.targets[targetIndex].position.y + 0.035
                    )
                    snapshot.targets[targetIndex].tidalSlowRemaining = max(
                        snapshot.targets[targetIndex].tidalSlowRemaining,
                        0.70
                    )
                }
                events.append(impactEvent(
                    for: snapshot.targets[targetIndex],
                    damage: resolution.appliedDamage,
                    flavor: .ice,
                    critical: true,
                    delivery: .area,
                    impulse: .init(x: 0, y: 1)
                ))
                events.append(.characterAbilityEffect(
                    .tidalHit(snapshot.targets[targetIndex].position)
                ))
                registerDefeatIfNeeded(
                    at: targetIndex,
                    awardsAbilityCharge: false,
                    characterAbilityCredit: true,
                    events: &events
                )
            }

            for projectile in snapshot.projectiles where projectile.hostile {
                if projectile.position.y >= lowerY,
                   projectile.position.y <= upperY,
                   abs(projectile.position.x - wave.centerX) <= wave.halfWidth {
                    removedProjectileIDs.insert(projectile.id)
                }
            }
            snapshot.bossHazards.removeAll {
                abs($0.position.x - wave.centerX)
                    <= wave.halfWidth + $0.halfWidth
            }

            if wave.progress >= 1 {
                completedIDs.insert(wave.id)
            }
            snapshot.tidalWaves[waveIndex] = wave
        }

        snapshot.tidalWaves.removeAll { completedIDs.contains($0.id) }
        if !hitTargetIDs.isEmpty {
            snapshot.targets.removeAll { hitTargetIDs.contains($0.id) }
        }
        if !removedProjectileIDs.isEmpty {
            snapshot.projectiles.removeAll {
                removedProjectileIDs.contains($0.id)
            }
        }
    }

    private func updateTargets(delta: Double, events: inout [SimulationEvent]) {
        removedTargetIDs.removeAll(keepingCapacity: true)
        let gravityRank = abilities[.gravityBoots, default: 0]
        let slowFactor = mode.isEndless
            ? EndlessAbilityRules.gravitySpeedFactor(rank: gravityRank)
            : 0.35 + 0.65 * pow(0.90, Double(gravityRank))
        for index in snapshot.targets.indices {
            var target = snapshot.targets[index]
            let activeTrap = snapshot.magneticTraps.first {
                $0.targetID == target.id && $0.hasLanded
            }
            let trapMovementFactor: Double = if activeTrap == nil {
                1
            } else if target.isShielded {
                1
            } else if target.bossTier == .standard {
                0
            } else {
                0.35
            }
            let tidalMovementFactor = target.tidalSlowRemaining > 0 ? 0.42 : 1
            let undertowMovementFactor = target.undertowSlowRemaining > 0
                ? EndlessSpecialBallRules.undertowSpeedFactor
                : 1
            let abilityMovementFactor = min(
                trapMovementFactor,
                tidalMovementFactor,
                undertowMovementFactor
            )
            let movementWasLocked = target.freezeRemaining > 0
                || target.stunRemaining > 0
                || abilityMovementFactor == 0
            if !movementWasLocked {
                target.phase += delta * abilityMovementFactor
            }

            target.freezeRemaining = max(0, target.freezeRemaining - delta)
            target.reverseRemaining = max(0, target.reverseRemaining - delta)
            target.stunRemaining = max(0, target.stunRemaining - delta)
            target.tidalSlowRemaining = max(
                0,
                target.tidalSlowRemaining - delta
            )
            target.undertowSlowRemaining = max(
                0,
                target.undertowSlowRemaining - delta
            )
            target.magnetRemaining = max(0, target.magnetRemaining - delta)
            if target.magnetRemaining == 0 {
                target.magnetTurnRate = 0
            }
            if target.burnRemaining > 0 {
                target.burnRemaining = max(0, target.burnRemaining - delta)
                target.burnTickClock -= delta
                if target.burnTickClock <= 0 {
                    target.burnTickClock += 0.5
                    let burnDamage = max(
                        1,
                        target.burnTickDamage > 0
                            ? target.burnTickDamage
                            : stats.ballDamage * 0.18
                    )
                    awardCharacterAbilityChargeForBossDamage(
                        to: target,
                        damage: burnDamage,
                        awardsAbilityCharge: true
                    )
                    target.hitPoints -= burnDamage
                    events.append(impactEvent(
                        for: target,
                        damage: burnDamage,
                        flavor: .fire,
                        critical: false,
                        delivery: .damageOverTime,
                        impulse: .init(x: 0, y: 0)
                    ))
                    if target.hitPoints <= 0 {
                        removedTargetIDs.insert(target.id)
                        awardReward(for: target, events: &events)
                        registerDefeat(target, events: &events)
                        snapshot.targets[index] = target
                        continue
                    }
                }
            }
            if target.burnRemaining == 0 {
                target.burnTickDamage = 0
            }

            let freezeFactor = target.freezeRemaining > 0 || target.stunRemaining > 0
                ? 0
                : abilityMovementFactor
            let direction = target.reverseRemaining > 0 ? -1.0 : 1.0
            switch target.kind {
            case .enemy(let kind):
                if target.bossTier != .standard {
                    let movementRate = CampaignBalance.bossMovementRate(tier: target.bossTier)
                    let amplitude = target.bossTier == .megaBoss ? 0.68 : 0.58
                    if freezeFactor > 0 {
                        target.bossMovementPhase += delta * freezeFactor * direction
                        target.position.x = sin(target.bossMovementPhase * movementRate)
                            * amplitude
                    }
                    let healthRatio = target.hitPoints / target.maximumHitPoints
                    let newPhase = healthRatio > 0.66 ? 1 : (healthRatio > 0.33 ? 2 : 3)
                    if newPhase > bossPhase {
                        let crossedPhases = (bossPhase + 1)...newPhase
                        bossPhase = newPhase
                        for crossedPhase in crossedPhases {
                            if target.maximumShieldHitPoints > 0 {
                                target.shieldHitPoints = target.maximumShieldHitPoints
                                clearEnemyEffects(on: &target)
                                snapshot.magneticTraps.removeAll {
                                    $0.targetID == target.id
                                }
                                timeBreakTargetIDs.remove(target.id)
                                events.append(.enemyShieldRefreshed(target.position))
                            }
                            events.append(.bossPhase(crossedPhase))
                            pendingReinforcementPhases.append(crossedPhase)
                            if world == .mars {
                                pendingVolatileCorePositions.append(target.position)
                            }
                        }
                    }
                    let attackInterval = max(
                        0.60,
                        (2.3 - Double(bossPhase) * 0.3)
                            * activeAttackCadenceMultiplier
                    )
                    if freezeFactor > 0,
                       target.phase.truncatingRemainder(dividingBy: attackInterval) < delta {
                        spawnProjectile(
                            x: target.position.x,
                            y: target.position.y - 0.05,
                            velocityX: (random.unit() - 0.5) * 0.14,
                            damage: 14 * activeDamageMultiplier,
                            pierce: 0,
                            hostile: true,
                            critical: false
                        )
                    }
                } else {
                    let gravityMovementFactor = target.isShielded ? 1 : slowFactor
                    target.position.y -= enemySpeed(kind) * activeSpeedMultiplier * gravityMovementFactor * freezeFactor * direction * delta
                    if kind == .tackleBot || kind == .craterCrawler || kind == .lunarHopper {
                        target.position.x += sin(target.phase * 5.2) * delta * 0.23 * direction * freezeFactor
                    }
                    if freezeFactor > 0,
                       isRanged(kind),
                       target.phase.truncatingRemainder(
                           dividingBy: 3.0 * activeAttackCadenceMultiplier
                       ) < delta,
                       target.position.y < 0.86 {
                        spawnProjectile(
                            x: target.position.x,
                            y: target.position.y - 0.04,
                            velocityX: 0,
                            damage: 12 * activeDamageMultiplier,
                            pierce: 0,
                            hostile: true,
                            critical: false
                        )
                    }
                }
                if target.position.y <= 0.12 {
                    removedTargetIDs.insert(target.id)
                    applyDamage(contactDamage(kind) * activeDamageMultiplier, events: &events)
                } else if target.position.y > 1.18 {
                    target.position.y = 1.18
                }
            case .fieldObject:
                target.position.y -= 0.11
                    * activeSpeedMultiplier
                    * slowFactor
                    * freezeFactor
                    * direction
                    * delta
                if target.position.y <= 0.12 { removedTargetIDs.insert(target.id) }
            case .powerUp:
                target.position.y -= 0.26 * delta
                target.position.x += sin(target.phase * 9.5) * 2.2 * delta
                target.position.x = min(0.82, max(-0.82, target.position.x))
                if target.position.y <= 0.12 { removedTargetIDs.insert(target.id) }
            case .volatileCore:
                target.position.y -= 0.10 * delta
                target.position.x += sin(target.phase * 6.5) * 0.08 * delta
                if target.phase >= 2.75 || target.position.y <= 0.12 {
                    removedTargetIDs.insert(target.id)
                    events.append(.volatileCoreDetonated(target.position))
                    applyDamage(18 * activeDamageMultiplier, events: &events)
                }
            }
            applyGravityPull(to: &target, delta: delta)
            snapshot.targets[index] = target
        }
        if !removedTargetIDs.isEmpty {
            snapshot.targets.removeAll { removedTargetIDs.contains($0.id) }
        }
    }

    private func applyGravityPull(to target: inout TargetState, delta: Double) {
        guard !target.isShielded,
              let center = target.gravityPullCenter,
              target.gravityPullRemaining > 0,
              target.gravityPullStrength > 0 else {
            return
        }

        let activeDelta = min(delta, target.gravityPullRemaining)
        target.gravityPullRemaining = max(
            0,
            target.gravityPullRemaining - activeDelta
        )
        let pullFraction = 1 - exp(-target.gravityPullStrength * activeDelta)
        target.position.x += (center.x - target.position.x) * pullFraction
        target.position.y += (center.y - target.position.y) * pullFraction

        if target.gravityPullRemaining == 0 {
            target.gravityPullCenter = nil
            target.gravityPullStrength = 0
        }
    }

    private func updateCharacterAttacks(delta: Double, events: inout [SimulationEvent]) {
        guard !snapshot.characterAttacks.isEmpty else { return }
        hitTargetIDs.removeAll(keepingCapacity: true)
        var completedAttackIDs = Set<Int>()

        for attackIndex in snapshot.characterAttacks.indices {
            var attack = snapshot.characterAttacks[attackIndex]
            if attack.delayRemaining > 0 {
                attack.delayRemaining = max(0, attack.delayRemaining - delta)
                snapshot.characterAttacks[attackIndex] = attack
                continue
            }

            attack.elapsed = min(attack.duration, attack.elapsed + delta)
            let progress = attack.progress
            switch attack.kind {
            case .meteor:
                if let targetID = attack.targetID,
                   let target = snapshot.targets.first(where: { $0.id == targetID }) {
                    attack.destination = target.position
                }
                let eased = progress * progress * (3 - 2 * progress)
                attack.position = .init(
                    x: attack.startPosition.x + (attack.destination.x - attack.startPosition.x) * eased,
                    y: attack.startPosition.y + (attack.destination.y - attack.startPosition.y) * eased
                )
                if progress >= 1 {
                    resolveMeteorImpact(attack, events: &events)
                    completedAttackIDs.insert(attack.id)
                }
            case .shockwave:
                let travel = 1 - pow(1 - progress, 1.35)
                let expansion = 1 - pow(1 - progress, 2.8)
                attack.position = .init(
                    x: attack.startPosition.x,
                    y: attack.startPosition.y
                        + (attack.destination.y - attack.startPosition.y) * travel
                )
                attack.width = 0.18 + 1.82 * expansion
                applyShockwaveHits(&attack, events: &events)
                if progress >= 1 {
                    completedAttackIDs.insert(attack.id)
                }
            }
            snapshot.characterAttacks[attackIndex] = attack
        }

        if !completedAttackIDs.isEmpty {
            snapshot.characterAttacks.removeAll { completedAttackIDs.contains($0.id) }
        }
        if !hitTargetIDs.isEmpty {
            snapshot.targets.removeAll { hitTargetIDs.contains($0.id) }
        }
        hitTargetIDs.removeAll(keepingCapacity: true)
    }

    private func resolveMeteorImpact(
        _ attack: CharacterAttackState,
        events: inout [SimulationEvent]
    ) {
        events.append(.characterMeteorImpact(attack.destination))
        let verticalRadius = world == .mars ? 0.13 : 0.10
        for index in snapshot.targets.indices {
            let target = snapshot.targets[index]
            let horizontalDistance = (target.position.x - attack.destination.x) / attack.width
            let verticalDistance = (target.position.y - attack.destination.y) / verticalRadius
            guard !isPowerUp(target),
                  !hitTargetIDs.contains(target.id),
                  horizontalDistance * horizontalDistance
                    + verticalDistance * verticalDistance <= 1 else { continue }
            let damage = target.id == attack.targetID ? attack.damage : attack.damage * 0.55
            let resolution = applyTargetDamage(
                damage,
                at: index,
                events: &events
            )
            awardCharacterAbilityChargeForBossDamage(
                to: target,
                damage: resolution.appliedDamage,
                awardsAbilityCharge: attack.awardsAbilityCharge
            )
            events.append(impactEvent(
                for: snapshot.targets[index],
                damage: resolution.appliedDamage,
                flavor: .explosive,
                critical: true,
                delivery: .area,
                impulse: .init(
                    x: target.position.x - attack.destination.x,
                    y: target.position.y - attack.destination.y
                )
            ))
            registerDefeatIfNeeded(
                at: index,
                awardsAbilityCharge: attack.awardsAbilityCharge,
                characterAbilityCredit: !attack.awardsAbilityCharge,
                events: &events
            )
        }
    }

    private func applyShockwaveHits(
        _ attack: inout CharacterAttackState,
        events: inout [SimulationEvent]
    ) {
        let halfWidth = attack.width * 0.5
        snapshot.projectiles.removeAll {
            $0.hostile
                && abs($0.position.y - attack.position.y) <= 0.085
                && abs($0.position.x - attack.position.x) <= halfWidth
        }
        for index in snapshot.targets.indices {
            let target = snapshot.targets[index]
            guard !isPowerUp(target),
                  !hitTargetIDs.contains(target.id),
                  !attack.contactedTargetIDs.contains(target.id),
                  abs(target.position.y - attack.position.y) <= 0.075,
                  abs(target.position.x - attack.position.x) <= halfWidth else { continue }
            attack.contactedTargetIDs.insert(target.id)
            let resolution = applyTargetDamage(
                attack.damage,
                at: index,
                events: &events
            )
            awardCharacterAbilityChargeForBossDamage(
                to: target,
                damage: resolution.appliedDamage,
                awardsAbilityCharge: attack.awardsAbilityCharge
            )
            if !resolution.blocksEffects {
                snapshot.targets[index].stunRemaining = max(
                    snapshot.targets[index].stunRemaining,
                    0.78
                )
            }
            events.append(.characterShockwaveHit(target.position))
            events.append(impactEvent(
                for: snapshot.targets[index],
                damage: resolution.appliedDamage,
                flavor: .standard,
                critical: false,
                delivery: .area,
                impulse: .init(
                    x: target.position.x - attack.position.x,
                    y: 0.3
                )
            ))
            registerDefeatIfNeeded(
                at: index,
                awardsAbilityCharge: attack.awardsAbilityCharge,
                characterAbilityCredit: !attack.awardsAbilityCharge,
                events: &events
            )
        }
    }

    private func updateProjectiles(delta: Double, events: inout [SimulationEvent]) {
        removedProjectileIDs.removeAll(keepingCapacity: true)
        hitTargetIDs.removeAll(keepingCapacity: true)
        var splitProjectiles: [ProjectileState] = []
        for projectileIndex in snapshot.projectiles.indices {
            var projectile = snapshot.projectiles[projectileIndex]
            let movementDelta = projectile.hostile && timeBreakRemaining > 0
                ? 0
                : delta
            if !projectile.hostile,
               projectile.characterProjectile == nil,
               let marked = nearestMagnetizedTarget(for: projectile) {
                steerProjectile(
                    &projectile,
                    toward: marked.position,
                    turnRate: marked.magnetTurnRate,
                    delta: movementDelta
                )
            } else if projectile.hasEffect(.heatSeeking),
               let nearest = nearestHeatSeekingTarget(for: projectile) {
                steerHeatSeekingProjectile(
                    &projectile,
                    toward: nearest.position,
                    delta: movementDelta
                )
            } else {
                let curlerRank = abilities[.curler, default: 0]
                if !projectile.hostile,
                   projectile.characterProjectile == nil,
                   curlerRank > 0,
                   let nearest = nearestSteeringTarget(for: projectile) {
                    steerProjectile(
                        &projectile,
                        toward: nearest.position,
                        turnRate: curlerTurnRate(rank: curlerRank),
                        delta: movementDelta
                    )
                }
            }
            if world == .jupiter,
               worldHazardDelayRemaining == 0,
               worldHazardActiveRemaining > 0,
               !projectile.hostile,
               projectile.characterProjectile == nil {
                projectile.velocity.x += worldHazardDirection * 0.34 * movementDelta
            }
            projectile.position.x += projectile.velocity.x * movementDelta
            projectile.position.y += projectile.velocity.y * movementDelta
            if projectile.characterProjectile == .pinballBlitz {
                projectile.remainingLifetime -= delta
                for hostileProjectile in snapshot.projectiles where
                    hostileProjectile.hostile
                        && hypot(
                            hostileProjectile.position.x - projectile.position.x,
                            hostileProjectile.position.y - projectile.position.y
                        ) <= 0.075 {
                    removedProjectileIDs.insert(hostileProjectile.id)
                }
                let lateralLimit = 0.88
                if projectile.position.x <= -lateralLimit || projectile.position.x >= lateralLimit {
                    projectile.position.x = min(lateralLimit, max(-lateralLimit, projectile.position.x))
                    projectile.velocity.x = abs(projectile.velocity.x) * (projectile.position.x < 0 ? 1 : -1)
                    events.append(.characterProjectileRicochet(projectile.position))
                }
            }
            if world == .saturn,
               !projectile.hostile,
               projectile.characterProjectile == nil,
               projectile.position.y <= 0.26,
               snapshot.bossHazards.contains(where: {
                   $0.kind == .ringSegment
                       && $0.isActive
                       && abs(projectile.position.x - $0.position.x) <= $0.halfWidth
               }) {
                removedProjectileIDs.insert(projectile.id)
            }
            if projectile.hostile {
                let width = assistMode ? 0.08 : 0.11
                let isInUpperBodyBand = projectile.position.y >= 0.095 && projectile.position.y <= 0.17
                if isInUpperBodyBand && abs(projectile.position.x - snapshot.playerX) < width {
                    removedProjectileIDs.insert(projectile.id)
                    applyDamage(projectile.damage, events: &events)
                } else if projectile.position.y < 0.095 {
                    removedProjectileIDs.insert(projectile.id)
                }
            } else {
                let isPinball = projectile.characterProjectile == .pinballBlitz
                if let targetIndex = snapshot.targets.firstIndex(where: {
                    let hitbox = targetHitbox(for: $0)
                    return !hitTargetIDs.contains($0.id)
                        && !projectile.contactedTargetIDs.contains($0.id)
                        && abs($0.position.x - projectile.position.x)
                            < hitbox.halfWidth + (isPinball ? 0.035 : assistMode ? 0.055 : 0)
                        && abs($0.position.y - projectile.position.y) < hitbox.halfHeight
                }) {
                    let position = snapshot.targets[targetIndex].position
                    let targetID = snapshot.targets[targetIndex].id
                    let targetBlockedEffects = snapshot.targets[targetIndex].isShielded
                    let hitEnemy = if case .enemy = snapshot.targets[targetIndex].kind {
                        true
                    } else {
                        false
                    }
                    applyProjectileHit(projectile, to: targetIndex, events: &events)
                    if projectile.hasEffect(.volt),
                       !projectile.hasTriggeredVoltChain,
                       hitEnemy {
                        projectile.hasTriggeredVoltChain = true
                        applyVoltChain(
                            from: position,
                            originTargetID: targetID,
                            projectileDamage: projectile.damage,
                            events: &events
                        )
                    }
                    if projectile.hasEffect(.solarPierce) {
                        events.append(.specialBallEffect(
                            .solarPierce(position: position)
                        ))
                    }
                    if projectile.hasEffect(.explosive) {
                        let explosiveRank = specialBallRank(.explosive)
                        let damageMultiplier = mode.isEndless
                            ? EndlessSpecialBallRules.explosionDamageMultiplier(rank: explosiveRank)
                            : 0.55
                        let radius = mode.isEndless
                            ? EndlessSpecialBallRules.explosionRadius(rank: explosiveRank)
                            : 0.28
                        applyExplosion(
                            centeredAt: position,
                            excluding: snapshot.targets[targetIndex].id,
                            damage: projectile.damage * damageMultiplier,
                            radius: radius,
                            events: &events
                        )
                    }
                    if projectile.hasEffect(.gravityWell) {
                        let rank = specialBallRank(.gravityWell)
                        let radius = mode.isEndless
                            ? EndlessSpecialBallRules.gravityWellRadius(rank: rank)
                            : 0.42
                        let damageMultiplier = mode.isEndless
                            ? EndlessSpecialBallRules.gravityWellDamageMultiplier(rank: rank)
                            : 0.38
                        let pullStrength = mode.isEndless
                            ? EndlessSpecialBallRules.gravityWellPullStrength(rank: rank)
                            : 6.5
                        for index in snapshot.targets.indices {
                            let target = snapshot.targets[index]
                            let isPullable = switch target.kind {
                            case .enemy, .fieldObject: true
                            case .powerUp, .volatileCore: false
                            }
                            guard target.id != targetID,
                                  !target.isShielded,
                                  isPullable,
                                  hypot(target.position.x - position.x, target.position.y - position.y) <= radius else {
                                continue
                            }
                            snapshot.targets[index].gravityPullCenter = position
                            snapshot.targets[index].gravityPullRemaining = max(
                                snapshot.targets[index].gravityPullRemaining,
                                EndlessSpecialBallRules.gravityWellPullDuration
                            )
                            snapshot.targets[index].gravityPullStrength = max(
                                snapshot.targets[index].gravityPullStrength,
                                pullStrength
                            )
                        }
                        events.append(.specialBallEffect(
                            .gravityVortex(position: position, radius: radius)
                        ))
                        applyExplosion(
                            centeredAt: position,
                            excluding: targetID,
                            damage: projectile.damage * damageMultiplier,
                            radius: radius,
                            events: &events
                        )
                    }
                    if projectile.hasEffect(.polarLink),
                       snapshot.targets.indices.contains(targetIndex),
                       hitEnemy,
                       !targetBlockedEffects,
                       snapshot.targets[targetIndex].hitPoints > 0 {
                        let rank = specialBallRank(.polarLink)
                        let turnRate = mode.isEndless
                            ? EndlessSpecialBallRules.polarLinkTurnRate(
                                rank: rank
                            )
                            : 5.5
                        let duration = mode.isEndless
                            ? EndlessSpecialBallRules.polarLinkMarkDuration(
                                rank: rank
                            )
                            : 1.4
                        snapshot.targets[targetIndex].magnetRemaining = max(
                            snapshot.targets[targetIndex].magnetRemaining,
                            duration
                        )
                        snapshot.targets[targetIndex].magnetTurnRate = max(
                            snapshot.targets[targetIndex].magnetTurnRate,
                            turnRate
                        )
                        events.append(.specialBallEffect(
                            .magnetMark(position: position, duration: duration)
                        ))
                    }
                    if projectile.hasEffect(.undertow),
                       snapshot.targets.indices.contains(targetIndex),
                       hitEnemy,
                       !targetBlockedEffects,
                       snapshot.targets[targetIndex].bossTier == .standard {
                        let rank = specialBallRank(.undertow)
                        let push = mode.isEndless
                            ? EndlessSpecialBallRules.undertowPush(rank: rank)
                            : 0.14
                        let duration = mode.isEndless
                            ? EndlessSpecialBallRules.undertowSlowDuration(rank: rank)
                            : 0.55
                        snapshot.targets[targetIndex].position.y = min(
                            1.04,
                            snapshot.targets[targetIndex].position.y + push
                        )
                        snapshot.targets[targetIndex].undertowSlowRemaining = max(
                            snapshot.targets[targetIndex].undertowSlowRemaining,
                            duration
                        )
                        events.append(.specialBallEffect(
                            .tidalPush(position: position)
                        ))
                    }
                    if projectile.hasEffect(.split), projectile.canSplit {
                        let splitRank = specialBallRank(.split)
                        let damageMultiplier = mode.isEndless
                            ? EndlessSpecialBallRules.splitDamageMultiplier(rank: splitRank)
                            : 0.42
                        let count = mode.isEndless
                            ? EndlessSpecialBallRules.splitProjectileCount(
                                rank: splitRank,
                                isCritical: projectile.isCritical
                            )
                            : projectile.isCritical ? 8 : 5
                        splitProjectiles.append(
                            contentsOf: makeSplitProjectiles(
                                from: position,
                                damage: projectile.damage * damageMultiplier,
                                count: count
                            )
                        )
                    }
                    if isPinball {
                        projectile.contactedTargetIDs.insert(targetID)
                        projectile.velocity.x *= -1
                        events.append(.characterProjectileRicochet(position))
                    } else if projectile.hasEffect(.orbitShot),
                              projectile.orbitChainsRemaining > 0 {
                        projectile.contactedTargetIDs.insert(targetID)
                        projectile.orbitChainsRemaining -= 1
                        if let next = nearestOrbitTarget(
                            from: projectile.position,
                            excluding: projectile.contactedTargetIDs
                        ) {
                            let dx = next.position.x - projectile.position.x
                            let dy = next.position.y - projectile.position.y
                            let length = max(0.001, hypot(dx, dy))
                            projectile.velocity = .init(
                                x: dx / length * stats.ballSpeed,
                                y: dy / length * stats.ballSpeed
                            )
                            events.append(.specialBallEffect(
                                .orbitRedirect(position: position)
                            ))
                        }
                    } else if projectile.hasEffect(.ringReturn),
                              projectile.orbitChainsRemaining > 0 {
                        projectile.contactedTargetIDs.insert(targetID)
                    } else if projectile.remainingPierces > 0 {
                        projectile.contactedTargetIDs.insert(targetID)
                        projectile.remainingPierces -= 1
                    } else {
                        removedProjectileIDs.insert(projectile.id)
                    }
                }
                if projectile.hasEffect(.ringReturn),
                   (projectile.position.y > 1.12 || projectile.position.y < 0.08),
                   projectile.orbitChainsRemaining > 0 {
                    let isAtTop = projectile.position.y > 1.12
                    projectile.position.y = isAtTop ? 1.10 : 0.10
                    projectile.velocity.y = isAtTop
                        ? -abs(projectile.velocity.y)
                        : abs(projectile.velocity.y)
                    if let returnDamage = projectile.ringReturnDamage {
                        projectile.damage = returnDamage
                    }
                    projectile.orbitChainsRemaining -= 1
                    projectile.contactedTargetIDs.removeAll(keepingCapacity: true)
                    events.append(.specialBallEffect(
                        .returnShot(position: projectile.position)
                    ))
                }
                if projectile.remainingLifetime <= 0
                    || ((projectile.position.y > 1.12 || projectile.position.y < 0.08)
                        && (!projectile.hasEffect(.ringReturn)
                            || projectile.orbitChainsRemaining == 0))
                    || (projectile.characterProjectile == nil && abs(projectile.position.x) > 1.1) {
                    removedProjectileIDs.insert(projectile.id)
                }
            }
            snapshot.projectiles[projectileIndex] = projectile
        }
        snapshot.projectiles.append(contentsOf: splitProjectiles)
        if !removedProjectileIDs.isEmpty {
            snapshot.projectiles.removeAll { removedProjectileIDs.contains($0.id) }
        }
        if !hitTargetIDs.isEmpty {
            snapshot.targets.removeAll { hitTargetIDs.contains($0.id) }
        }
    }

    private func applyProjectileHit(
        _ projectile: ProjectileState,
        to targetIndex: Int,
        events: inout [SimulationEvent]
    ) {
        if case .powerUp = snapshot.targets[targetIndex].kind {
            snapshot.targets[targetIndex].hitPoints = 0
            registerDefeatIfNeeded(at: targetIndex, events: &events)
            return
        }
        if case .volatileCore = snapshot.targets[targetIndex].kind {
            let position = snapshot.targets[targetIndex].position
            hitTargetIDs.insert(snapshot.targets[targetIndex].id)
            events.append(.volatileCoreNeutralized(position))
            return
        }

        let flavor = damageFlavor(for: projectile.ballEffects)
        let targetBeforeDamage = snapshot.targets[targetIndex]
        let resolution = applyTargetDamage(
            projectile.damage,
            at: targetIndex,
            events: &events
        )
        awardCharacterAbilityChargeForBossDamage(
            to: targetBeforeDamage,
            damage: resolution.appliedDamage,
            awardsAbilityCharge: projectile.characterProjectile == nil
        )
        if projectile.hasEffect(.fire), !resolution.blocksEffects {
            let fireRank = specialBallRank(.fire)
            let duration = mode.isEndless
                ? EndlessSpecialBallRules.fireDuration(rank: fireRank)
                : 4
            let tickDamageMultiplier = mode.isEndless
                ? EndlessSpecialBallRules.fireTickDamageMultiplier(rank: fireRank)
                : 0.18
            let tickDamage = projectile.damage * tickDamageMultiplier
            snapshot.targets[targetIndex].burnRemaining = max(
                snapshot.targets[targetIndex].burnRemaining,
                duration
            )
            snapshot.targets[targetIndex].burnTickClock = min(snapshot.targets[targetIndex].burnTickClock, 0.18)
            snapshot.targets[targetIndex].burnTickDamage = max(
                snapshot.targets[targetIndex].burnTickDamage,
                tickDamage
            )
        }
        if projectile.hasEffect(.ice), !resolution.blocksEffects {
            let duration = mode.isEndless
                ? EndlessSpecialBallRules.iceDuration(rank: specialBallRank(.ice))
                : 1.7
            snapshot.targets[targetIndex].freezeRemaining = max(
                snapshot.targets[targetIndex].freezeRemaining,
                duration
            )
        }
        if projectile.hasEffect(.reverse), !resolution.blocksEffects {
            let duration = mode.isEndless
                ? EndlessSpecialBallRules.reverseDuration(rank: specialBallRank(.reverse))
                : 2.8
            snapshot.targets[targetIndex].reverseRemaining = max(
                snapshot.targets[targetIndex].reverseRemaining,
                duration
            )
        }
        events.append(impactEvent(
            for: snapshot.targets[targetIndex],
            damage: resolution.appliedDamage,
            flavor: flavor,
            critical: projectile.isCritical,
            delivery: .direct,
            impulse: projectile.velocity
        ))
        registerDefeatIfNeeded(
            at: targetIndex,
            awardsAbilityCharge: projectile.characterProjectile == nil,
            characterAbilityCredit: projectile.characterProjectile != nil,
            events: &events
        )
    }

    private func applyExplosion(
        centeredAt center: Vector2,
        excluding excludedID: Int,
        damage: Double,
        radius: Double,
        awardsAbilityCharge: Bool = true,
        events: inout [SimulationEvent]
    ) {
        for index in snapshot.targets.indices {
            let target = snapshot.targets[index]
            guard target.id != excludedID,
                  !hitTargetIDs.contains(target.id),
                  hypot(target.position.x - center.x, target.position.y - center.y) <= radius else { continue }
            if case .powerUp = target.kind { continue }
            if case .volatileCore = target.kind { continue }
            let resolution = applyTargetDamage(
                damage,
                at: index,
                events: &events
            )
            awardCharacterAbilityChargeForBossDamage(
                to: target,
                damage: resolution.appliedDamage,
                awardsAbilityCharge: awardsAbilityCharge
            )
            events.append(impactEvent(
                for: snapshot.targets[index],
                damage: resolution.appliedDamage,
                flavor: .explosive,
                critical: false,
                delivery: .area,
                impulse: .init(
                    x: target.position.x - center.x,
                    y: target.position.y - center.y
                )
            ))
            registerDefeatIfNeeded(
                at: index,
                awardsAbilityCharge: awardsAbilityCharge,
                events: &events
            )
        }
    }

    private func applyVoltChain(
        from origin: Vector2,
        originTargetID: Int,
        projectileDamage: Double,
        events: inout [SimulationEvent]
    ) {
        let orderedTargetIndices = snapshot.targets.indices
            .filter { index in
                let target = snapshot.targets[index]
                guard target.id != originTargetID,
                      target.hitPoints > 0,
                      !hitTargetIDs.contains(target.id) else {
                    return false
                }
                if case .enemy = target.kind { return true }
                return false
            }
            .sorted { leftIndex, rightIndex in
                let left = snapshot.targets[leftIndex]
                let right = snapshot.targets[rightIndex]
                let leftDistance = hypot(
                    left.position.x - origin.x,
                    left.position.y - origin.y
                )
                let rightDistance = hypot(
                    right.position.x - origin.x,
                    right.position.y - origin.y
                )
                if abs(leftDistance - rightDistance) > 0.000_001 {
                    return leftDistance < rightDistance
                }
                return left.id < right.id
            }

        guard !orderedTargetIndices.isEmpty else { return }

        var nodePositions = [origin]
        var arcs: [VoltArc] = []
        var aftermathEvents: [SimulationEvent] = []
        for (offset, targetIndex) in orderedTargetIndices.enumerated() {
            let recipientOrder = offset + 1
            let target = snapshot.targets[targetIndex]
            let parentOrder = recipientOrder / 2
            let damageMultiplier = EndlessSpecialBallRules.voltDamageMultiplier(
                recipientOffset: offset,
                recipientCount: orderedTargetIndices.count,
                rank: mode.isEndless
                    ? specialBallRank(.volt)
                    : EndlessSpecialBallRules.campaignEquivalentRank
            )
            let damage = projectileDamage * damageMultiplier
            let resolution = applyTargetDamage(
                damage,
                at: targetIndex,
                events: &aftermathEvents
            )
            awardCharacterAbilityChargeForBossDamage(
                to: target,
                damage: resolution.appliedDamage,
                awardsAbilityCharge: true
            )
            let generation = Int(log2(Double(recipientOrder)).rounded(.down)) + 1
            arcs.append(VoltArc(
                source: nodePositions[parentOrder],
                targetID: target.id,
                destination: target.position,
                generation: generation,
                recipientOrder: recipientOrder,
                damage: resolution.appliedDamage,
                isDefeating: snapshot.targets[targetIndex].hitPoints <= 0
            ))
            nodePositions.append(target.position)
            registerDefeatIfNeeded(at: targetIndex, events: &aftermathEvents)
        }

        events.append(.voltChain(VoltChainEvent(
            originTargetID: originTargetID,
            origin: origin,
            arcs: arcs
        )))
        events.append(contentsOf: aftermathEvents)
    }

    private func registerDefeatIfNeeded(
        at index: Int,
        awardsAbilityCharge: Bool = true,
        characterAbilityCredit: Bool = false,
        events: inout [SimulationEvent]
    ) {
        let target = snapshot.targets[index]
        guard target.hitPoints <= 0, !hitTargetIDs.contains(target.id) else { return }
        hitTargetIDs.insert(target.id)
        awardReward(for: target, events: &events)
        if case .powerUp = target.kind { return }
        if case .volatileCore = target.kind {
            events.append(.volatileCoreNeutralized(target.position))
            return
        }
        registerDefeat(
            target,
            awardsAbilityCharge: awardsAbilityCharge,
            characterAbilityCredit: characterAbilityCredit,
            events: &events
        )
    }

    private func makeSplitProjectiles(from position: Vector2, damage: Double, count: Int) -> [ProjectileState] {
        (0..<count).map { index in
            let angle = Double(index) / Double(count) * .pi * 2
            return ProjectileState(
                id: identifier(),
                position: position,
                velocity: .init(x: cos(angle) * stats.ballSpeed, y: sin(angle) * stats.ballSpeed),
                damage: damage,
                remainingPierces: 0,
                hostile: false,
                isCritical: false,
                temporaryAbility: .split,
                canSplit: false
            )
        }
    }

    private func evaluateWave(events: inout [SimulationEvent]) {
        guard !snapshot.isBossWave,
              snapshot.waveDefeats >= snapshot.waveEnemyQuota else { return }
        completeWave(events: &events)
    }

    private func completeWave(events: inout [SimulationEvent]) {
        let completedWave = snapshot.wave
        let endlessWorldTransition = mode.isEndless
            ? EndlessRules.worldTransition(after: completedWave)
            : nil
        if mode.isEndless {
            snapshot.score += EndlessRules.waveClearScore(wave: completedWave)
            awardTokens(
                EndlessRules.waveClearTokenBase(wave: completedWave),
                at: .init(x: snapshot.playerX, y: 0.16),
                awardsScore: false,
                events: &events
            )
        }

        let recoveryRank = abilities[.secondWind, default: 0]
        if recoveryRank > 0 {
            let recovery = mode.isEndless
                ? EndlessAbilityRules.secondWindWaveRecovery(rank: recoveryRank)
                : 4 + Double(recoveryRank) * 3
            let amount = min(
                snapshot.maxStamina - snapshot.stamina,
                recovery
            )
            if amount > 0 {
                snapshot.stamina += amount
                events.append(.heal(amount, .init(x: snapshot.playerX, y: 0.16)))
            }
        }

        if let level, completedWave >= level.waveCount {
            finished = true
            snapshot.targets.removeAll()
            snapshot.projectiles.removeAll()
            snapshot.characterAttacks.removeAll()
            snapshot.galeBounces.removeAll()
            snapshot.galeInterceptors.removeAll()
            snapshot.haloRings.removeAll()
            snapshot.magneticTraps.removeAll()
            snapshot.tidalWaves.removeAll()
            snapshot.bossHazards.removeAll()
            pendingVolatileCorePositions.removeAll(keepingCapacity: true)
            events.append(.waveCompleted(completedWave))
            events.append(.finished(true))
            return
        }

        snapshot.targets.removeAll()
        snapshot.wave += 1
        if mode.isEndless {
            snapshot.world = EndlessRules.world(for: snapshot.wave)
        }
        snapshot.projectiles.removeAll()
        snapshot.characterAttacks.removeAll()
        snapshot.galeBounces.removeAll()
        snapshot.galeInterceptors.removeAll()
        snapshot.haloRings.removeAll()
        snapshot.magneticTraps.removeAll()
        snapshot.tidalWaves.removeAll()
        snapshot.bossHazards.removeAll()
        timeBreakRemaining = 0
        timeBreakTargetIDs.removeAll(keepingCapacity: true)
        galeLandingHitCounts.removeAll(keepingCapacity: true)
        pendingVolatileCorePositions.removeAll(keepingCapacity: true)
        worldHazardDelayRemaining = 0
        worldHazardActiveRemaining = 0
        worldHazardDirection = 0
        playerDriftVelocity = 0
        if endlessWorldTransition != nil {
            resetWorldRuntime()
        }
        resetWaveRuntime()
        events.append(.waveCompleted(completedWave))
        if let endlessWorldTransition {
            events.append(.worldTransitioned(
                from: endlessWorldTransition.from,
                to: endlessWorldTransition.to
            ))
        } else {
            events.append(.checkpoint(completedWave))
        }
    }

    private func evaluateFinish(events: inout [SimulationEvent]) {
        if finishAfterStaminaDepletion(events: &events) { return }
        guard level != nil else { return }
    }

    @discardableResult
    private func finishAfterStaminaDepletion(
        events: inout [SimulationEvent]
    ) -> Bool {
        guard !finished, snapshot.stamina <= 0 else { return false }
        snapshot.stamina = 0
        finished = true
        events.append(.finished(false))
        return true
    }

    private func finishBossWaveIfNeeded(events: inout [SimulationEvent]) -> Bool {
        guard snapshot.isBossWave, bossDefeated else { return false }
        completeWave(events: &events)
        return true
    }

    private func applyDamage(_ amount: Double, events: inout [SimulationEvent]) {
        guard deathSaveDamageGraceRemaining == 0,
              snapshot.stamina > 0 else { return }
        let effectiveAmount = CombatBalance.effectiveIncomingDamage(
            rawDamage: amount,
            maxStamina: snapshot.maxStamina
        )
        if snapshot.shieldCharges > 0 {
            snapshot.shieldCharges -= 1
        } else {
            let previousStamina = snapshot.stamina
            snapshot.stamina = max(0, snapshot.stamina - effectiveAmount)
            if snapshot.stamina < previousStamina, comboCount > 0 {
                comboCount = 0
                snapshot.combo = 0
                snapshot.comboFraction = 0
                events.append(.comboChanged(0))
            }
        }
        events.append(.damage)
    }

    @discardableResult
    private func applyTargetDamage(
        _ amount: Double,
        at index: Int,
        events: inout [SimulationEvent]
    ) -> TargetDamageResolution {
        let requestedDamage = max(0, amount)
        let wasShielded = snapshot.targets[index].shieldHitPoints > 0
        let shieldDamage = min(
            snapshot.targets[index].shieldHitPoints,
            requestedDamage
        )
        snapshot.targets[index].shieldHitPoints -= shieldDamage
        let remainingDamage = requestedDamage - shieldDamage
        let healthDamage = min(
            max(0, snapshot.targets[index].hitPoints),
            remainingDamage
        )
        snapshot.targets[index].hitPoints -= remainingDamage
        let brokeShield = wasShielded
            && snapshot.targets[index].shieldHitPoints <= 0
        if brokeShield {
            snapshot.targets[index].shieldHitPoints = 0
            events.append(.enemyShieldBroken(snapshot.targets[index].position))
        }
        return TargetDamageResolution(
            shieldDamage: shieldDamage,
            healthDamage: healthDamage,
            wasShielded: wasShielded,
            brokeShield: brokeShield
        )
    }

    private func clearEnemyEffects(on target: inout TargetState) {
        target.burnRemaining = 0
        target.burnTickClock = 0
        target.burnTickDamage = 0
        target.freezeRemaining = 0
        target.reverseRemaining = 0
        target.stunRemaining = 0
        target.tidalSlowRemaining = 0
        target.undertowSlowRemaining = 0
        target.magnetRemaining = 0
        target.magnetTurnRate = 0
        target.gravityPullCenter = nil
        target.gravityPullRemaining = 0
        target.gravityPullStrength = 0
    }

    private var characterAbilityReferenceQuota: Int {
        if mode.isEndless {
            return EndlessRules.enemyQuota(wave: snapshot.wave)
        }
        guard let level else { return 1 }
        let finalRegularWave = max(1, level.waveCount - 1)
        let referenceWave = min(max(1, snapshot.wave), finalRegularWave)
        return CampaignBalance.regularEnemyQuota(
            wave: referenceWave,
            for: level
        )
    }

    private func characterAbilityDefeatCharge(for target: TargetState) -> Double {
        switch target.kind {
        case .enemy:
            guard target.bossTier == .standard else {
                return 0
            }
            return CharacterAbilityChargeBalance.enemyDefeatCharge(
                referenceQuota: characterAbilityReferenceQuota
            )
        case .fieldObject:
            return CharacterAbilityChargeBalance.fieldObjectDefeatCharge(
                referenceQuota: characterAbilityReferenceQuota
            )
        case .powerUp, .volatileCore:
            return 0
        }
    }

    private func addCharacterAbilityCharge(_ amount: Double) {
        guard amount > 0, !snapshot.characterAbilityReady else { return }
        snapshot.characterAbilityCharge = min(
            CharacterAbilityChargeBalance.fullCharge,
            snapshot.characterAbilityCharge
                + amount * stats.characterAbilityChargeMultiplier
        )
        snapshot.characterAbilityReady =
            snapshot.characterAbilityCharge >= CharacterAbilityChargeBalance.fullCharge
    }

    private func awardCharacterAbilityChargeForBossDamage(
        to target: TargetState,
        damage: Double,
        awardsAbilityCharge: Bool
    ) {
        guard awardsAbilityCharge,
              target.waveRole == .boss || target.bossTier != .standard else {
            return
        }
        let effectiveDamage = min(
            max(0, target.hitPoints + target.shieldHitPoints),
            max(0, damage)
        )
        addCharacterAbilityCharge(
            CharacterAbilityChargeBalance.bossDamageCharge(
                damage: effectiveDamage,
                maximumHitPoints: target.maximumHitPoints
            )
        )
    }

    private func registerDefeat(
        _ target: TargetState,
        awardsAbilityCharge: Bool = true,
        characterAbilityCredit: Bool = false,
        events: inout [SimulationEvent]
    ) {
        comboCount += 1
        snapshot.combo = comboCount
        snapshot.comboFraction = 1
        snapshot.bestCombo = max(snapshot.bestCombo, comboCount)
        snapshot.targetsDefeated += 1
        if case .enemy = target.kind,
           characterAbilityCredit
            || (character.id == .volt && timeBreakTargetIDs.contains(target.id)) {
            snapshot.characterAbilityDefeats += 1
        }
        if awardsAbilityCharge {
            addCharacterAbilityCharge(
                characterAbilityDefeatCharge(for: target)
            )
        }
        if case .enemy = target.kind {
            if target.waveRole == .quota, target.bossTier == .standard {
                snapshot.waveDefeats = min(snapshot.waveEnemyQuota, snapshot.waveDefeats + 1)
            }
            if world == .mars, target.bossTier == .standard {
                marsDefeatCount += 1
                if marsDefeatCount.isMultiple(of: 6) {
                    pendingVolatileCorePositions.append(target.position)
                }
            }
            if target.waveRole == .boss || target.bossTier != .standard {
                snapshot.bossesDefeated += 1
                bossDefeated = true
            }
        }
        events.append(.comboChanged(comboCount))
        if Self.comboMilestones.contains(comboCount) { events.append(.comboMilestone(comboCount)) }
    }

    private func spawnEnemy(
        _ kind: EnemyKind,
        x: Double,
        y: Double,
        tier: CampaignBossTier = .standard,
        role: WaveEnemyRole = .quota
    ) {
        let hitPoints: Double
        if let level, tier != .standard {
            hitPoints = CampaignBalance.bossHitPoints(
                tier: tier,
                wave: snapshot.wave,
                for: level
            )
        } else {
            let multiplier = mode.isEndless
                ? EndlessRules.healthMultiplier(
                    wave: snapshot.wave,
                    startingOffenseFactor: EndlessRules
                        .startingOffenseFactor(stats: stats)
                )
                : level.map {
                    CampaignBalance.wave(snapshot.wave, for: $0).healthMultiplier
                } ?? 1
            let tierMultiplier = if mode.isEndless, tier == .megaBoss {
                EndlessRules.bossHealthMultiplier(wave: snapshot.wave)
            } else {
                CampaignBalance.bossHealthMultiplier(
                    tier: tier,
                    wave: snapshot.wave,
                    world: world
                )
            }
            hitPoints = CombatBalance.baseHealth(kind)
                * multiplier
                * tierMultiplier
        }
        var target = TargetState(
            id: identifier(),
            kind: .enemy(kind),
            position: .init(x: x, y: statusEffectPreview == nil ? y : min(y, 0.62)),
            hitPoints: hitPoints,
            maximumHitPoints: hitPoints,
            phase: 0,
            bossTier: tier,
            waveRole: role
        )
        if mode.isEndless {
            let isBoss = tier != .standard || role == .boss
            let chance = isBoss
                ? EndlessRules.bossShieldSpawnChance(wave: snapshot.wave)
                : EndlessRules.regularShieldSpawnChance(wave: snapshot.wave)
            if chance > 0, random.unit() < chance {
                let fraction = isBoss
                    ? EndlessRules.bossShieldHealthFraction(wave: snapshot.wave)
                    : EndlessRules.regularShieldHealthFraction(wave: snapshot.wave)
                target.maximumShieldHitPoints = hitPoints * fraction
                target.shieldHitPoints = target.maximumShieldHitPoints
            }
        }
        applyStatusEffectPreview(to: &target)
        snapshot.targets.append(target)
    }

    private func spawnObject(_ kind: FieldObjectKind, x: Double, y: Double) {
        let base: Double = switch kind {
        case .ballCart, .meteorCrate, .roverBattery, .pressureCell,
             .ringShardCrate, .magneticCoil, .stormBattery: 18
        case .waterCooler, .oxygenPod, .gravityCell, .cloudCondenser,
             .thermalPod, .cryoCanister, .oxygenBell: 14
        case .tacticsBoard, .holoGate, .satelliteRelay, .lightningMast,
             .shepherdBeacon, .auroraRelay, .currentGate: 35
        case .coneBarricade, .crystalBarricade, .regolithBarricade, .windGate,
             .iceBarricade, .frostBarricade, .coralBarricade: 20
        case .equipmentTrunk, .artifactVault, .lunarVault, .stormVault,
             .crownVault, .polarVault, .trenchVault: 55
        }
        let multiplier = mode.isEndless
            ? sqrt(
                EndlessRules.healthMultiplier(
                    wave: snapshot.wave,
                    startingOffenseFactor: EndlessRules
                        .startingOffenseFactor(stats: stats)
                )
            )
            : 1
        let hitPoints = base * multiplier
        var target = TargetState(
            id: identifier(),
            kind: .fieldObject(kind),
            position: .init(x: x, y: statusEffectPreview == nil ? y : min(y, 0.68)),
            hitPoints: hitPoints,
            maximumHitPoints: hitPoints,
            phase: 0
        )
        applyStatusEffectPreview(to: &target)
        snapshot.targets.append(target)
    }

    private func applyStatusEffectPreview(to target: inout TargetState) {
        switch statusEffectPreview {
        case .fire:
            target.burnRemaining = 30
            target.burnTickClock = .greatestFiniteMagnitude
            target.burnTickDamage = stats.ballDamage * 0.18
        case .ice:
            target.freezeRemaining = 30
        case .reverse:
            target.reverseRemaining = 30
        default:
            break
        }
    }

    private func spawnPowerUp(_ ability: TemporaryBallAbility, x: Double, y: Double) {
        snapshot.targets.append(TargetState(
            id: identifier(),
            kind: .powerUp(ability),
            position: .init(x: x, y: y),
            hitPoints: 1,
            maximumHitPoints: 1,
            phase: random.unit() * .pi * 2
        ))
    }

    private func spawnPendingVolatileCores(events: inout [SimulationEvent]) {
        guard !pendingVolatileCorePositions.isEmpty else { return }
        for position in pendingVolatileCorePositions {
            snapshot.targets.append(TargetState(
                id: identifier(),
                kind: .volatileCore,
                position: position,
                hitPoints: 1,
                maximumHitPoints: 1,
                phase: 0
            ))
            events.append(.worldEffectActivated(.volatileCores, position))
        }
        pendingVolatileCorePositions.removeAll(keepingCapacity: true)
    }

    private func nearestOrbitTarget(
        from position: Vector2,
        excluding excluded: Set<Int>
    ) -> TargetState? {
        snapshot.targets
            .filter { !excluded.contains($0.id) && !isPowerUp($0) }
            .min {
                hypot($0.position.x - position.x, $0.position.y - position.y)
                    < hypot($1.position.x - position.x, $1.position.y - position.y)
            }
    }

    private func nearestHeatSeekingTarget(for projectile: ProjectileState) -> TargetState? {
        var nearest: TargetState?
        var nearestDistance = Double.greatestFiniteMagnitude
        for target in snapshot.targets {
            guard !isPowerUp(target),
                  !hitTargetIDs.contains(target.id),
                  !projectile.contactedTargetIDs.contains(target.id),
                  target.position.y >= projectile.position.y - 0.03 else { continue }
            let dx = target.position.x - projectile.position.x
            let dy = target.position.y - projectile.position.y
            let distance = dx * dx + dy * dy
            if distance < nearestDistance {
                nearest = target
                nearestDistance = distance
            }
        }
        return nearest
    }

    private func nearestMagnetizedTarget(for projectile: ProjectileState) -> TargetState? {
        snapshot.targets
            .filter {
                $0.magnetRemaining > 0
                    && $0.hitPoints > 0
                    && !hitTargetIDs.contains($0.id)
                    && !projectile.contactedTargetIDs.contains($0.id)
            }
            .min {
                hypot(
                    $0.position.x - projectile.position.x,
                    $0.position.y - projectile.position.y
                ) < hypot(
                    $1.position.x - projectile.position.x,
                    $1.position.y - projectile.position.y
                )
            }
    }

    private func steerHeatSeekingProjectile(
        _ projectile: inout ProjectileState,
        toward target: Vector2,
        delta: Double
    ) {
        steerProjectile(&projectile, toward: target, turnRate: 10, delta: delta)
    }

    private func steerProjectile(
        _ projectile: inout ProjectileState,
        toward target: Vector2,
        turnRate: Double,
        delta: Double
    ) {
        let dx = target.x - projectile.position.x
        let dy = target.y - projectile.position.y
        let distance = max(0.001, hypot(dx, dy))
        let speed = max(stats.ballSpeed, hypot(projectile.velocity.x, projectile.velocity.y))
        let desired = Vector2(x: dx / distance * speed, y: dy / distance * speed)
        let turn = 1 - exp(-max(0, turnRate) * delta)
        let blended = Vector2(
            x: projectile.velocity.x + (desired.x - projectile.velocity.x) * turn,
            y: projectile.velocity.y + (desired.y - projectile.velocity.y) * turn
        )
        let blendedSpeed = max(0.001, hypot(blended.x, blended.y))
        projectile.velocity = .init(
            x: blended.x / blendedSpeed * speed,
            y: blended.y / blendedSpeed * speed
        )
    }

    private func nearestSteeringTarget(for projectile: ProjectileState) -> TargetState? {
        snapshot.targets
            .filter {
                !isPowerUp($0)
                    && !projectile.contactedTargetIDs.contains($0.id)
                    && $0.position.y >= projectile.position.y - 0.02
            }
            .min {
                hypot($0.position.x - projectile.position.x, $0.position.y - projectile.position.y)
                    < hypot($1.position.x - projectile.position.x, $1.position.y - projectile.position.y)
            }
    }

    private func curlerTurnRate(rank: Int) -> Double {
        if mode.isEndless {
            return EndlessAbilityRules.curlerTurnRate(rank: rank)
        }
        return [0, 3.5, 6.5, 9][min(max(rank, 0), 3)]
    }

    private func targetHitbox(for target: TargetState) -> (halfWidth: Double, halfHeight: Double) {
        let dimensions: (width: Double, height: Double) = switch target.kind {
        case .enemy(let enemy):
            switch enemy {
            case .coneRunner, .cloudRunner, .ringRunner, .frostSprinter, .mistRunner: (0.14, 0.055)
            case .dummyDefender, .regolithRunner, .dustSprite, .pressureBrute,
                 .iceMason, .tiltBrute, .currentBrute: (0.17, 0.058)
            case .tackleBot, .roverRaider, .vortexSkimmer, .shepherdDrone,
                 .auroraDrifter, .squallRay: (0.19, 0.060)
            case .keeperDrone, .ballLauncher, .lunarHopper, .orbitDrone,
                 .eclipseKeeper, .gravityStriker, .saucerKeeper, .plasmaStriker,
                 .stormKeeper, .boltStriker, .haloKeeper, .shardStriker,
                 .polarKeeper, .magnetStriker, .tridentKeeper, .pressureStriker: (0.21, 0.066)
            case .craterCrawler: (0.23, 0.058)
            case .titanKeeper, .lunarWarden, .marsColossus, .tempestRegent,
                 .crownSovereign, .axisPrime, .abyssalMonarch: (0.25, 0.078)
            }
        case .fieldObject(let object):
            switch object {
            case .waterCooler, .gravityCell, .cloudCondenser, .thermalPod,
                 .cryoCanister, .oxygenBell: (0.15, 0.066)
            case .ballCart, .roverBattery, .tacticsBoard, .satelliteRelay,
                 .pressureCell, .ringShardCrate, .magneticCoil, .stormBattery,
                 .lightningMast, .shepherdBeacon, .auroraRelay, .currentGate: (0.19, 0.068)
            case .coneBarricade, .regolithBarricade, .holoGate, .windGate,
                 .iceBarricade, .frostBarricade, .coralBarricade: (0.25, 0.060)
            case .equipmentTrunk, .lunarVault, .meteorCrate,
                 .crystalBarricade, .artifactVault, .stormVault, .crownVault,
                 .polarVault, .trenchVault: (0.24, 0.075)
            case .oxygenPod: (0.17, 0.072)
            }
        case .powerUp:
            (0.16, 0.060)
        case .volatileCore:
            (0.15, 0.055)
        }
        let bossScale = CampaignBalance.bossScale(tier: target.bossTier)
        return (
            min(0.40, dimensions.width * bossScale),
            min(0.14, dimensions.height * bossScale)
        )
    }

    private func spawnProjectile(
        x: Double,
        y: Double = 0.17,
        velocityX: Double,
        damage: Double,
        pierce: Int,
        hostile: Bool,
        critical: Bool,
        temporaryAbility: TemporaryBallAbility? = nil,
        endlessEffects: Set<TemporaryBallAbility> = [],
        canSplit: Bool = true
    ) {
        if hostile {
            let maximumHostileProjectiles = if mode.isEndless {
                EndlessRules.maximumHostileProjectiles(wave: snapshot.wave)
            } else if let level {
                CampaignBalance.maximumHostileProjectiles(
                    wave: snapshot.wave,
                    for: level
                )
            } else {
                Int.max
            }
            if snapshot.projectiles.count(where: \.hostile)
                >= maximumHostileProjectiles {
                return
            }
        }
        let speed = hostile
            ? (assistMode ? -0.30 : -0.38) * activeHostileProjectileSpeedMultiplier
            : stats.ballSpeed
        var effects = endlessEffects
        if let temporaryAbility {
            effects.insert(temporaryAbility)
        }
        let ringReturnPasses = if effects.contains(.ringReturn) {
            mode.isEndless
                ? EndlessSpecialBallRules.ringReturnPasses(
                    rank: specialBallRank(.ringReturn)
                )
                : 1
        } else {
            0
        }
        let returnDamage: Double? = if effects.contains(.ringReturn) {
            damage * (mode.isEndless
                ? EndlessSpecialBallRules.ringReturnDamageMultiplier(
                    rank: specialBallRank(.ringReturn)
                )
                : 1)
        } else {
            nil
        }
        snapshot.projectiles.append(ProjectileState(
            id: identifier(),
            position: .init(x: x, y: y),
            velocity: .init(x: velocityX, y: speed),
            damage: damage,
            remainingPierces: pierce,
            hostile: hostile,
            isCritical: critical,
            temporaryAbility: temporaryAbility,
            canSplit: canSplit,
            endlessEffects: endlessEffects,
            orbitChainsRemaining: effects.contains(.orbitShot)
                ? 3
                : ringReturnPasses,
            ringReturnDamage: returnDamage
        ))
    }

    private func awardReward(for target: TargetState, events: inout [SimulationEvent]) {
        switch target.kind {
        case .enemy(let enemy):
            let baseValue = target.bossTier == .megaBoss
                ? CombatBalance.tokenValue(enemy)
                : target.bossTier == .miniBoss
                    ? CombatBalance.tokenValue(enemy) * 5
                    : CombatBalance.tokenValue(enemy)
            if target.waveRole == .reinforcement {
                awardScore(baseValue: baseValue)
            } else {
                awardTokens(baseValue, at: target.position, events: &events)
            }
        case .fieldObject(.waterCooler), .fieldObject(.oxygenPod), .fieldObject(.gravityCell),
             .fieldObject(.cloudCondenser), .fieldObject(.thermalPod),
             .fieldObject(.cryoCanister), .fieldObject(.oxygenBell):
            let amount = min(24, snapshot.maxStamina - snapshot.stamina)
            snapshot.stamina += amount
            events.append(.heal(amount, target.position))
        case .fieldObject(.equipmentTrunk), .fieldObject(.artifactVault), .fieldObject(.lunarVault),
             .fieldObject(.stormVault), .fieldObject(.crownVault),
             .fieldObject(.polarVault), .fieldObject(.trenchVault):
            awardTokens(35, at: target.position, events: &events)
        case .fieldObject(.ballCart), .fieldObject(.meteorCrate), .fieldObject(.roverBattery),
             .fieldObject(.pressureCell), .fieldObject(.ringShardCrate),
             .fieldObject(.magneticCoil), .fieldObject(.stormBattery):
            awardTokens(18, at: target.position, events: &events)
        case .fieldObject:
            awardTokens(8, at: target.position, events: &events)
        case .powerUp(let ability):
            activateTemporaryAbility(ability)
            events.append(.temporaryAbilityActivated(
                ability,
                snapshot.temporaryAbilityDuration,
                target.position
            ))
        case .volatileCore:
            break
        }
    }

    private func awardTokens(
        _ baseValue: Int,
        at position: Vector2,
        awardsScore: Bool = true,
        events: inout [SimulationEvent]
    ) {
        let value = EconomyBalance.tokenReward(
            baseValue: baseValue,
            isEndless: mode.isEndless,
            wave: snapshot.wave,
            goldenGoalRank: abilities[.goldenGoal, default: 0],
            playerMultiplier: stats.tokenMultiplier
        )
        snapshot.tokens += value
        if awardsScore {
            awardScore(baseValue: baseValue)
        }
        events.append(.reward(value, position))
    }

    private func awardScore(baseValue: Int) {
        let comboBonus = 1 + min(1.0, Double(comboCount) * 0.1)
        snapshot.score += Int((Double(baseValue * 100 * max(1, snapshot.wave)) * comboBonus).rounded())
    }

    private var activeDamageMultiplier: Double {
        if mode.isEndless {
            return EndlessRules.damageMultiplier(
                wave: snapshot.wave,
                startingSurvivalFactor: EndlessRules
                    .startingSurvivalFactor(stats: stats)
            )
        }
        guard let level else { return 1 }
        return CampaignBalance.wave(snapshot.wave, for: level).damageMultiplier
    }

    private var activeSpeedMultiplier: Double {
        if mode.isEndless { return EndlessRules.speedMultiplier(wave: snapshot.wave) }
        guard let level else { return 1 }
        return CampaignBalance.wave(snapshot.wave, for: level).speedMultiplier
    }

    private var activeAttackCadenceMultiplier: Double {
        if mode.isEndless {
            return EndlessRules.attackCadenceMultiplier(wave: snapshot.wave)
        }
        guard let level else { return 1 }
        return CampaignBalance.attackCadenceMultiplier(
            level: level,
            wave: snapshot.wave
        )
    }

    private var activeHostileProjectileSpeedMultiplier: Double {
        if mode.isEndless {
            return EndlessRules.hostileProjectileSpeedMultiplier(
                wave: snapshot.wave
            )
        }
        guard let level else { return 1 }
        return CampaignBalance.hostileProjectileSpeedMultiplier(
            level: level,
            wave: snapshot.wave
        )
    }

    private var activeHealthMultiplier: Double {
        if mode.isEndless {
            return EndlessRules.healthMultiplier(
                wave: snapshot.wave,
                startingOffenseFactor: EndlessRules
                    .startingOffenseFactor(stats: stats)
            )
        }
        guard let level else { return 1 }
        return CampaignBalance.wave(snapshot.wave, for: level).healthMultiplier
    }

    private var endlessEnemyPool: [EnemyKind] {
        EndlessRules.enemyPool(wave: snapshot.wave)
    }

    private var endlessObjectPool: [FieldObjectKind] {
        GameContent.world(world).endlessObjects
    }

    private func reinforcements(for phase: Int) -> [EnemyKind] {
        if let level {
            let count = CampaignBalance.reinforcementPulseSize(levelNumber: level.number)
            return (0..<count).map { _ in
                level.enemies[Int(random.next() % UInt64(level.enemies.count))]
            }
        }
        let count = min(4, 2 + max(0, snapshot.wave - 1) / 10)
        let pool = GameContent.world(world).endlessEnemies
        let ordered = phase == 2
            ? pool
            : Array(pool.dropFirst(2)) + Array(pool.prefix(2))
        return Array(ordered.prefix(count))
    }

    private func configureWaveObjective() {
        if let level {
            let wave = CampaignBalance.wave(snapshot.wave, for: level)
            snapshot.isBossWave = wave.isBossWave
            snapshot.waveEnemyQuota = wave.enemyQuota
        } else {
            snapshot.isBossWave = EndlessRules.isBossWave(snapshot.wave)
            snapshot.waveEnemyQuota = snapshot.isBossWave
                ? 1
                : EndlessRules.enemyQuota(wave: snapshot.wave)
        }
        snapshot.waveDefeats = 0
    }

    private func resetWaveRuntime() {
        snapshot.waveElapsed = 0
        snapshot.bossHazards.removeAll()
        snapshot.galeBounces.removeAll()
        snapshot.galeInterceptors.removeAll()
        snapshot.haloRings.removeAll()
        snapshot.magneticTraps.removeAll()
        snapshot.tidalWaves.removeAll()
        timeBreakRemaining = 0
        timeBreakTargetIDs.removeAll(keepingCapacity: true)
        galeLandingHitCounts.removeAll(keepingCapacity: true)
        configureWaveObjective()
        spawnClock = 0
        pendingCampaignEnemySpawns = 0
        campaignEnemyStaggerClock = 0
        bossSpawned = false
        bossDefeated = false
        bossPhase = 1
        bossPowerUpClock = 7
        bossSignatureClock = 6 * activeAttackCadenceMultiplier
        pendingReinforcementPhases.removeAll(keepingCapacity: true)
        reinforcementQuietClock = 0
        bossSupportSpawnClock = 1.5
        endlessInitialBossSupportSpawned = false
        endlessBossReinforcementsWereActive = false
        pendingMeteorMarkers = 0
        meteorMarkerClock = 0
        shockwaveBurstsRemaining = 0
        shockwaveBurstClock = 0
        powerUpSpawned = false
        scheduleWavePowerUp()
    }

    private func resetWorldRuntime() {
        worldEffectElapsed = 0
        nextLunarEffectTime = 10 * activeAttackCadenceMultiplier
        pendingLunarDebrisStrikes = 0
        lunarDebrisClock = 0
        marsDefeatCount = 0
        pendingVolatileCorePositions.removeAll(keepingCapacity: true)
    }

    private func scheduleWavePowerUp() {
        nextPowerUpDefeat = max(1, snapshot.waveEnemyQuota / 2)
    }

    private func damageFlavor(
        for effects: Set<TemporaryBallAbility>
    ) -> DamageFlavor {
        if effects.contains(.explosive) || effects.contains(.gravityWell) {
            return .explosive
        }
        if effects.contains(.fire) { return .fire }
        if effects.contains(.ice) { return .ice }
        if effects.contains(.reverse) { return .reverse }
        if effects.contains(.split) { return .split }
        if effects.contains(.volt) || effects.contains(.polarLink) {
            return .volt
        }
        if effects.contains(.undertow) { return .ice }
        return .standard
    }

    private func impactEvent(
        for target: TargetState,
        damage: Double,
        flavor: DamageFlavor,
        critical: Bool,
        delivery: ImpactDelivery,
        impulse: Vector2
    ) -> SimulationEvent {
        let length = hypot(impulse.x, impulse.y)
        let normalizedImpulse: Vector2
        if delivery == .damageOverTime {
            normalizedImpulse = .init(x: 0, y: 0)
        } else if length > 0.0001 {
            normalizedImpulse = .init(x: impulse.x / length, y: impulse.y / length)
        } else {
            normalizedImpulse = .init(x: 0, y: 1)
        }
        return .impact(ImpactEvent(
            targetID: target.id,
            position: target.position,
            impulse: normalizedImpulse,
            damage: damage,
            flavor: flavor,
            isCritical: critical,
            isDefeating: target.hitPoints <= 0,
            delivery: delivery
        ))
    }

    private func randomSpawnX(near y: Double) -> Double {
        let lowerBound = -0.76
        let upperBound = 0.76
        let nearby = snapshot.targets.filter { abs($0.position.y - y) < 0.16 }
        var bestCandidate = lowerBound + random.unit() * (upperBound - lowerBound)
        var bestClearance = nearby.map { abs($0.position.x - bestCandidate) }.min() ?? .greatestFiniteMagnitude

        for _ in 0..<7 {
            let candidate = lowerBound + random.unit() * (upperBound - lowerBound)
            let clearance = nearby.map { abs($0.position.x - candidate) }.min() ?? .greatestFiniteMagnitude
            if clearance >= 0.24 {
                return candidate
            }
            if clearance > bestClearance {
                bestCandidate = candidate
                bestClearance = clearance
            }
        }
        return bestCandidate
    }

    private func identifier() -> Int { defer { nextIdentifier += 1 }; return nextIdentifier }

    private func isRanged(_ kind: EnemyKind) -> Bool {
        switch kind {
        case .ballLauncher, .gravityStriker, .plasmaStriker, .boltStriker,
             .shardStriker, .magnetStriker, .pressureStriker:
            true
        default:
            false
        }
    }

    private func enemySpeed(_ kind: EnemyKind) -> Double {
        switch kind {
        case .coneRunner, .regolithRunner, .dustSprite, .cloudRunner, .ringRunner,
             .frostSprinter, .mistRunner: 0.105
        case .dummyDefender, .eclipseKeeper, .roverRaider, .pressureBrute,
             .iceMason, .tiltBrute, .currentBrute: 0.075
        case .tackleBot, .lunarHopper, .craterCrawler, .vortexSkimmer,
             .shepherdDrone, .auroraDrifter, .squallRay: 0.13
        case .keeperDrone, .orbitDrone, .saucerKeeper, .stormKeeper,
             .haloKeeper, .polarKeeper, .tridentKeeper: 0.06
        case .ballLauncher, .gravityStriker, .plasmaStriker, .boltStriker,
             .shardStriker, .magnetStriker, .pressureStriker: 0.05
        case .titanKeeper, .lunarWarden, .marsColossus, .tempestRegent,
             .crownSovereign, .axisPrime, .abyssalMonarch: 0
        }
    }

    private func contactDamage(_ kind: EnemyKind) -> Double {
        switch kind {
        case .coneRunner, .regolithRunner, .dustSprite, .cloudRunner, .ringRunner,
             .frostSprinter, .mistRunner: 9
        case .titanKeeper, .lunarWarden, .marsColossus, .tempestRegent,
             .crownSovereign, .axisPrime, .abyssalMonarch: 22
        default: 14
        }
    }

}
