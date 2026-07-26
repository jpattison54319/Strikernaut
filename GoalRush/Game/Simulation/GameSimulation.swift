import Foundation

final class GameSimulation {
    private(set) var snapshot: SimulationSnapshot
    private let mode: RunMode
    private let level: LevelDefinition?
    private let world: WorldID
    private let stats: PlayerStats
    private let character: CharacterDefinition
    private let assistMode: Bool
    private var random: SeededGenerator
    private var targetPlayerX = 0.0
    private var spawnClock = 0.0
    private var kickClock = 0.0
    private var nextIdentifier = 1
    private var abilities: [AbilityKind: Int] = [:]
    private var finished = false
    private var bossSpawned = false
    private var campaignBossDefeated = false
    private var bossPhase = 1
    private var powerUpSpawned = false
    private var nextPowerUpTime = 0.0
    private var kickCount = 0
    static let comboWindow: Double = 3.0
    private static let comboMilestones: Set<Int> = [5, 10, 15, 25, 50, 100]
    private var comboCount = 0
    private var comboTimer = 0.0
    private var removedTargetIDs = Set<Int>()
    private var removedProjectileIDs = Set<Int>()
    private var hitTargetIDs = Set<Int>()
    private var statusEffectPreview: TemporaryBallAbility?
    private var fieldObjectPreview: FieldObjectKind?
    private var fieldObjectPreviewSpawned = false
    private var shockwaveBurstsRemaining = 0
    private var shockwaveBurstClock = 0.0
    private var lastWorldEffectActive = false
    private var marsDefeatCount = 0
    private var pendingVolatileCorePositions: [Vector2] = []

    convenience init(level: LevelDefinition, progress: PlayerProgress, assistMode: Bool, seed: UInt64) {
        self.init(mode: .campaign(level: level.number), progress: progress, assistMode: assistMode, seed: seed)
    }

