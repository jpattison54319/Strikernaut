import Foundation

final class GameSimulation {
    private(set) var snapshot: SimulationSnapshot
    private let mode: RunMode
    private let level: LevelDefinition?
    private let stats: PlayerStats
    private let character: CharacterDefinition
    private let assistMode: Bool
    private var random: SeededGenerator
    private var targetPlayerX = 0.0
    private var spawnClock = 0.0
    private var kickClock = 0.0
    private var nextIdentifier = 1
    private var abilities: [AbilityKind: Int] = [:]
    private var specialBallRanks: [TemporaryBallAbility: Int] = [:]
    private var finished = false
    private var bossSpawned = false
    private var bossDefeated = false
    private var bossPhase = 1
    private var powerUpSpawned = false
    private var nextPowerUpDefeat = 0
    private var bossPowerUpClock = 7.0
    private var bossSignatureClock = 6.0
    private var pendingReinforcementPhases: [Int] = []
    private var reinforcementQuietClock = 0.0
    private var hadActiveReinforcements = false
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
    private var world: WorldID { snapshot.world }

    convenience init(level: LevelDefinition, progress: PlayerProgress, assistMode: Bool, seed: UInt64) {
        self.init(mode: .campaign(level: level.number), progress: progress, assistMode: assistMode, seed: seed)
    }

    init(mode: RunMode, progress: PlayerProgress, assistMode: Bool, seed: UInt64) {
        self.mode = mode
        self.level = mode.campaignLevel.map(GameContent.level)
        self.stats = PlayerStats(progress: progress)
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
            bossHazards: [],
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
    }

    func setPlayerTarget(x: Double) {
        targetPlayerX = min(0.92, max(-0.92, x))
    }

