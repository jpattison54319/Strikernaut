import Foundation

final class GameSimulation {
    private(set) var snapshot: SimulationSnapshot
    private let mode: RunMode
    private let level: LevelDefinition?
    private let world: WorldID
    private let stats: PlayerStats
    private let assistMode: Bool
    private var random: SeededGenerator
    private var targetPlayerX = 0.0
    private var spawnClock = 0.0
    private var kickClock = 0.0
    private var nextIdentifier = 1
    private var checkpointIndex = 0
    private var abilities: [AbilityKind: Int] = [:]
    private var finished = false
    private var bossSpawned = false
    private var bossPhase = 1
    private var kickCount = 0
    static let comboWindow: Double = 3.0
    private static let comboMilestones: Set<Int> = [5, 10, 15, 25, 50, 100]
    private var comboCount = 0
    private var comboTimer = 0.0

    convenience init(level: LevelDefinition, progress: PlayerProgress, assistMode: Bool, seed: UInt64) {
        self.init(mode: .campaign(level: level.number), progress: progress, assistMode: assistMode, seed: seed)
    }

    init(mode: RunMode, progress: PlayerProgress, assistMode: Bool, seed: UInt64) {
        self.mode = mode
        self.level = mode.campaignLevel.map(GameContent.level)
        self.world = mode.world
        self.stats = PlayerStats(progress: progress)
        self.assistMode = assistMode
        self.random = SeededGenerator(seed: seed)
        let duration = level?.duration ?? EndlessRules.waveDuration
        self.snapshot = SimulationSnapshot(
            playerX: 0,
            stamina: stats.maxStamina,
            maxStamina: stats.maxStamina,
            elapsed: 0,
            duration: duration,
            tokens: 0,
            targets: [],
            projectiles: [],
            shieldCharges: stats.startingShields,
            wave: mode.isEndless ? 1 : 0,
            waveElapsed: 0,
            waveDuration: EndlessRules.waveDuration,
            score: 0,
            isEndless: mode.isEndless,
            combo: 0,
            comboFraction: 0,
            bestCombo: 0,
            targetsDefeated: 0,
            bossesDefeated: 0
        )
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
        if mode.isEndless { snapshot.waveElapsed += delta }
        updatePlayer(delta: delta)
        updateCombo(delta: delta, events: &events)
        updateCampaignCheckpoints(events: &events)
        updateSpawning(delta: delta)
        updateKicking(delta: delta, events: &events)
        updateTargets(delta: delta, events: &events)
        updateProjectiles(delta: delta, events: &events)
        evaluateEndlessWave(events: &events)
        evaluateFinish(events: &events)
        return events
    }

    private func updatePlayer(delta: Double) {
        let difference = targetPlayerX - snapshot.playerX
        snapshot.playerX += difference * min(1, stats.movementResponse * delta)
    }

    private func updateCampaignCheckpoints(events: inout [SimulationEvent]) {
        guard let level else { return }
        let thresholds = level.number == 1 ? [0.40] : [0.25, 0.5, 0.75]
        guard checkpointIndex < thresholds.count else { return }
        if snapshot.elapsed / level.duration >= thresholds[checkpointIndex] {
            checkpointIndex += 1
            if level.number == 1 {
                snapshot.stamina = min(snapshot.maxStamina, snapshot.stamina + 10)
            }
            events.append(.checkpoint(checkpointIndex))
        }
    }

    private func updateSpawning(delta: Double) {
        if mode.isEndless {
            updateEndlessSpawning(delta: delta)
        } else {
            updateCampaignSpawning(delta: delta)
        }
    }

    private func updateCampaignSpawning(delta: Double) {
        guard let level else { return }
        let bossStart = level.duration - 38
        if level.hasBoss && snapshot.elapsed >= bossStart {
            if !bossSpawned {
                bossSpawned = true
                spawnEnemy(GameContent.world(level.world).boss, x: 0, y: 0.82)
            }
            return
        }
        guard snapshot.elapsed < level.duration - 8 else { return }
        spawnClock += delta
        let pressure = 1 - min(0.22, snapshot.elapsed / level.duration * 0.22)
        guard spawnClock >= level.spawnInterval * pressure else { return }
        spawnClock = 0
        let enemy = level.enemies[Int(random.next() % UInt64(level.enemies.count))]
        spawnEnemy(enemy, x: randomLaneX(), y: 1.04)
        if random.unit() < 0.12, let object = level.objects.randomElement(using: &random) {
            spawnObject(object, x: randomLaneX(), y: 1.10)
        }
    }