    init(mode: RunMode, progress: PlayerProgress, assistMode: Bool, seed: UInt64) {
        self.mode = mode
        self.level = mode.campaignLevel.map(GameContent.level)
        self.world = mode.world
        self.stats = PlayerStats(progress: progress)
        self.character = CharacterCatalog.character(progress.selectedCharacter)
        self.assistMode = assistMode
        self.random = SeededGenerator(seed: seed)
        let duration = level?.duration ?? EndlessRules.waveDuration
        let waveCount = level?.waveCount ?? Int.max
        let waveDuration = level?.waveDuration ?? EndlessRules.waveDuration
        self.snapshot = SimulationSnapshot(
            playerX: 0,
            stamina: stats.maxStamina,
            maxStamina: stats.maxStamina,
            elapsed: 0,
            duration: duration,
            tokens: 0,
            targets: [],
            projectiles: [],
            characterAttacks: [],
            shieldCharges: stats.startingShields,
            wave: 1,
            waveElapsed: 0,
            waveDuration: waveDuration,
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
            characterAbilityReady: false,
            worldEffectActive: false,
            worldEffectProgress: 0
        )
        schedulePowerUp()
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
        }
        if let comboArgumentIndex = arguments.firstIndex(of: "--combo-preview"),
           arguments.indices.contains(comboArgumentIndex + 1),
           let requestedCombo = Int(arguments[comboArgumentIndex + 1]) {
            comboCount = max(0, requestedCombo)
            comboTimer = 30
            snapshot.combo = comboCount
            snapshot.comboFraction = comboCount > 0 ? 1 : 0
        }
        if level != nil, arguments.contains("--boss-preview") {
            snapshot.waveElapsed = snapshot.waveDuration * 0.69
            powerUpSpawned = true
        } else if level != nil, arguments.contains("--wave-complete-preview") {
            snapshot.waveElapsed = snapshot.waveDuration
            bossSpawned = true
            powerUpSpawned = true
        } else if arguments.contains("--power-up-preview") {
            nextPowerUpTime = 0
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

    func abilityRank(_ ability: AbilityKind) -> Int { abilities[ability, default: 0] }

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
        snapshot.waveElapsed = max(0, elapsed)
        bossSpawned = false
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
            let safetyFloor = 0.14
            return safetyFloor + (stats.kickCooldown - safetyFloor) * pow(0.88, Double(safeRank))
        }
        return max(0.14, stats.kickCooldown * pow(0.82, Double(safeRank)))
    }

    func update(delta rawDelta: Double) -> [SimulationEvent] {
        guard !finished else { return [] }
        let delta = min(max(rawDelta, 0), 1.0 / 20.0)
        var events: [SimulationEvent] = []
        snapshot.elapsed += delta
        snapshot.waveElapsed += delta
        updateTemporaryAbility(delta: delta)
        updateWorldEffect(events: &events)
        updatePlayer(delta: delta)
        updateCharacterAttackSchedule(delta: delta, events: &events)
        updateCombo(delta: delta, events: &events)
        updateSpawning(delta: delta)
        updatePowerUpSpawning()
        updateKicking(delta: delta, events: &events)
        updateTargets(delta: delta, events: &events)
        if finishCampaignAfterBossDefeat(events: &events) { return events }
        updateCharacterAttacks(delta: delta, events: &events)
        if finishCampaignAfterBossDefeat(events: &events) { return events }
        updateProjectiles(delta: delta, events: &events)
        if finishCampaignAfterBossDefeat(events: &events) { return events }
        spawnPendingVolatileCores()
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

    private func updateWorldEffect(events: inout [SimulationEvent]) {
        switch world {
        case .earth:
            snapshot.worldEffectActive = false
            snapshot.worldEffectProgress = 0
        case .moon:
            let cycle = snapshot.elapsed.truncatingRemainder(dividingBy: 16)
            snapshot.worldEffectActive = cycle >= 10
            snapshot.worldEffectProgress = cycle < 10 ? cycle / 10 : (cycle - 10) / 6
            if snapshot.worldEffectActive && !lastWorldEffectActive {
                events.append(.worldEffectActivated(.lunarCycle, .init(x: snapshot.playerX, y: 0.34)))
            }
            lastWorldEffectActive = snapshot.worldEffectActive
        case .mars:
            snapshot.worldEffectActive = false
            snapshot.worldEffectProgress = Double(marsDefeatCount % 6) / 6
        }
    }

    private func updateSpawning(delta: Double) {
        if let fieldObjectPreview {
            if !fieldObjectPreviewSpawned {
                fieldObjectPreviewSpawned = true
                spawnObject(fieldObjectPreview, x: 0, y: 0.62)
            }
            return
        }
        if mode.isEndless {
            updateEndlessSpawning(delta: delta)
        } else {
            updateCampaignSpawning(delta: delta)
        }
    }

    private func updateCampaignSpawning(delta: Double) {
        guard let level else { return }
        let wave = CampaignBalance.wave(snapshot.wave, for: level)
        let bossStart = wave.duration * 0.68
        if snapshot.waveElapsed >= bossStart,
           !bossSpawned,
           let boss = wave.boss,
           let bossTier = wave.bossTier {
            bossSpawned = true
            spawnEnemy(boss, x: 0, y: 0.82, tier: bossTier)
        }
        guard snapshot.waveElapsed < wave.duration else { return }
        spawnClock += delta
        let supportPressure = bossSpawned ? 1.42 : 1
        guard spawnClock >= wave.spawnInterval * supportPressure else { return }
        spawnClock = 0
        let enemy = level.enemies[Int(random.next() % UInt64(level.enemies.count))]
        spawnEnemy(enemy, x: randomSpawnX(near: 1.04), y: 1.04)
        if random.unit() < 0.12, let object = level.objects.randomElement(using: &random) {
            spawnObject(object, x: randomSpawnX(near: 1.10), y: 1.10)
        }
    }

    private func updateEndlessSpawning(delta: Double) {
        guard snapshot.waveElapsed < snapshot.waveDuration else { return }
        if snapshot.wave.isMultiple(of: 5), !bossSpawned, snapshot.waveElapsed >= 1 {
            bossSpawned = true
            spawnEnemy(GameContent.world(world).boss, x: 0, y: 0.84, tier: .megaBoss)
        }

        spawnClock += delta
        guard spawnClock >= EndlessRules.spawnInterval(wave: snapshot.wave) else { return }
        spawnClock = 0
        let pool = endlessEnemyPool
        for _ in 0..<EndlessRules.packSize(wave: snapshot.wave) {
            let enemy = pool[Int(random.next() % UInt64(pool.count))]
            let y = 1.04 + random.unit() * 0.10
            spawnEnemy(enemy, x: randomSpawnX(near: y), y: y)
        }
        if random.unit() < 0.10, let object = endlessObjectPool.randomElement(using: &random) {
            spawnObject(object, x: randomSpawnX(near: 1.12), y: 1.12)
        }
    }

    private func updatePowerUpSpawning() {
        guard !powerUpSpawned, snapshot.waveElapsed >= nextPowerUpTime else { return }
        powerUpSpawned = true
        let powers = GameContent.world(world).temporaryPowers
        let power = powers[Int(random.next() % UInt64(powers.count))]
        spawnPowerUp(power, x: randomSpawnX(near: 1.08), y: 1.08)
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
        let temporaryAbility = snapshot.activeTemporaryAbility
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
        var bossReinforcements: [EnemyKind] = []
        let slowFactor = 0.35 + 0.65 * pow(0.90, Double(abilities[.gravityBoots, default: 0]))
        let lunarSpeedFactor = snapshot.worldEffectActive ? 0.65 : 1
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
                    let burnDamage = max(1, stats.ballDamage * 0.18)
                    target.hitPoints -= burnDamage
                    events.append(.impact(target.position, burnDamage, .fire, false))
                    if target.hitPoints <= 0 {
                        removedTargetIDs.insert(target.id)
                        awardReward(for: target, events: &events)
                        registerDefeat(target, events: &events)
                        snapshot.targets[index] = target
                        continue
                    }
                }
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
                    if newPhase != bossPhase {
                        bossPhase = newPhase
                        events.append(.bossPhase(newPhase))
                        bossReinforcements = reinforcements(for: newPhase)
                        if world == .mars {
                            pendingVolatileCorePositions.append(target.position)
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
                    target.position.y -= enemySpeed(kind) * activeSpeedMultiplier * slowFactor * lunarSpeedFactor * freezeFactor * direction * delta
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
                target.position.y -= 0.11 * activeSpeedMultiplier * slowFactor * lunarSpeedFactor * delta
                if target.position.y <= 0.12 { removedTargetIDs.insert(target.id) }
            case .powerUp:
                target.position.y -= 0.26 * lunarSpeedFactor * delta
                target.position.x += sin(target.phase * 9.5) * 2.2 * delta
                target.position.x = min(0.82, max(-0.82, target.position.x))
                if target.position.y <= 0.12 { removedTargetIDs.insert(target.id) }
            case .volatileCore:
                target.position.y -= 0.10 * delta
                target.position.x += sin(target.phase * 6.5) * 0.08 * delta
                if target.phase >= 3 || target.position.y <= 0.12 {
                    removedTargetIDs.insert(target.id)
                }
            }
            snapshot.targets[index] = target
        }
        if !removedTargetIDs.isEmpty {
            snapshot.targets.removeAll { removedTargetIDs.contains($0.id) }
        }
        for (index, kind) in bossReinforcements.enumerated() {
            spawnEnemy(kind, x: index.isMultiple(of: 2) ? -0.58 : 0.58, y: 0.88)
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
            events.append(.impact(target.position, damage, .explosive, true))
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
            events.append(.impact(target.position, attack.damage, .standard, false))
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
            let lunarProjectileFactor = projectile.hostile && snapshot.worldEffectActive ? 0.65 : 1
            projectile.position.y += projectile.velocity.y * delta * lunarProjectileFactor
            if !projectile.hostile,
               projectile.characterProjectile == nil,
               snapshot.worldEffectActive,
               projectile.lunarRailBouncesRemaining > 0,
               abs(projectile.position.x) >= 0.90 {
                projectile.position.x = min(0.90, max(-0.90, projectile.position.x))
                projectile.velocity.x = abs(projectile.velocity.x) * (projectile.position.x < 0 ? 1 : -1)
                projectile.lunarRailBouncesRemaining -= 1
                events.append(.characterProjectileRicochet(projectile.position))
            }
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
                    applyProjectileHit(projectile, to: targetIndex, events: &events)
                    if projectile.temporaryAbility == .explosive {
                        applyExplosion(
                            centeredAt: position,
                            excluding: snapshot.targets[targetIndex].id,
                            damage: projectile.damage * 0.55,
                            events: &events
                        )
                    }
                    if projectile.temporaryAbility == .split, projectile.canSplit {
                        splitProjectiles.append(
                            contentsOf: makeSplitProjectiles(
                                from: position,
                                damage: projectile.damage * 0.42,
                                count: projectile.isCritical ? 8 : 5
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
            applyExplosion(
                centeredAt: position,
                excluding: snapshot.targets[targetIndex].id,
                damage: stats.ballDamage * 2.4,
                awardsAbilityCharge: projectile.characterProjectile == nil,
                events: &events
            )
            events.append(.volatileCoreBurst(position))
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
            snapshot.targets[targetIndex].burnRemaining = max(snapshot.targets[targetIndex].burnRemaining, 4)
            snapshot.targets[targetIndex].burnTickClock = min(snapshot.targets[targetIndex].burnTickClock, 0.18)
        case .ice:
            if snapshot.targets[targetIndex].burnRemaining > 0 {
                snapshot.targets[targetIndex].burnRemaining = 0
                snapshot.targets[targetIndex].burnTickClock = 0
                events.append(.elementalReaction(snapshot.targets[targetIndex].position))
            }
            snapshot.targets[targetIndex].freezeRemaining = max(snapshot.targets[targetIndex].freezeRemaining, 1.7)
        case .reverse:
            snapshot.targets[targetIndex].reverseRemaining = max(snapshot.targets[targetIndex].reverseRemaining, 2.8)
        default:
            break
        }
        events.append(.impact(
            snapshot.targets[targetIndex].position,
            projectile.damage,
            flavor,
            projectile.isCritical
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
        awardsAbilityCharge: Bool = true,
        events: inout [SimulationEvent]
    ) {
        for index in snapshot.targets.indices {
            let target = snapshot.targets[index]
            guard target.id != excludedID,
                  !hitTargetIDs.contains(target.id),
                  hypot(target.position.x - center.x, target.position.y - center.y) <= 0.28 else { continue }
            if case .powerUp = target.kind { continue }
            if case .volatileCore = target.kind { continue }
            snapshot.targets[index].hitPoints -= damage
            events.append(.impact(target.position, damage, .explosive, false))
            registerDefeatIfNeeded(
                at: index,
                awardsAbilityCharge: awardsAbilityCharge,
                events: &events
            )
        }
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
        if case .volatileCore = target.kind { return }
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
        guard snapshot.waveElapsed >= snapshot.waveDuration,
              !snapshot.targets.contains(where: isWaveBlockingTarget) else { return }
        let completedWave = snapshot.wave
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
            events.append(.waveCompleted(completedWave))
            events.append(.finished(true))
            return
        }

        snapshot.targets.removeAll()
        snapshot.wave += 1
        snapshot.waveElapsed = 0
        snapshot.projectiles.removeAll()
        snapshot.characterAttacks.removeAll()
        shockwaveBurstsRemaining = 0
        shockwaveBurstClock = 0
        spawnClock = 0
        bossSpawned = false
        bossPhase = 1
        powerUpSpawned = false
        schedulePowerUp()
        events.append(.waveCompleted(completedWave))
        events.append(.checkpoint(completedWave))
    }

    private func evaluateFinish(events: inout [SimulationEvent]) {
        if snapshot.stamina <= 0 {
            finished = true
            events.append(.finished(false))
            return
        }
        guard level != nil else { return }
    }

    private func finishCampaignAfterBossDefeat(events: inout [SimulationEvent]) -> Bool {
        guard campaignBossDefeated, level != nil else { return false }
        finished = true
        snapshot.targets.removeAll()
        snapshot.projectiles.removeAll()
        snapshot.characterAttacks.removeAll()
        pendingVolatileCorePositions.removeAll(keepingCapacity: true)
        events.append(.waveCompleted(snapshot.wave))
        events.append(.finished(true))
        return true
    }

    private func applyDamage(_ amount: Double, events: inout [SimulationEvent]) {
        if snapshot.shieldCharges > 0 {
            snapshot.shieldCharges -= 1
        } else {
            snapshot.stamina = max(0, snapshot.stamina - amount)
            if comboCount > 0 {
                comboCount = 0
                comboTimer = 0
                snapshot.combo = 0
                snapshot.comboFraction = 0
                events.append(.comboChanged(0))
            }
        }
        events.append(.damage)
    }

    private func updateCombo(delta: Double, events: inout [SimulationEvent]) {
        guard comboCount > 0 else { return }
        comboTimer -= delta
        snapshot.comboFraction = max(0, comboTimer / Self.comboWindow)
        if comboTimer <= 0 {
            comboCount = 0
            snapshot.combo = 0
            snapshot.comboFraction = 0
            events.append(.comboChanged(0))
        }
    }

    private func registerDefeat(
        _ target: TargetState,
        awardsAbilityCharge: Bool = true,
        events: inout [SimulationEvent]
    ) {
        comboCount += 1
        comboTimer = Self.comboWindow
        snapshot.combo = comboCount
        snapshot.comboFraction = 1
        snapshot.bestCombo = max(snapshot.bestCombo, comboCount)
        snapshot.targetsDefeated += 1
        if awardsAbilityCharge {
            snapshot.characterAbilityCharge = min(100, snapshot.characterAbilityCharge + 20)
            snapshot.characterAbilityReady = snapshot.characterAbilityCharge >= 100
        }
        if world == .mars,
           case .enemy = target.kind,
           target.bossTier == .standard {
            marsDefeatCount += 1
            if marsDefeatCount.isMultiple(of: 6) {
                pendingVolatileCorePositions.append(target.position)
            }
        }
        if case .enemy = target.kind, target.bossTier != .standard {
            snapshot.bossesDefeated += 1
            if let level, snapshot.wave == level.waveCount {
                campaignBossDefeated = true
            }
        }
        events.append(.comboChanged(comboCount))
        if Self.comboMilestones.contains(comboCount) { events.append(.comboMilestone(comboCount)) }
    }

    private func spawnEnemy(
        _ kind: EnemyKind,
        x: Double,
        y: Double,
        tier: CampaignBossTier = .standard
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
        let tierMultiplier = CampaignBalance.bossHealthMultiplier(tier: tier, wave: snapshot.wave)
        let hitPoints = enemyHealth(kind) * multiplier * tierMultiplier
        var target = TargetState(
            id: identifier(),
            kind: .enemy(kind),
            position: .init(x: x, y: statusEffectPreview == nil ? y : min(y, 0.62)),
            hitPoints: hitPoints,
            maximumHitPoints: hitPoints,
            phase: 0,
            bossTier: tier
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

    private func spawnPendingVolatileCores() {
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
        let turn = min(1, delta * turnRate)
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
            return min(9, 1.8 + Double(rank) * 1.7)
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
            lunarRailBouncesRemaining: world == .moon ? 1 : 0,
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
        let count = min(ordered.count, 1 + max(0, snapshot.wave - 1) / 2)
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
            let count = phase == 2 ? 2 : 3
            return (0..<count).map { _ in
                level.enemies[Int(random.next() % UInt64(level.enemies.count))]
            }
        }
        return switch world {
        case .earth: phase == 2 ? [.coneRunner, .coneRunner] : [.tackleBot, .keeperDrone]
        case .moon: phase == 2 ? [.regolithRunner, .regolithRunner] : [.lunarHopper, .eclipseKeeper]
        case .mars: phase == 2 ? [.dustSprite, .dustSprite] : [.craterCrawler, .saucerKeeper]
        }
    }

    private func schedulePowerUp() {
        let earliest = snapshot.waveDuration * 0.25
        let window = snapshot.waveDuration * 0.28
        nextPowerUpTime = earliest + random.unit() * window
    }

    private func isWaveBlockingTarget(_ target: TargetState) -> Bool {
        if case .enemy = target.kind { return true }
        return false
    }

    private func damageFlavor(for ability: TemporaryBallAbility?) -> DamageFlavor {
        switch ability {
        case .explosive: .explosive
        case .fire: .fire
        case .ice: .ice
        case .reverse: .reverse
        case .split: .split
        case .rapidFire, .heatSeeking, .orbitShot, .solarPierce, nil: .standard
        }
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