    func apply(_ ability: AbilityKind) {
        let maximum = mode.isEndless ? Int.max : 3
        let newRank = min(maximum, abilities[ability, default: 0] + 1)
        abilities[ability] = newRank
        if ability == .cleanSheet {
            snapshot.shieldCharges += 1
        }
        if ability == .secondWind {
            snapshot.stamina = min(snapshot.maxStamina, snapshot.stamina + 10 + Double(newRank) * 4)
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
        snapshot.characterAbilityCharge = 100
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

    func spawnFriendlyProjectileForTesting(
        pierce: Int,
        temporaryAbility: TemporaryBallAbility? = nil
    ) {
        spawnProjectile(
            x: snapshot.playerX,
            velocityX: 0,
            damage: stats.ballDamage,
            pierce: pierce,
            hostile: false,
            critical: false,
            temporaryAbility: temporaryAbility
        )
    }

    func spawnHostileProjectileForTesting(x: Double, y: Double) {
        spawnProjectile(
            x: x,
            y: y,
            velocityX: 0,
            damage: 10,
            pierce: 0,
            hostile: true,
            critical: false
        )
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
            for index in snapshot.targets.indices {
                guard !isPowerUp(snapshot.targets[index]) else { continue }
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

    private func spawnMeteorVolley() {
        let targets = snapshot.targets
            .filter { !isPowerUp($0) }
            .sorted { $0.position.y < $1.position.y }
            .prefix(7)
        let destinations: [(position: Vector2, targetID: Int?)]
        if targets.isEmpty {
            destinations = [-0.58, 0, 0.58].map {
                (.init(x: $0, y: 0.52), nil)
            }
        } else {
            destinations = targets.map { ($0.position, Optional($0.id)) }
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
                delayRemaining: Double(index) * 0.11,
                elapsed: 0,
                duration: 0.92,
                width: 0.86
            ))
        }
    }

    private func spawnShockwaveBurst() -> SimulationEvent {
        let origin = Vector2(x: snapshot.playerX, y: 0.18)
        snapshot.characterAttacks.append(CharacterAttackState(
            id: identifier(),
            kind: .shockwave,
            position: origin,
            startPosition: origin,
            destination: .init(x: origin.x, y: 1.08),
            targetID: nil,
            damage: stats.ballDamage * 0.80,
            delayRemaining: 0,
            elapsed: 0,
            duration: 0.90,
            width: 0.18
        ))
        return .characterShockwaveBurst(origin)
    }

    private func updateCharacterAttackSchedule(delta: Double, events: inout [SimulationEvent]) {
        guard shockwaveBurstsRemaining > 0 else { return }
        shockwaveBurstClock -= delta
        if shockwaveBurstClock <= 0 {
            shockwaveBurstsRemaining -= 1
            shockwaveBurstClock += 0.30
            events.append(spawnShockwaveBurst())
        }
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
        snapshot.elapsed += delta
        snapshot.waveElapsed += delta
        updateTemporaryAbility(delta: delta)
        updateWorldEffect(delta: delta, events: &events)
        updatePlayer(delta: delta)
        updateCharacterAttackSchedule(delta: delta, events: &events)
        updateSpawning(delta: delta)
        updateBossSupport(delta: delta)
        updatePowerUpSpawning(delta: delta)
        updateBossAttackSchedule(delta: delta, events: &events)
        updateBossHazards(delta: delta, events: &events)
        updateKicking(delta: delta, events: &events)
        updateTargets(delta: delta, events: &events)
        if finishBossWaveIfNeeded(events: &events) { return events }
        updateCharacterAttacks(delta: delta, events: &events)
        if finishBossWaveIfNeeded(events: &events) { return events }
        updateProjectiles(delta: delta, events: &events)
        if finishBossWaveIfNeeded(events: &events) { return events }
        spawnPendingVolatileCores(events: &events)
        evaluateWave(events: &events)
        evaluateFinish(events: &events)
        return events
    }

    private func updatePlayer(delta: Double) {
        let difference = targetPlayerX - snapshot.playerX
        snapshot.playerX += difference * min(1, stats.movementResponse * delta)
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
        guard world == .moon else { return }
        worldEffectElapsed += delta

        if pendingLunarDebrisStrikes > 0 {
            lunarDebrisClock -= delta
            if lunarDebrisClock <= 0 {
                pendingLunarDebrisStrikes -= 1
                appendLunarDebris(events: &events)
            }
        }

        if worldEffectElapsed >= nextLunarEffectTime {
            nextLunarEffectTime += 16
            appendLunarDebris(events: &events)
            pendingLunarDebrisStrikes += 1
            lunarDebrisClock = 3
        }
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
                world: world
              ) else { return }
        spawnClock += delta
        guard spawnClock >= wave.spawnInterval else { return }
        spawnClock -= wave.spawnInterval
        let enemy = level.enemies[Int(random.next() % UInt64(level.enemies.count))]
        spawnEnemy(enemy, x: randomSpawnX(near: 1.04), y: 1.04, role: .quota)
        if random.unit() < 0.12, let object = level.objects.randomElement(using: &random) {
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
        guard snapshot.isBossWave else { return }
        let hasActiveReinforcements = snapshot.targets.contains {
            if case .enemy = $0.kind { $0.waveRole == .reinforcement } else { false }
        }
        if hadActiveReinforcements && !hasActiveReinforcements {
            reinforcementQuietClock = max(reinforcementQuietClock, 3)
        }
        hadActiveReinforcements = hasActiveReinforcements
        if reinforcementQuietClock > 0 {
            reinforcementQuietClock = max(0, reinforcementQuietClock - delta)
        }
        guard !hasActiveReinforcements,
              reinforcementQuietClock == 0,
              !pendingReinforcementPhases.isEmpty else { return }
        let phase = pendingReinforcementPhases.removeFirst()
        let pulse = reinforcements(for: phase)
        for (index, kind) in pulse.enumerated() {
            let offset = Double(index) - Double(max(0, pulse.count - 1)) / 2
            spawnEnemy(
                kind,
                x: min(0.72, max(-0.72, offset * 0.34)),
                y: 0.88 + Double(index % 2) * 0.06,
                role: .reinforcement
            )
        }
        hadActiveReinforcements = true
    }

    private func updateBossAttackSchedule(delta: Double, events: inout [SimulationEvent]) {
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
            bossSignatureClock = 10
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
            bossSignatureClock = 11
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
            bossSignatureClock = 10
        }
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
        guard !snapshot.bossHazards.isEmpty else { return }
        for index in snapshot.bossHazards.indices {
            var hazard = snapshot.bossHazards[index]
            if hazard.telegraphRemaining > 0 {
                let previous = hazard.telegraphRemaining
                hazard.telegraphRemaining = max(0, previous - delta)
                if previous > 0, hazard.telegraphRemaining == 0 {
                    if hazard.kind == .lunarDebris {
                        events.append(.worldEffectImpact(.lunarCycle, hazard.position))
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

        let powerBase = mode.isEndless ? 1.25 : 1.35
        var baseDamage = stats.ballDamage * pow(powerBase, Double(abilities[.powerDrive, default: 0]))
        baseDamage *= quickReleaseDamageMultiplier(atAbilityRank: quickRank)
        let meteorRank = abilities[.meteorStrike, default: 0]
        let meteorInterval = max(2, 7 - min(meteorRank, 5))
        let isMeteor = meteorRank > 0 && kickCount.isMultiple(of: meteorInterval)
        if isMeteor {
            baseDamage *= 1 + Double(meteorRank) * 0.55
            events.append(.meteorKick)
        }

        let criticalPower = max(0, stats.criticalChance)
        let guaranteedCriticalTiers = Int(criticalPower.rounded(.down))
        let fractionalCriticalTier = random.unit() < criticalPower.truncatingRemainder(dividingBy: 1) ? 1 : 0
        let criticalTiers = max(isMeteor ? 1 : 0, guaranteedCriticalTiers + fractionalCriticalTier)
        let critical = criticalTiers > 0
        let damage = baseDamage * Double(1 + criticalTiers)
        let temporaryAbility = if mode.isEndless {
            EndlessSpecialBallRules.selectedAbility(
                ranks: specialBallRanks,
                roll: random.unit()
            )
        } else {
            snapshot.activeTemporaryAbility
        }
        let pierce = temporaryAbility == .solarPierce
            ? Int.max
            : abilities[.throughBall, default: 0] + stats.extraPierce
        spawnProjectile(
            x: snapshot.playerX,
            velocityX: 0,
            damage: damage,
            pierce: pierce,
            hostile: false,
            critical: critical,
            temporaryAbility: temporaryAbility
        )
        spawnVolley(
            rank: abilities[.oneTwo, default: 0],
            damage: damage,
            pierce: pierce,
            critical: critical,
            temporaryAbility: temporaryAbility
        )
        events.append(.kick)
    }

    private func spawnVolley(
        rank: Int,
        damage: Double,
        pierce: Int,
        critical: Bool,
        temporaryAbility: TemporaryBallAbility?
    ) {
        guard rank > 0 else { return }
        let mastery = 1 + Double(max(0, rank - 3)) * 0.12
        switch rank {
        case 1:
            spawnSpreadBall(
                horizontalSpeed: kickCount.isMultiple(of: 2) ? -0.34 : 0.34,
                damage: damage * 0.70,
                pierce: pierce,
                critical: critical,
                temporaryAbility: temporaryAbility
            )
        case 2:
            spawnSpreadPair(horizontalSpeed: 0.46, damage: damage * 0.74, pierce: pierce, critical: critical, temporaryAbility: temporaryAbility)
        default:
            spawnSpreadPair(horizontalSpeed: 0.38, damage: damage * 0.76 * mastery, pierce: pierce, critical: critical, temporaryAbility: temporaryAbility)
            spawnSpreadBall(
                horizontalSpeed: kickCount.isMultiple(of: 2) ? -0.62 : 0.62,
                damage: damage * 0.68 * mastery,
                pierce: pierce,
                critical: critical,
                temporaryAbility: temporaryAbility
            )
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
            target.phase += delta

            target.freezeRemaining = max(0, target.freezeRemaining - delta)
            target.reverseRemaining = max(0, target.reverseRemaining - delta)
            target.stunRemaining = max(0, target.stunRemaining - delta)
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

            let freezeFactor = target.freezeRemaining > 0 || target.stunRemaining > 0 ? 0 : 1.0
            let direction = target.reverseRemaining > 0 ? -1.0 : 1.0
            switch target.kind {
            case .enemy(let kind):
                if target.bossTier != .standard {
                    let movementRate = CampaignBalance.bossMovementRate(tier: target.bossTier)
                    let amplitude = target.bossTier == .megaBoss ? 0.68 : 0.58
                    target.position.x = sin(target.phase * movementRate * direction) * amplitude * freezeFactor
                    let healthRatio = target.hitPoints / target.maximumHitPoints
                    let newPhase = healthRatio > 0.66 ? 1 : (healthRatio > 0.33 ? 2 : 3)
                    if newPhase > bossPhase {
                        let crossedPhases = (bossPhase + 1)...newPhase
                        bossPhase = newPhase
                        for crossedPhase in crossedPhases {
                            events.append(.bossPhase(crossedPhase))
                            pendingReinforcementPhases.append(crossedPhase)
                            if world == .mars {
                                pendingVolatileCorePositions.append(target.position)
                            }
                        }
                    }
                    let attackInterval = max(0.90, 2.3 - Double(bossPhase) * 0.3)
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
                    target.position.y -= enemySpeed(kind) * activeSpeedMultiplier * slowFactor * freezeFactor * direction * delta
                    if kind == .tackleBot || kind == .craterCrawler || kind == .lunarHopper {
                        target.position.x += sin(target.phase * 5.2) * delta * 0.23 * direction * freezeFactor
                    }
                    if freezeFactor > 0,
                       isRanged(kind),
                       target.phase.truncatingRemainder(dividingBy: 3.0) < delta,
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
                target.position.y -= 0.11 * activeSpeedMultiplier * slowFactor * delta
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
            snapshot.targets[index] = target
        }
        if !removedTargetIDs.isEmpty {
            snapshot.targets.removeAll { removedTargetIDs.contains($0.id) }
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
            snapshot.targets[index].hitPoints -= damage
            events.append(impactEvent(
                for: snapshot.targets[index],
                damage: damage,
                flavor: .explosive,
                critical: true,
                delivery: .area,
                impulse: .init(
                    x: target.position.x - attack.destination.x,
                    y: target.position.y - attack.destination.y
                )
            ))
            registerDefeatIfNeeded(at: index, awardsAbilityCharge: false, events: &events)
        }
    }

    private func applyShockwaveHits(
        _ attack: inout CharacterAttackState,
        events: inout [SimulationEvent]
    ) {
        let halfWidth = attack.width * 0.5
        for index in snapshot.targets.indices {
            let target = snapshot.targets[index]
            guard !isPowerUp(target),
                  !hitTargetIDs.contains(target.id),
                  !attack.contactedTargetIDs.contains(target.id),
                  abs(target.position.y - attack.position.y) <= 0.075,
                  abs(target.position.x - attack.position.x) <= halfWidth else { continue }
            attack.contactedTargetIDs.insert(target.id)
            snapshot.targets[index].hitPoints -= attack.damage
            snapshot.targets[index].stunRemaining = max(snapshot.targets[index].stunRemaining, 0.78)
            events.append(.characterShockwaveHit(target.position))
            events.append(impactEvent(
                for: snapshot.targets[index],
                damage: attack.damage,
                flavor: .standard,
                critical: false,
                delivery: .area,
                impulse: .init(
                    x: target.position.x - attack.position.x,
                    y: 0.3
                )
            ))
            registerDefeatIfNeeded(at: index, awardsAbilityCharge: false, events: &events)
        }
    }

    private func updateProjectiles(delta: Double, events: inout [SimulationEvent]) {
        removedProjectileIDs.removeAll(keepingCapacity: true)
        hitTargetIDs.removeAll(keepingCapacity: true)
        var splitProjectiles: [ProjectileState] = []
        for projectileIndex in snapshot.projectiles.indices {
            var projectile = snapshot.projectiles[projectileIndex]
            if projectile.temporaryAbility == .heatSeeking,
               let nearest = nearestHeatSeekingTarget(for: projectile) {
                steerHeatSeekingProjectile(&projectile, toward: nearest.position, delta: delta)
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
                        delta: delta
                    )
                }
            }
            projectile.position.x += projectile.velocity.x * delta
            projectile.position.y += projectile.velocity.y * delta
            if projectile.characterProjectile == .pinballBlitz {
                projectile.remainingLifetime -= delta
                let lateralLimit = 0.88
                if projectile.position.x <= -lateralLimit || projectile.position.x >= lateralLimit {
                    projectile.position.x = min(lateralLimit, max(-lateralLimit, projectile.position.x))
                    projectile.velocity.x = abs(projectile.velocity.x) * (projectile.position.x < 0 ? 1 : -1)
                    events.append(.characterProjectileRicochet(projectile.position))
                }
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
                    let hitEnemy = if case .enemy = snapshot.targets[targetIndex].kind {
                        true
                    } else {
                        false
                    }
                    applyProjectileHit(projectile, to: targetIndex, events: &events)
                    if projectile.temporaryAbility == .volt,
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
                    if projectile.temporaryAbility == .explosive {
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
                    if projectile.temporaryAbility == .split, projectile.canSplit {
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
                    } else if projectile.temporaryAbility == .orbitShot,
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
                        }
                    } else if projectile.remainingPierces > 0 {
                        projectile.contactedTargetIDs.insert(targetID)
                        projectile.remainingPierces -= 1
                    } else {
                        removedProjectileIDs.insert(projectile.id)
                    }
                }
                if projectile.remainingLifetime <= 0
                    || projectile.position.y > 1.12
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

        let flavor = damageFlavor(for: projectile.temporaryAbility)
        snapshot.targets[targetIndex].hitPoints -= projectile.damage
        switch projectile.temporaryAbility {
        case .fire:
            if snapshot.targets[targetIndex].freezeRemaining > 0 {
                snapshot.targets[targetIndex].freezeRemaining = 0
                events.append(.elementalReaction(snapshot.targets[targetIndex].position))
            }
            let fireRank = specialBallRank(.fire)
            let duration = mode.isEndless
                ? EndlessSpecialBallRules.fireDuration(rank: fireRank)
                : 4
            let tickDamage = mode.isEndless
                ? projectile.damage
                    * EndlessSpecialBallRules.fireTickDamageMultiplier(rank: fireRank)
                : stats.ballDamage * 0.18
            snapshot.targets[targetIndex].burnRemaining = max(
                snapshot.targets[targetIndex].burnRemaining,
                duration
            )
            snapshot.targets[targetIndex].burnTickClock = min(snapshot.targets[targetIndex].burnTickClock, 0.18)
            snapshot.targets[targetIndex].burnTickDamage = max(
                snapshot.targets[targetIndex].burnTickDamage,
                tickDamage
            )
        case .ice:
            if snapshot.targets[targetIndex].burnRemaining > 0 {
                snapshot.targets[targetIndex].burnRemaining = 0
                snapshot.targets[targetIndex].burnTickClock = 0
                snapshot.targets[targetIndex].burnTickDamage = 0
                events.append(.elementalReaction(snapshot.targets[targetIndex].position))
            }
            let duration = mode.isEndless
                ? EndlessSpecialBallRules.iceDuration(rank: specialBallRank(.ice))
                : 1.7
            snapshot.targets[targetIndex].freezeRemaining = max(
                snapshot.targets[targetIndex].freezeRemaining,
                duration
            )
        case .reverse:
            let duration = mode.isEndless
                ? EndlessSpecialBallRules.reverseDuration(rank: specialBallRank(.reverse))
                : 2.8
            snapshot.targets[targetIndex].reverseRemaining = max(
                snapshot.targets[targetIndex].reverseRemaining,
                duration
            )
        default:
            break
        }
        events.append(impactEvent(
            for: snapshot.targets[targetIndex],
            damage: projectile.damage,
            flavor: flavor,
            critical: projectile.isCritical,
            delivery: .direct,
            impulse: projectile.velocity
        ))
        registerDefeatIfNeeded(
            at: targetIndex,
            awardsAbilityCharge: projectile.characterProjectile == nil,
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
            snapshot.targets[index].hitPoints -= damage
            events.append(impactEvent(
                for: snapshot.targets[index],
                damage: damage,
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
            let damageMultiplier = mode.isEndless
                ? EndlessSpecialBallRules.voltDamageMultiplier(
                    recipientOffset: offset,
                    rank: specialBallRank(.volt)
                )
                : 0.15 + Double(offset) * 0.05
            let damage = projectileDamage * damageMultiplier
            snapshot.targets[targetIndex].hitPoints -= damage
            let generation = Int(log2(Double(recipientOrder)).rounded(.down)) + 1
            arcs.append(VoltArc(
                source: nodePositions[parentOrder],
                targetID: target.id,
                destination: target.position,
                generation: generation,
                recipientOrder: recipientOrder,
                damage: damage,
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
        registerDefeat(target, awardsAbilityCharge: awardsAbilityCharge, events: &events)
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
            let tokenBonus = max(4, completedWave * 2)
            snapshot.tokens += tokenBonus
            events.append(.reward(tokenBonus, .init(x: snapshot.playerX, y: 0.16)))
        }

        let recoveryRank = abilities[.secondWind, default: 0]
        if recoveryRank > 0 {
            let amount = min(snapshot.maxStamina - snapshot.stamina, 4 + Double(recoveryRank) * 3)
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
        snapshot.bossHazards.removeAll()
        pendingVolatileCorePositions.removeAll(keepingCapacity: true)
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
        if snapshot.stamina <= 0 {
            finished = true
            events.append(.finished(false))
            return
        }
        guard level != nil else { return }
    }

    private func finishBossWaveIfNeeded(events: inout [SimulationEvent]) -> Bool {
        guard snapshot.isBossWave, bossDefeated else { return false }
        completeWave(events: &events)
        return true
    }

    private func applyDamage(_ amount: Double, events: inout [SimulationEvent]) {
        if snapshot.shieldCharges > 0 {
            snapshot.shieldCharges -= 1
        } else {
            let previousStamina = snapshot.stamina
            snapshot.stamina = max(0, snapshot.stamina - amount)
            if snapshot.stamina < previousStamina, comboCount > 0 {
                comboCount = 0
                snapshot.combo = 0
                snapshot.comboFraction = 0
                events.append(.comboChanged(0))
            }
        }
        events.append(.damage)
    }

    private func registerDefeat(
        _ target: TargetState,
        awardsAbilityCharge: Bool = true,
        events: inout [SimulationEvent]
    ) {
        comboCount += 1
        snapshot.combo = comboCount
        snapshot.comboFraction = 1
        snapshot.bestCombo = max(snapshot.bestCombo, comboCount)
        snapshot.targetsDefeated += 1
        if awardsAbilityCharge {
            snapshot.characterAbilityCharge = min(100, snapshot.characterAbilityCharge + 20)
            snapshot.characterAbilityReady = snapshot.characterAbilityCharge >= 100
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
        var multiplier: Double
        if mode.isEndless {
            multiplier = EndlessRules.healthMultiplier(wave: snapshot.wave)
        } else {
            guard let level else { return }
            multiplier = tier == .megaBoss
                ? 1 + Double(level.number - 1) * 0.025
                : CampaignBalance.wave(snapshot.wave, for: level).healthMultiplier
        }
        let tierMultiplier = CampaignBalance.bossHealthMultiplier(
            tier: tier,
            wave: snapshot.wave,
            world: world
        )
        let hitPoints = enemyHealth(kind) * multiplier * tierMultiplier
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
        applyStatusEffectPreview(to: &target)
        snapshot.targets.append(target)
    }

    private func spawnObject(_ kind: FieldObjectKind, x: Double, y: Double) {
        let base: Double = switch kind {
        case .ballCart, .meteorCrate, .roverBattery: 18
        case .waterCooler, .oxygenPod, .gravityCell: 14
        case .tacticsBoard, .holoGate, .satelliteRelay: 35
        case .coneBarricade, .crystalBarricade, .regolithBarricade: 20
        case .equipmentTrunk, .artifactVault, .lunarVault: 55
        }
        let multiplier = mode.isEndless ? sqrt(EndlessRules.healthMultiplier(wave: snapshot.wave)) : 1
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
            case .coneRunner: (0.14, 0.055)
            case .dummyDefender, .regolithRunner, .dustSprite: (0.17, 0.058)
            case .tackleBot, .roverRaider: (0.19, 0.060)
            case .keeperDrone, .ballLauncher, .lunarHopper, .orbitDrone,
                 .eclipseKeeper, .gravityStriker, .saucerKeeper, .plasmaStriker: (0.21, 0.066)
            case .craterCrawler: (0.23, 0.058)
            case .titanKeeper, .lunarWarden, .marsColossus: (0.25, 0.078)
            }
        case .fieldObject(let object):
            switch object {
            case .waterCooler, .gravityCell: (0.15, 0.066)
            case .ballCart, .roverBattery, .tacticsBoard, .satelliteRelay: (0.19, 0.068)
            case .coneBarricade, .regolithBarricade, .holoGate: (0.25, 0.060)
            case .equipmentTrunk, .lunarVault, .meteorCrate,
                 .crystalBarricade, .artifactVault: (0.24, 0.075)
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
        canSplit: Bool = true
    ) {
        let speed = hostile ? (assistMode ? -0.30 : -0.38) : stats.ballSpeed
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
            orbitChainsRemaining: temporaryAbility == .orbitShot ? 3 : 0
        ))
    }

    private func spawnSpreadPair(
        horizontalSpeed: Double,
        damage: Double,
        pierce: Int,
        critical: Bool,
        temporaryAbility: TemporaryBallAbility?
    ) {
        spawnProjectile(
            x: snapshot.playerX - 0.025,
            velocityX: -horizontalSpeed,
            damage: damage,
            pierce: pierce,
            hostile: false,
            critical: critical,
            temporaryAbility: temporaryAbility
        )
        spawnProjectile(
            x: snapshot.playerX + 0.025,
            velocityX: horizontalSpeed,
            damage: damage,
            pierce: pierce,
            hostile: false,
            critical: critical,
            temporaryAbility: temporaryAbility
        )
    }

    private func spawnSpreadBall(
        horizontalSpeed: Double,
        damage: Double,
        pierce: Int,
        critical: Bool,
        temporaryAbility: TemporaryBallAbility?
    ) {
        spawnProjectile(
            x: snapshot.playerX,
            velocityX: horizontalSpeed,
            damage: damage,
            pierce: pierce,
            hostile: false,
            critical: critical,
            temporaryAbility: temporaryAbility
        )
    }

    private func awardReward(for target: TargetState, events: inout [SimulationEvent]) {
        switch target.kind {
        case .enemy(let enemy):
            let baseValue = target.bossTier == .megaBoss
                ? (world == .mars ? 180 : 150)
                : target.bossTier == .miniBoss
                    ? tokenValue(enemy) * 5
                    : tokenValue(enemy)
            awardTokens(baseValue, at: target.position, events: &events)
        case .fieldObject(.waterCooler), .fieldObject(.oxygenPod), .fieldObject(.gravityCell):
            let amount = min(24, snapshot.maxStamina - snapshot.stamina)
            snapshot.stamina += amount
            events.append(.heal(amount, target.position))
        case .fieldObject(.equipmentTrunk), .fieldObject(.artifactVault), .fieldObject(.lunarVault):
            awardTokens(35, at: target.position, events: &events)
        case .fieldObject(.ballCart), .fieldObject(.meteorCrate), .fieldObject(.roverBattery):
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

    private func awardTokens(_ baseValue: Int, at position: Vector2, events: inout [SimulationEvent]) {
        let goldenMultiplier = 1 + Double(abilities[.goldenGoal, default: 0]) * 0.15
        let waveMultiplier = mode.isEndless ? 1 + Double(max(0, snapshot.wave - 1) / 10) * 0.25 : 1
        let value = max(1, Int((Double(baseValue) * stats.tokenMultiplier * goldenMultiplier * waveMultiplier).rounded()))
        snapshot.tokens += value
        let comboBonus = 1 + min(1.0, Double(comboCount) * 0.1)
        snapshot.score += Int((Double(baseValue * 100 * max(1, snapshot.wave)) * comboBonus).rounded())
        events.append(.reward(value, position))
    }

    private var activeDamageMultiplier: Double {
        if mode.isEndless { return EndlessRules.damageMultiplier(wave: snapshot.wave) }
        guard let level else { return 1 }
        return CampaignBalance.wave(snapshot.wave, for: level).damageMultiplier
    }

    private var activeSpeedMultiplier: Double {
        if mode.isEndless { return EndlessRules.speedMultiplier(wave: snapshot.wave) }
        guard let level else { return 1 }
        return CampaignBalance.wave(snapshot.wave, for: level).speedMultiplier
    }

    private var activeHealthMultiplier: Double {
        if mode.isEndless { return EndlessRules.healthMultiplier(wave: snapshot.wave) }
        guard let level else { return 1 }
        return CampaignBalance.wave(snapshot.wave, for: level).healthMultiplier
    }

    private var endlessEnemyPool: [EnemyKind] {
        let ordered: [EnemyKind] = switch world {
        case .earth: [.coneRunner, .dummyDefender, .tackleBot, .keeperDrone, .ballLauncher]
        case .moon: [.regolithRunner, .lunarHopper, .orbitDrone, .eclipseKeeper, .gravityStriker]
        case .mars: [.dustSprite, .roverRaider, .craterCrawler, .saucerKeeper, .plasmaStriker]
        }
        let completedCircuits = EndlessRules.chapterIndex(for: snapshot.wave)
            / max(1, EndlessRules.worldSequence.count)
        let count = completedCircuits > 0
            ? ordered.count
            : min(ordered.count, 1 + (EndlessRules.waveInWorld(for: snapshot.wave) - 1) / 2)
        return Array(ordered.prefix(count))
    }

    private var endlessObjectPool: [FieldObjectKind] {
        return switch world {
        case .earth: [.ballCart, .waterCooler, .tacticsBoard, .coneBarricade, .equipmentTrunk]
        case .moon: [.roverBattery, .satelliteRelay, .regolithBarricade, .gravityCell, .lunarVault]
        case .mars: [.meteorCrate, .oxygenPod, .holoGate, .crystalBarricade, .artifactVault]
        }
    }

    private func reinforcements(for phase: Int) -> [EnemyKind] {
        if let level {
            let count = CampaignBalance.reinforcementPulseSize(levelNumber: level.number)
            return (0..<count).map { _ in
                level.enemies[Int(random.next() % UInt64(level.enemies.count))]
            }
        }
        let count = min(4, 2 + max(0, snapshot.wave - 1) / 10)
        let ordered: [EnemyKind] = switch world {
        case .earth: phase == 2
            ? [.coneRunner, .dummyDefender, .tackleBot, .keeperDrone]
            : [.tackleBot, .keeperDrone, .ballLauncher, .dummyDefender]
        case .moon: phase == 2
            ? [.regolithRunner, .lunarHopper, .orbitDrone, .eclipseKeeper]
            : [.lunarHopper, .eclipseKeeper, .gravityStriker, .orbitDrone]
        case .mars: phase == 2
            ? [.dustSprite, .roverRaider, .craterCrawler, .saucerKeeper]
            : [.craterCrawler, .saucerKeeper, .plasmaStriker, .roverRaider]
        }
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
        configureWaveObjective()
        spawnClock = 0
        bossSpawned = false
        bossDefeated = false
        bossPhase = 1
        bossPowerUpClock = 7
        bossSignatureClock = 6
        pendingReinforcementPhases.removeAll(keepingCapacity: true)
        reinforcementQuietClock = 0
        hadActiveReinforcements = false
        pendingMeteorMarkers = 0
        meteorMarkerClock = 0
        shockwaveBurstsRemaining = 0
        shockwaveBurstClock = 0
        powerUpSpawned = false
        scheduleWavePowerUp()
    }

    private func resetWorldRuntime() {
        worldEffectElapsed = 0
        nextLunarEffectTime = 10
        pendingLunarDebrisStrikes = 0
        lunarDebrisClock = 0
        marsDefeatCount = 0
        pendingVolatileCorePositions.removeAll(keepingCapacity: true)
    }

    private func scheduleWavePowerUp() {
        nextPowerUpDefeat = max(1, snapshot.waveEnemyQuota / 2)
    }

    private func damageFlavor(for ability: TemporaryBallAbility?) -> DamageFlavor {
        switch ability {
        case .explosive: .explosive
        case .fire: .fire
        case .ice: .ice
        case .reverse: .reverse
        case .split: .split
        case .volt: .volt
        case .rapidFire, .heatSeeking, .orbitShot, .solarPierce, nil: .standard
        }
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
        kind == .ballLauncher || kind == .gravityStriker || kind == .plasmaStriker
    }

    private func enemyHealth(_ kind: EnemyKind) -> Double {
        switch kind {
        case .coneRunner, .regolithRunner, .dustSprite: 10
        case .dummyDefender, .eclipseKeeper, .roverRaider: 24
        case .tackleBot, .lunarHopper, .craterCrawler: 18
        case .keeperDrone, .orbitDrone, .saucerKeeper: 42
        case .ballLauncher, .gravityStriker, .plasmaStriker: 28
        case .titanKeeper: 720
        case .lunarWarden: 820
        case .marsColossus: 900
        }
    }

    private func enemySpeed(_ kind: EnemyKind) -> Double {
        switch kind {
        case .coneRunner, .regolithRunner, .dustSprite: 0.105
        case .dummyDefender, .eclipseKeeper, .roverRaider: 0.075
        case .tackleBot, .lunarHopper, .craterCrawler: 0.13
        case .keeperDrone, .orbitDrone, .saucerKeeper: 0.06
        case .ballLauncher, .gravityStriker, .plasmaStriker: 0.05
        case .titanKeeper, .lunarWarden, .marsColossus: 0
        }
    }

    private func contactDamage(_ kind: EnemyKind) -> Double {
        switch kind {
        case .coneRunner, .regolithRunner, .dustSprite: 9
        case .titanKeeper, .lunarWarden, .marsColossus: 22
        default: 14
        }
    }

    private func tokenValue(_ kind: EnemyKind) -> Int {
        switch kind {
        case .coneRunner, .regolithRunner, .dustSprite: 2
        case .dummyDefender, .eclipseKeeper, .roverRaider: 4
        case .tackleBot, .lunarHopper, .craterCrawler: 5
        case .keeperDrone, .orbitDrone, .saucerKeeper: 7
        case .ballLauncher, .gravityStriker, .plasmaStriker: 8
        case .titanKeeper: 150
        case .lunarWarden: 165
        case .marsColossus: 180
        }
    }
}