    private func updateEndlessSpawning(delta: Double) {
        guard snapshot.waveElapsed < snapshot.waveDuration else { return }
        if snapshot.wave.isMultiple(of: 5), !bossSpawned, snapshot.waveElapsed >= 1 {
            bossSpawned = true
            spawnEnemy(GameContent.world(world).boss, x: 0, y: 0.84)
        }

        spawnClock += delta
        guard spawnClock >= EndlessRules.spawnInterval(wave: snapshot.wave) else { return }
        spawnClock = 0
        let pool = endlessEnemyPool
        for _ in 0..<EndlessRules.packSize(wave: snapshot.wave) {
            let enemy = pool[Int(random.next() % UInt64(pool.count))]
            spawnEnemy(enemy, x: randomLaneX(), y: 1.04 + random.unit() * 0.10)
        }
        if random.unit() < 0.10, let object = endlessObjectPool.randomElement(using: &random) {
            spawnObject(object, x: randomLaneX(), y: 1.12)
        }
    }

    private func updateKicking(delta: Double, events: inout [SimulationEvent]) {
        kickClock += delta
        let quickRank = abilities[.quickRelease, default: 0]
        let cooldown = kickInterval(atAbilityRank: quickRank)
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

        let critical = isMeteor || random.unit() < stats.criticalChance
        let damage = baseDamage * (critical ? 2 : 1)
        let pierce = abilities[.throughBall, default: 0] + stats.extraPierce
        spawnProjectile(x: snapshot.playerX, velocityX: 0, damage: damage, pierce: pierce, hostile: false, critical: critical)
        spawnVolley(rank: abilities[.oneTwo, default: 0], damage: damage, pierce: pierce, critical: critical)
        events.append(.kick)
    }

    private func spawnVolley(rank: Int, damage: Double, pierce: Int, critical: Bool) {
        guard rank > 0 else { return }
        let mastery = 1 + Double(max(0, rank - 3)) * 0.12
        switch rank {
        case 1:
            spawnSpreadPair(horizontalSpeed: 0.34, damage: damage * 0.70, pierce: pierce, critical: critical)
        case 2:
            spawnSpreadPair(horizontalSpeed: 0.46, damage: damage * 0.74, pierce: pierce, critical: critical)
        default:
            spawnSpreadPair(horizontalSpeed: 0.32, damage: damage * 0.78 * mastery, pierce: pierce, critical: critical)
            spawnSpreadPair(horizontalSpeed: 0.58, damage: damage * 0.68 * mastery, pierce: pierce, critical: critical)
        }
    }

    private func updateTargets(delta: Double, events: inout [SimulationEvent]) {
        var removed: Set<Int> = []
        var bossReinforcements: [EnemyKind] = []
        let slowFactor = 0.35 + 0.65 * pow(0.90, Double(abilities[.gravityBoots, default: 0]))
        for index in snapshot.targets.indices {
            var target = snapshot.targets[index]
            target.phase += delta
            switch target.kind {
            case .enemy(let kind):
                if isBoss(kind) {
                    target.position.x = sin(target.phase * 0.9) * 0.70
                    let healthRatio = target.hitPoints / target.maximumHitPoints
                    let newPhase = healthRatio > 0.66 ? 1 : (healthRatio > 0.33 ? 2 : 3)
                    if newPhase != bossPhase {
                        bossPhase = newPhase
                        events.append(.bossPhase(newPhase))
                        bossReinforcements = reinforcements(for: newPhase)
                    }
                    let attackInterval = max(0.90, 2.3 - Double(bossPhase) * 0.3)
                    if target.phase.truncatingRemainder(dividingBy: attackInterval) < delta {
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
                    let speedFactor = level?.number == 1 ? 0.85 : 1.0
                    target.position.y -= enemySpeed(kind) * speedFactor * activeSpeedMultiplier * slowFactor * delta
                    if kind == .tackleBot || kind == .craterCrawler {
                        target.position.x += sin(target.phase * 5.2) * delta * 0.23
                    }
                    if isRanged(kind), target.phase.truncatingRemainder(dividingBy: 3.0) < delta, target.position.y < 0.86 {
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
                    removed.insert(target.id)
                    applyDamage(contactDamage(kind) * activeDamageMultiplier, events: &events)
                }
            case .fieldObject:
                target.position.y -= 0.11 * activeSpeedMultiplier * slowFactor * delta
                if target.position.y <= 0.12 { removed.insert(target.id) }
            }
            snapshot.targets[index] = target
        }
        snapshot.targets.removeAll { removed.contains($0.id) }
        for (index, kind) in bossReinforcements.enumerated() {
            spawnEnemy(kind, x: index.isMultiple(of: 2) ? -0.58 : 0.58, y: 0.88)
        }
    }

    private func updateProjectiles(delta: Double, events: inout [SimulationEvent]) {
        var removedProjectiles: Set<Int> = []
        var removedTargets: Set<Int> = []
        for projectileIndex in snapshot.projectiles.indices {
            var projectile = snapshot.projectiles[projectileIndex]
            let tracking = stats.homingStrength + Double(abilities[.curler, default: 0]) * 0.55
            if !projectile.hostile, tracking > 0,
               let nearest = snapshot.targets.min(by: { abs($0.position.y - projectile.position.y) < abs($1.position.y - projectile.position.y) }) {
                projectile.velocity.x += (nearest.position.x - projectile.position.x) * delta * tracking
                projectile.velocity.x = min(1.4, max(-1.4, projectile.velocity.x))
            }
            projectile.position.x += projectile.velocity.x * delta
            projectile.position.y += projectile.velocity.y * delta
            if projectile.hostile {
                let width = assistMode ? 0.08 : 0.11
                if projectile.position.y <= 0.14 && abs(projectile.position.x - snapshot.playerX) < width {
                    removedProjectiles.insert(projectile.id)
                    applyDamage(projectile.damage, events: &events)
                } else if projectile.position.y < -0.05 {
                    removedProjectiles.insert(projectile.id)
                }
            } else {
                let hitWidth = assistMode ? 0.17 : 0.115
                if let targetIndex = snapshot.targets.firstIndex(where: {
                    !removedTargets.contains($0.id) && abs($0.position.x - projectile.position.x) < hitWidth && abs($0.position.y - projectile.position.y) < 0.055
                }) {
                    snapshot.targets[targetIndex].hitPoints -= projectile.damage
                    events.append(.impact(snapshot.targets[targetIndex].position, projectile.isCritical))
                    if snapshot.targets[targetIndex].hitPoints <= 0 {
                        let defeated = snapshot.targets[targetIndex]
                        removedTargets.insert(defeated.id)
                        awardReward(for: defeated, events: &events)
                        registerDefeat(defeated, events: &events)
                    }
                    if projectile.remainingPierces > 0 {
                        projectile.remainingPierces -= 1
                    } else {
                        removedProjectiles.insert(projectile.id)
                    }
                }
                if projectile.position.y > 1.12 || abs(projectile.position.x) > 1.1 {
                    removedProjectiles.insert(projectile.id)
                }
            }
            snapshot.projectiles[projectileIndex] = projectile
        }
        snapshot.projectiles.removeAll { removedProjectiles.contains($0.id) }
        snapshot.targets.removeAll { removedTargets.contains($0.id) }
    }

    private func evaluateEndlessWave(events: inout [SimulationEvent]) {
        guard mode.isEndless, snapshot.waveElapsed >= snapshot.waveDuration, snapshot.targets.isEmpty else { return }
        let completedWave = snapshot.wave
        snapshot.score += EndlessRules.waveClearScore(wave: completedWave)
        let tokenBonus = max(4, completedWave * 2)
        snapshot.tokens += tokenBonus
        events.append(.reward(tokenBonus, .init(x: snapshot.playerX, y: 0.16)))

        let recoveryRank = abilities[.secondWind, default: 0]
        if recoveryRank > 0 {
            let amount = min(snapshot.maxStamina - snapshot.stamina, 4 + Double(recoveryRank) * 3)
            if amount > 0 {
                snapshot.stamina += amount
                events.append(.heal(amount, .init(x: snapshot.playerX, y: 0.16)))
            }
        }

        snapshot.wave += 1
        snapshot.waveElapsed = 0
        snapshot.projectiles.removeAll()
        spawnClock = 0
        bossSpawned = false
        bossPhase = 1
        events.append(.waveCompleted(completedWave))
        events.append(.checkpoint(completedWave))
    }

    private func evaluateFinish(events: inout [SimulationEvent]) {
        if snapshot.stamina <= 0 {
            finished = true
            events.append(.finished(false))
            return
        }
        guard let level else { return }
        if snapshot.elapsed >= level.duration && snapshot.targets.isEmpty {
            finished = true
            events.append(.finished(true))
        }
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

    private func registerDefeat(_ target: TargetState, events: inout [SimulationEvent]) {
        comboCount += 1
        comboTimer = Self.comboWindow
        snapshot.combo = comboCount
        snapshot.comboFraction = 1
        snapshot.bestCombo = max(snapshot.bestCombo, comboCount)
        snapshot.targetsDefeated += 1
        if case .enemy(let kind) = target.kind, isBoss(kind) { snapshot.bossesDefeated += 1 }
        events.append(.comboChanged(comboCount))
        if Self.comboMilestones.contains(comboCount) { events.append(.comboMilestone(comboCount)) }
    }

    private func spawnEnemy(_ kind: EnemyKind, x: Double, y: Double) {
        var multiplier: Double
        if mode.isEndless {
            multiplier = EndlessRules.healthMultiplier(wave: snapshot.wave)
        } else {
            multiplier = 1 + Double((level?.number ?? 1) - 1) * 0.08
            if level?.number == 1 { multiplier = 0.85 }
        }
        let hitPoints = enemyHealth(kind) * multiplier
        snapshot.targets.append(TargetState(id: identifier(), kind: .enemy(kind), position: .init(x: x, y: y), hitPoints: hitPoints, maximumHitPoints: hitPoints, phase: 0))
    }

    private func spawnObject(_ kind: FieldObjectKind, x: Double, y: Double) {
        let base: Double = switch kind {
        case .ballCart, .meteorCrate: 18
        case .waterCooler, .oxygenPod: 14
        case .tacticsBoard, .holoGate: 35
        case .coneBarricade, .crystalBarricade: 20
        case .equipmentTrunk, .artifactVault: 55
        }
        let multiplier = mode.isEndless ? sqrt(EndlessRules.healthMultiplier(wave: snapshot.wave)) : 1
        let hitPoints = base * multiplier
        snapshot.targets.append(TargetState(id: identifier(), kind: .fieldObject(kind), position: .init(x: x, y: y), hitPoints: hitPoints, maximumHitPoints: hitPoints, phase: 0))
    }

    private func spawnProjectile(x: Double, y: Double = 0.17, velocityX: Double, damage: Double, pierce: Int, hostile: Bool, critical: Bool) {
        let speed = hostile ? (assistMode ? -0.30 : -0.38) : stats.ballSpeed
        snapshot.projectiles.append(ProjectileState(id: identifier(), position: .init(x: x, y: y), velocity: .init(x: velocityX, y: speed), damage: damage, remainingPierces: pierce, hostile: hostile, isCritical: critical))
    }

    private func spawnSpreadPair(horizontalSpeed: Double, damage: Double, pierce: Int, critical: Bool) {
        spawnProjectile(x: snapshot.playerX - 0.025, velocityX: -horizontalSpeed, damage: damage, pierce: pierce, hostile: false, critical: critical)
        spawnProjectile(x: snapshot.playerX + 0.025, velocityX: horizontalSpeed, damage: damage, pierce: pierce, hostile: false, critical: critical)
    }

    private func awardReward(for target: TargetState, events: inout [SimulationEvent]) {
        switch target.kind {
        case .enemy(let enemy):
            let baseValue = isBoss(enemy) ? (world == .mars ? 180 : 150) : tokenValue(enemy)
            awardTokens(baseValue, at: target.position, events: &events)
        case .fieldObject(.waterCooler), .fieldObject(.oxygenPod):
            let amount = min(24, snapshot.maxStamina - snapshot.stamina)
            snapshot.stamina += amount
            events.append(.heal(amount, target.position))
        case .fieldObject(.equipmentTrunk), .fieldObject(.artifactVault):
            awardTokens(35, at: target.position, events: &events)
        case .fieldObject(.ballCart), .fieldObject(.meteorCrate):
            awardTokens(18, at: target.position, events: &events)
        case .fieldObject:
            awardTokens(8, at: target.position, events: &events)
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
        mode.isEndless ? EndlessRules.damageMultiplier(wave: snapshot.wave) : 1
    }

    private var activeSpeedMultiplier: Double {
        mode.isEndless ? EndlessRules.speedMultiplier(wave: snapshot.wave) : 1
    }

    private var endlessEnemyPool: [EnemyKind] {
        let ordered: [EnemyKind] = switch world {
        case .earth: [.coneRunner, .dummyDefender, .tackleBot, .keeperDrone, .ballLauncher]
        case .mars: [.dustSprite, .roverRaider, .craterCrawler, .saucerKeeper, .plasmaStriker]
        }
        let count = min(ordered.count, 1 + max(0, snapshot.wave - 1) / 2)
        return Array(ordered.prefix(count))
    }

    private var endlessObjectPool: [FieldObjectKind] {
        switch world {
        case .earth: [.ballCart, .waterCooler, .tacticsBoard, .coneBarricade, .equipmentTrunk]
        case .mars: [.meteorCrate, .oxygenPod, .holoGate, .crystalBarricade, .artifactVault]
        }
    }

    private func reinforcements(for phase: Int) -> [EnemyKind] {
        switch world {
        case .earth: phase == 2 ? [.coneRunner, .coneRunner] : [.tackleBot, .keeperDrone]
        case .mars: phase == 2 ? [.dustSprite, .dustSprite] : [.craterCrawler, .saucerKeeper]
        }
    }

    private func randomLaneX() -> Double { laneX(Int(random.next() % 3)) }
    private func identifier() -> Int { defer { nextIdentifier += 1 }; return nextIdentifier }
    private func laneX(_ lane: Int) -> Double { [-0.62, 0, 0.62][min(max(lane, 0), 2)] }

    private func isBoss(_ kind: EnemyKind) -> Bool {
        kind == .titanKeeper || kind == .marsColossus
    }

    private func isRanged(_ kind: EnemyKind) -> Bool {
        kind == .ballLauncher || kind == .plasmaStriker
    }

    private func enemyHealth(_ kind: EnemyKind) -> Double {
        switch kind {
        case .coneRunner, .dustSprite: 10
        case .dummyDefender, .roverRaider: 24
        case .tackleBot, .craterCrawler: 18
        case .keeperDrone, .saucerKeeper: 42
        case .ballLauncher, .plasmaStriker: 28
        case .titanKeeper: 720
        case .marsColossus: 900
        }
    }

    private func enemySpeed(_ kind: EnemyKind) -> Double {
        switch kind {
        case .coneRunner, .dustSprite: 0.105
        case .dummyDefender, .roverRaider: 0.075
        case .tackleBot, .craterCrawler: 0.13
        case .keeperDrone, .saucerKeeper: 0.06
        case .ballLauncher, .plasmaStriker: 0.05
        case .titanKeeper, .marsColossus: 0
        }
    }

    private func contactDamage(_ kind: EnemyKind) -> Double {
        switch kind {
        case .coneRunner, .dustSprite: 9
        case .titanKeeper, .marsColossus: 22
        default: 14
        }
    }

    private func tokenValue(_ kind: EnemyKind) -> Int {
        switch kind {
        case .coneRunner, .dustSprite: 2
        case .dummyDefender, .roverRaider: 4
        case .tackleBot, .craterCrawler: 5
        case .keeperDrone, .saucerKeeper: 7
        case .ballLauncher, .plasmaStriker: 8
        case .titanKeeper: 150
        case .marsColossus: 180
        }
    }
}
