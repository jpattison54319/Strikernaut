import SpriteKit

@MainActor
final class GoalRushScene: SKScene {
    private unowned let session: GameSessionModel
    private let world = SKNode()
    private let targetLayer = SKNode()
    private let characterAttackLayer = SKNode()
    private let projectileLayer = SKNode()
    private let bossHazardLayer = SKNode()
    private let effectsLayer = SKNode()
    private let playerNode: SKNode
    private let touchGuide = SKNode()
    private var targetNodes: [Int: SKNode] = [:]
    private var projectileNodes: [Int: SKNode] = [:]
    private var characterAttackNodes: [Int: SKSpriteNode] = [:]
    private var bossHazardNodes: [Int: SKShapeNode] = [:]
    private var targetKinds: [Int: TargetState.Kind] = [:]
    private var targetNodePools: [TargetState.Kind: [SKNode]] = [:]
    private var friendlyProjectilePool: [SKNode] = []
    private var hostileProjectilePool: [SKNode] = []
    private var kickWavePool: [SKShapeNode] = []
    private var normalImpactPool: [SKShapeNode] = []
    private var criticalImpactPool: [SKShapeNode] = []
    private var damageNumberPool: [SKNode] = []
    private var meteorAttackPool: [SKSpriteNode] = []
    private var shockwaveAttackPool: [SKSpriteNode] = []
    private var ricochetFlashPool: [SKShapeNode] = []
    private var freezeCrystalPool: [SKShapeNode] = []
    private var meteorImpactPool: [SKSpriteNode] = []
    private var shockwaveLaunchPool: [SKShapeNode] = []
    private var shockwaveContactPool: [SKShapeNode] = []
    private var criticalLabelPool: [SKLabelNode] = []
    private var liveTargetIDs = Set<Int>()
    private var liveProjectileIDs = Set<Int>()
    private var liveCharacterAttackIDs = Set<Int>()
    private var liveBossHazardIDs = Set<Int>()
    private var targetHealthRatios: [Int: Double] = [:]
    private var configuredSize = CGSize.zero
    private var renderedWorldID: WorldID
    private var lastHandledEventPulse = 0
    private var targetPrewarmQueue: [TargetState.Kind]
    private var targetPrewarmIndex = 0
    private var impactPrewarmIndex = 0
    private let reducedEffects: Bool
#if DEBUG
    private var didShowRewardPreview = false
#endif
    private lazy var meteorTexture = SKTexture(imageNamed: "AbilityMeteor")
    private lazy var shockwaveTexture = SKTexture(imageNamed: "AbilityShockwave")
    private lazy var meteorImpactTexture = SKTexture(imageNamed: "AbilityMeteorImpact")
    var eventHandler: (([SimulationEvent], SimulationSnapshot) -> Void)?

    init(session: GameSessionModel, reducedEffects: Bool) {
        self.session = session
        self.reducedEffects = reducedEffects
        self.playerNode = GameNodeFactory.player(character: session.character.id)
        self.renderedWorldID = session.snapshot.world
        if let level = session.level {
            self.targetPrewarmQueue = level.enemies.map(TargetState.Kind.enemy)
                + level.objects.map(TargetState.Kind.fieldObject)
                + TemporaryBallAbility.allCases.map(TargetState.Kind.powerUp)
                + [.enemy(session.world.boss)]
        } else {
            self.targetPrewarmQueue = Array(Set(
                GameContent.levels.flatMap {
                    $0.enemies.map(TargetState.Kind.enemy)
                        + $0.objects.map(TargetState.Kind.fieldObject)
                }
            )) + TemporaryBallAbility.allCases.map(TargetState.Kind.powerUp)
                + GameContent.worlds.map { .enemy($0.boss) }
        }
        super.init(size: .init(width: 390, height: 844))
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.025, green: 0.07, blue: 0.14, alpha: 1)
    }

    required init?(coder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        view.shouldCullNonVisibleNodes = true
        anchorPoint = .zero
        addChild(world)
        world.addChild(targetLayer)
        world.addChild(characterAttackLayer)
        world.addChild(projectileLayer)
        world.addChild(bossHazardLayer)
        world.addChild(effectsLayer)
        world.addChild(playerNode)
        configureTouchGuide()
        GameNodeFactory.prewarmKickActions()
        GameNodeFactory.prewarmProjectileTextures()
        kickWavePool = (0..<2).map { _ in makeKickWave() }
        friendlyProjectilePool = (0..<3).map { _ in
            let node = GameNodeFactory.projectile(hostile: false)
            node.name = "friendly-projectile"
            return node
        }
        addChild(touchGuide)
        rebuildField()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size != configuredSize else { return }
        configuredSize = size
        rebuildField()
    }

    override func update(_ currentTime: TimeInterval) {
#if DEBUG
        showRewardPreviewIfRequested()
#endif
        // Spread prototype construction across early frames, before the first
        // scheduled spawn, instead of blocking the exact frame a target appears.
        if targetPrewarmIndex < targetPrewarmQueue.count {
            GameNodeFactory.prewarmTarget(kind: targetPrewarmQueue[targetPrewarmIndex])
            targetPrewarmIndex += 1
        } else if impactPrewarmIndex < 35 {
            // A single small node per frame keeps impact feedback allocation-free
            // without concentrating setup work into navigation or gameplay events.
            if impactPrewarmIndex < 19 {
                let critical = impactPrewarmIndex >= 7
                recycleImpactSpark(makeImpactSpark(critical: critical), critical: critical)
            } else {
                recycleDamageNumber(makeDamageNumber())
            }
            impactPrewarmIndex += 1
        }
        // Button-driven events can arrive between SpriteKit frames. Consume them
        // before advancing the simulation so a kick/update cannot overwrite the
        // ability activation and make its visual/audio feedback disappear.
        consumePendingEvents()
        session.update(currentTime: currentTime)
        consumePendingEvents()
        render(session.snapshot)
    }

    private func consumePendingEvents() {
        guard session.eventPulse != lastHandledEventPulse else { return }
        lastHandledEventPulse = session.eventPulse
        handle(session.recentEvents)
        eventHandler?(session.recentEvents, session.snapshot)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { updateTouch(touches.first) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { updateTouch(touches.first) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { hideTouchGuide() }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { hideTouchGuide() }

    private func updateTouch(_ touch: UITouch?) {
        guard let touch else { return }
        let location = touch.location(in: self)
        let x = location.x / max(size.width, 1)
        session.setPlayerTarget((Double(x) - 0.5) / 0.42)
        touchGuide.position = location
        touchGuide.alpha = 1
        touchGuide.setScale(1)
    }

    private func rebuildField(animated: Bool = false) {
        let retiringField = world.childNode(withName: "field")
        let retiringTint = world.childNode(withName: "arena-tint")
        retiringField?.name = "retiring-field"
        retiringTint?.name = "retiring-arena-tint"

        let definition = GameContent.world(renderedWorldID)
        let texture = SKTexture(imageNamed: definition.gameplayAsset)
        let field = SKSpriteNode(texture: texture)
        field.name = "field"
        let textureSize = texture.size()
        let scale = max(size.width / max(textureSize.width, 1), size.height / max(textureSize.height, 1))
        field.size = CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
        field.position = CGPoint(x: size.width / 2, y: size.height / 2)
        field.zPosition = -200
        field.alpha = animated ? 0 : 1
        world.insertChild(field, at: 0)

        let turfTint = SKShapeNode(rectOf: size)
        turfTint.fillColor = renderedWorldID == .mars
            ? SKColor(red: 0.20, green: 0.02, blue: 0.22, alpha: 0.10)
            : SKColor(red: 0.02, green: 0.10, blue: 0.16, alpha: 0.12)
        turfTint.strokeColor = .clear
        turfTint.position = field.position
        turfTint.zPosition = -190
        turfTint.name = "arena-tint"
        turfTint.alpha = animated ? 0 : 1
        world.insertChild(turfTint, at: 1)

        if animated {
            field.run(.fadeIn(withDuration: 0.32))
            turfTint.run(.fadeIn(withDuration: 0.32))
            retiringField?.run(.sequence([
                .fadeOut(withDuration: 0.24),
                .removeFromParent()
            ]))
            retiringTint?.run(.sequence([
                .fadeOut(withDuration: 0.24),
                .removeFromParent()
            ]))
        } else {
            retiringField?.removeFromParent()
            retiringTint?.removeFromParent()
        }
    }

    private func render(_ snapshot: SimulationSnapshot) {
        if renderedWorldID != snapshot.world {
            renderedWorldID = snapshot.world
            rebuildField(animated: !reducesMotion)
        }
        playerNode.position = point(x: snapshot.playerX, y: 0.08)
        playerNode.zPosition = 1_000
        syncTargets(snapshot.targets)
        syncCharacterAttacks(snapshot.characterAttacks)
        syncProjectiles(snapshot.projectiles)
        syncBossHazards(snapshot.bossHazards)
    }

    private func syncTargets(_ targets: [TargetState]) {
        liveTargetIDs.removeAll(keepingCapacity: true)
        for target in targets { liveTargetIDs.insert(target.id) }
        for id in targetNodes.keys where !liveTargetIDs.contains(id) {
            if let node = targetNodes.removeValue(forKey: id), let kind = targetKinds.removeValue(forKey: id) {
                recycleTarget(node, kind: kind)
            }
            targetHealthRatios.removeValue(forKey: id)
        }
        let reduceMotion = reducesMotion
        for target in targets {
            let node = targetNodes[target.id] ?? {
                let newNode = dequeueTarget(for: target)
                targetLayer.addChild(newNode)
                targetNodes[target.id] = newNode
                targetKinds[target.id] = target.kind
                return newNode
            }()
            let scale = perspectiveScale(target.position.y)
            var targetPoint = point(x: target.position.x, y: target.position.y)
            let isFrozen = target.freezeRemaining > 0
            if !isFrozen {
                targetPoint.y += CGFloat(sin(target.phase * 7.5) * 2.2) * scale
            }
            node.position = targetPoint
            let bossMultiplier = scale * CGFloat(CampaignBalance.bossScale(tier: target.bossTier))
            if case .volatileCore = target.kind {
                let arming = min(1, max(0, target.phase / 2.75))
                let pulse = reducesMotion ? 0 : (sin(target.phase * 13) + 1) * 0.035
                node.setScale(bossMultiplier * CGFloat(1 + arming * 0.14 + pulse))
            } else {
                node.setScale(bossMultiplier)
            }
            if isFrozen {
                node.zRotation = 0
            } else if case .enemy(let enemy) = target.kind, enemy == .tackleBot || enemy == .craterCrawler {
                node.zRotation = 0.08 + CGFloat(sin(target.phase * 8)) * 0.045
            } else {
                node.zRotation = CGFloat(sin(target.phase * 5.5)) * 0.025
            }
            node.zPosition = CGFloat(900 - target.position.y * 700)
            GameNodeFactory.animateTarget(
                on: node,
                kind: target.kind,
                phase: target.phase,
                reducedMotion: reduceMotion,
                frozen: isFrozen
            )
            if case .powerUp = target.kind {
                targetHealthRatios.removeValue(forKey: target.id)
            } else {
                let healthRatio = target.hitPoints / target.maximumHitPoints
                if targetHealthRatios[target.id] != healthRatio {
                    GameNodeFactory.updateHealth(on: node, ratio: healthRatio)
                    targetHealthRatios[target.id] = healthRatio
                }
                GameNodeFactory.updateStatus(on: node, target: target, reducedMotion: reduceMotion)
            }
        }
    }

    private func syncProjectiles(_ projectiles: [ProjectileState]) {
        liveProjectileIDs.removeAll(keepingCapacity: true)
        for projectile in projectiles { liveProjectileIDs.insert(projectile.id) }
        for id in projectileNodes.keys where !liveProjectileIDs.contains(id) {
            if let node = projectileNodes.removeValue(forKey: id) {
                recycleProjectile(node)
            }
        }
        for projectile in projectiles {
            let node = projectileNodes[projectile.id] ?? {
                let newNode = dequeueProjectile(for: projectile)
                projectileLayer.addChild(newNode)
                projectileNodes[projectile.id] = newNode
                return newNode
            }()
            node.position = point(x: projectile.position.x, y: projectile.position.y)
            node.setScale(perspectiveScale(projectile.position.y))
            node.zPosition = CGFloat(950 - projectile.position.y * 700)
            node.zRotation += projectile.hostile ? -0.12 : 0.18
        }
    }

    private func syncCharacterAttacks(_ attacks: [CharacterAttackState]) {
        liveCharacterAttackIDs.removeAll(keepingCapacity: true)
        for attack in attacks { liveCharacterAttackIDs.insert(attack.id) }
        for id in characterAttackNodes.keys where !liveCharacterAttackIDs.contains(id) {
            if let node = characterAttackNodes.removeValue(forKey: id) {
                recycleCharacterAttack(node)
            }
        }

        for attack in attacks {
            let node = characterAttackNodes[attack.id] ?? {
                let newNode = dequeueCharacterAttack(kind: attack.kind)
                characterAttackLayer.addChild(newNode)
                characterAttackNodes[attack.id] = newNode
                return newNode
            }()
            guard attack.delayRemaining <= 0 else {
                node.alpha = 0
                continue
            }

            let progress = CGFloat(attack.progress)
            node.alpha = progress > 0.92 ? max(0, (1 - progress) / 0.08) : 1
            node.position = point(x: attack.position.x, y: attack.position.y)
            switch attack.kind {
            case .meteor:
                node.size = CGSize(width: size.width * 0.17, height: size.width * 0.255)
                node.setScale((0.42 + progress * 0.68) * perspectiveScale(attack.position.y))
                node.zPosition = 3_180
            case .shockwave:
                let trackWidth = CGFloat(attack.width)
                    * size.width
                    * CGFloat(0.43 - 0.22 * attack.position.y)
                let visualWidth = max(76, trackWidth * 1.38)
                node.size = CGSize(width: visualWidth, height: visualWidth * 0.58)
                node.setScale(1)
                node.zPosition = 3_080
            }
        }
    }

    private func syncBossHazards(_ hazards: [BossHazardState]) {
        liveBossHazardIDs.removeAll(keepingCapacity: true)
        for hazard in hazards { liveBossHazardIDs.insert(hazard.id) }
        for id in bossHazardNodes.keys where !liveBossHazardIDs.contains(id) {
            bossHazardNodes.removeValue(forKey: id)?.removeFromParent()
        }

        for hazard in hazards {
            let node = bossHazardNodes[hazard.id] ?? {
                let newNode = SKShapeNode()
                newNode.lineJoin = .round
                newNode.zPosition = 1_450
                bossHazardLayer.addChild(newNode)
                bossHazardNodes[hazard.id] = newNode
                return newNode
            }()
            node.path = bossHazardPath(for: hazard)
            node.position = .zero

            let color = bossHazardColor(for: hazard.kind)
            if hazard.isActive {
                node.fillColor = color.withAlphaComponent(reducedEffects ? 0.38 : 0.62)
                node.strokeColor = .white.withAlphaComponent(0.92)
                node.lineWidth = 3.5
                node.glowWidth = reducedEffects ? 0 : 14
                node.alpha = 1
            } else {
                let progress = CGFloat(hazard.telegraphProgress)
                let pulse = (sin(progress * .pi * 8) + 1) * 0.5
                node.fillColor = color.withAlphaComponent(0.10 + pulse * 0.10)
                node.strokeColor = color.withAlphaComponent(0.58 + pulse * 0.38)
                node.lineWidth = 2 + progress * 2
                node.glowWidth = reducedEffects ? 0 : 3 + progress * 7
                node.alpha = 0.82
            }
        }
    }

    private func bossHazardPath(for hazard: BossHazardState) -> CGPath {
        switch hazard.kind {
        case .meteorStrike:
            let center = point(x: hazard.position.x, y: hazard.position.y)
            let width = max(54, size.width * CGFloat(hazard.halfWidth) * 0.86)
            return CGPath(
                ellipseIn: CGRect(
                    x: center.x - width,
                    y: center.y - width * 0.34,
                    width: width * 2,
                    height: width * 0.68
                ),
                transform: nil
            )
        case .orbitalLaser, .eclipseLane, .lunarDebris:
            let bottomY = 0.02
            let topY = renderedWorldID == .mars ? 0.86 : 0.92
            let bottom = point(x: hazard.position.x, y: bottomY)
            let top = point(x: hazard.position.x, y: topY)
            let bottomHalfWidth = size.width * CGFloat(hazard.halfWidth) * 0.43
            let topHalfWidth = size.width * CGFloat(hazard.halfWidth) * 0.23
            let path = CGMutablePath()
            path.move(to: CGPoint(x: bottom.x - bottomHalfWidth, y: bottom.y))
            path.addLine(to: CGPoint(x: top.x - topHalfWidth, y: top.y))
            path.addLine(to: CGPoint(x: top.x + topHalfWidth, y: top.y))
            path.addLine(to: CGPoint(x: bottom.x + bottomHalfWidth, y: bottom.y))
            path.closeSubpath()
            return path
        }
    }

    private func bossHazardColor(for kind: BossAttackKind) -> SKColor {
        switch kind {
        case .orbitalLaser:
            SKColor(red: 1, green: 0.24, blue: 0.06, alpha: 1)
        case .eclipseLane:
            SKColor(red: 0.70, green: 0.36, blue: 1, alpha: 1)
        case .meteorStrike:
            SKColor(red: 0.20, green: 0.90, blue: 1, alpha: 1)
        case .lunarDebris:
            SKColor(red: 0.76, green: 0.88, blue: 1, alpha: 1)
        }
    }

    private func dequeueCharacterAttack(kind: CharacterAttackKind) -> SKSpriteNode {
        let node: SKSpriteNode
        switch kind {
        case .meteor:
            node = meteorAttackPool.popLast() ?? SKSpriteNode(texture: meteorTexture)
            node.texture = meteorTexture
            node.name = "ability-meteor"
        case .shockwave:
            node = shockwaveAttackPool.popLast() ?? SKSpriteNode(texture: shockwaveTexture)
            node.texture = shockwaveTexture
            node.name = "ability-shockwave"
        }
        node.removeAllActions()
        node.alpha = 0
        node.setScale(1)
        return node
    }

    private func recycleCharacterAttack(_ node: SKSpriteNode) {
        node.removeFromParent()
        node.removeAllActions()
        if node.name == "ability-meteor" {
            if meteorAttackPool.count < 5 { meteorAttackPool.append(node) }
        } else if shockwaveAttackPool.count < 4 {
            shockwaveAttackPool.append(node)
        }
    }

    private func dequeueTarget(for target: TargetState) -> SKNode {
        if var pool = targetNodePools[target.kind], let node = pool.popLast() {
            targetNodePools[target.kind] = pool
            GameNodeFactory.configureTarget(node, target: target, world: renderedWorldID)
            return node
        }
        return GameNodeFactory.target(target, world: renderedWorldID)
    }

    private func recycleTarget(_ node: SKNode, kind: TargetState.Kind) {
        GameNodeFactory.resetStatus(on: node)
        node.removeFromParent()
        var pool = targetNodePools[kind, default: []]
        if pool.count < 12 { pool.append(node) }
        targetNodePools[kind] = pool
    }

    private func dequeueProjectile(for projectile: ProjectileState) -> SKNode {
        let node: SKNode
        if projectile.hostile, let reused = hostileProjectilePool.popLast() {
            node = reused
        } else if !projectile.hostile, let reused = friendlyProjectilePool.popLast() {
            node = reused
        } else {
            node = GameNodeFactory.projectile(hostile: projectile.hostile)
            node.name = projectile.hostile ? "hostile-projectile" : "friendly-projectile"
        }
        node.zRotation = 0
        GameNodeFactory.configureProjectile(
            node,
            hostile: projectile.hostile,
            critical: projectile.isCritical,
            temporaryAbility: projectile.temporaryAbility,
            characterProjectile: projectile.characterProjectile
        )
        return node
    }

    private func recycleProjectile(_ node: SKNode) {
        node.removeFromParent()
        if node.name == "hostile-projectile" {
            if hostileProjectilePool.count < 32 { hostileProjectilePool.append(node) }
        } else if friendlyProjectilePool.count < 64 {
            friendlyProjectilePool.append(node)
        }
    }

    private func point(x: Double, y: Double) -> CGPoint {
        let narrowing = 0.43 - 0.22 * y
        let verticalPosition = renderedWorldID == .mars
            ? 0.08 + y * 0.60
            : 0.10 + y * 0.78
        return CGPoint(
            x: size.width * (0.5 + x * narrowing),
            y: size.height * verticalPosition
        )
    }

    private func perspectiveScale(_ y: Double) -> CGFloat { CGFloat(1.05 - min(max(y, 0), 1) * 0.48) }

    private func handle(_ events: [SimulationEvent]) {
        for event in events {
            switch event {
            case .kick:
                GameNodeFactory.animateKick(on: playerNode, reducedMotion: reducesMotion)
                spawnKickWave()
            case .impact(let position, let damage, let flavor, let critical):
                let location = point(x: position.x, y: position.y)
                spawnImpact(at: location, flavor: flavor, critical: critical)
                spawnDamageNumber(damage, flavor: flavor, critical: critical, at: location)
            case .elementalReaction(let position):
                spawnSteamReaction(at: point(x: position.x, y: position.y))
            case .reward(let value, let position):
                spawnReward(value: value, from: point(x: position.x, y: position.y))
            case .heal(let amount, let position):
                spawnHeal(amount: amount, from: point(x: position.x, y: position.y))
            case .damage:
                showDamageFeedback()
            case .checkpoint:
                showScreenPulse(color: SKColor(red: 1, green: 0.72, blue: 0.10, alpha: 1), strength: 0.38)
            case .abilityChosen:
                spawnAbilityAura()
            case .bossPhase:
                showScreenPulse(color: SKColor(red: 1, green: 0.24, blue: 0.08, alpha: 1), strength: 0.55)
                shake(intensity: 11)
            case .bossAttackTelegraphed(let kind):
                showBossAttackWarning(kind)
            case .bossAttackActivated(let kind, let position):
                activateBossAttackFeedback(kind, at: point(x: position.x, y: position.y))
            case .waveCompleted(let wave):
                showWaveBanner(wave: wave)
                showScreenPulse(color: SKColor(red: 0.18, green: 0.90, blue: 1, alpha: 1), strength: 0.30)
            case .worldTransitioned:
                break
            case .meteorKick:
                showScreenPulse(color: SKColor(red: 1, green: 0.34, blue: 0.08, alpha: 1), strength: 0.22)
                spawnMeteorAura()
            case .comboMilestone(let count):
                showComboPopup(count: count)
            case .worldEffectActivated(let rule, let position):
                showWorldEffect(rule, at: point(x: position.x, y: position.y))
            case .worldEffectImpact(let rule, let position):
                showWorldEffectImpact(rule, at: point(x: position.x, y: position.y))
            case .volatileCoreNeutralized(let position):
                let location = point(x: position.x, y: position.y)
                showComicCallout("CORE SAFE!", at: location, color: SKColor(red: 0.20, green: 0.92, blue: 1, alpha: 1))
                spawnImpact(at: location, flavor: .explosive, critical: true)
            case .volatileCoreDetonated(let position):
                let location = point(x: position.x, y: position.y)
                showComicCallout("CORE BLAST!", at: location, color: SKColor(red: 1, green: 0.24, blue: 0.04, alpha: 1))
                spawnImpact(at: location, flavor: .explosive, critical: true)
                showScreenPulse(color: SKColor(red: 1, green: 0.16, blue: 0.03, alpha: 1), strength: 0.40)
                if !reducedEffects { shake(intensity: 8) }
            case .comboChanged:
                break
            case .temporaryAbilityActivated(let ability, _, let position):
                showTemporaryAbility(ability, at: point(x: position.x, y: position.y))
            case .characterAbilityActivated(let ability):
                showCharacterAbility(ability)
            case .characterAbilityTargets(let ability, let positions):
                showCharacterAbilityTargets(ability, positions: positions)
            case .characterProjectileRicochet(let position):
                spawnPinballRicochet(at: point(x: position.x, y: position.y))
            case .characterMeteorImpact(let position):
                spawnGeneratedMeteorImpact(at: point(x: position.x, y: position.y), y: position.y)
            case .characterShockwaveBurst(let position):
                spawnShockwaveLaunch(at: point(x: position.x, y: position.y))
            case .characterShockwaveHit(let position):
                spawnShockwaveContact(at: point(x: position.x, y: position.y))
            case .finished(let won):
                if won { showScreenPulse(color: SKColor(red: 1, green: 0.78, blue: 0.16, alpha: 1), strength: 0.48) }
            }
        }
    }

    private var reducesMotion: Bool { reducedEffects || UIAccessibility.isReduceMotionEnabled }

    private func showBossAttackWarning(_ kind: BossAttackKind) {
        let text: String
        let color: SKColor
        switch kind {
        case .orbitalLaser:
            text = "ORBITAL LOCK!"
            color = SKColor(red: 1, green: 0.30, blue: 0.06, alpha: 1)
        case .eclipseLane:
            text = "FIND THE SAFE LANE!"
            color = SKColor(red: 0.72, green: 0.42, blue: 1, alpha: 1)
        case .meteorStrike:
            text = "METEOR MARKERS!"
            color = SKColor(red: 0.20, green: 0.90, blue: 1, alpha: 1)
        case .lunarDebris:
            text = "ORBITAL DEBRIS!"
            color = SKColor(red: 0.76, green: 0.88, blue: 1, alpha: 1)
        }
        showComicCallout(text, at: CGPoint(x: size.width * 0.5, y: size.height * 0.62), color: color)
    }

    private func activateBossAttackFeedback(_ kind: BossAttackKind, at position: CGPoint) {
        let color = bossHazardColor(for: kind)
        showScreenPulse(color: color, strength: kind == .meteorStrike ? 0.18 : 0.24)
        if !reducedEffects {
            shake(intensity: kind == .orbitalLaser ? 8 : 5)
        }
        if kind == .meteorStrike || kind == .lunarDebris {
            spawnImpact(at: position, flavor: .explosive, critical: true)
        }
    }

    private func configureTouchGuide() {
        let outer = SKShapeNode(circleOfRadius: 28)
        outer.strokeColor = SKColor(red: 0.20, green: 0.88, blue: 1, alpha: 0.72)
        outer.lineWidth = 2
        outer.fillColor = SKColor(red: 0.08, green: 0.45, blue: 0.90, alpha: 0.13)
        let inner = SKShapeNode(circleOfRadius: 7)
        inner.fillColor = .white.withAlphaComponent(0.85)
        inner.strokeColor = .clear
        touchGuide.addChild(outer)
        touchGuide.addChild(inner)
        touchGuide.zPosition = 4_000
        touchGuide.alpha = 0
    }

    private func hideTouchGuide() {
        touchGuide.run(.group([.fadeOut(withDuration: 0.18), .scale(to: 0.82, duration: 0.18)]))
    }

    private func spawnKickWave() {
        let wave = kickWavePool.popLast() ?? makeKickWave()
        wave.removeAllActions()
        wave.alpha = 1
        wave.setScale(1)
        wave.position = playerNode.position + CGPoint(x: 0, y: 26)
        wave.zPosition = 1_100
        effectsLayer.addChild(wave)
        let duration = reducesMotion ? 0.12 : 0.24
        wave.run(.group([
            .scale(to: reducesMotion ? 1.15 : 2.1, duration: duration),
            .fadeOut(withDuration: duration)
        ])) { [weak self, weak wave] in
            guard let self, let wave else { return }
            wave.removeFromParent()
            if self.kickWavePool.count < 3 { self.kickWavePool.append(wave) }
        }
    }

    private func makeKickWave() -> SKShapeNode {
        let wave = SKShapeNode(ellipseOf: .init(width: 48, height: 18))
        wave.strokeColor = SKColor(red: 0.20, green: 0.84, blue: 1, alpha: 0.75)
        wave.lineWidth = 3
        wave.fillColor = .clear
        return wave
    }

    private func spawnImpact(at position: CGPoint, flavor: DamageFlavor, critical: Bool) {
        let count = critical ? 12 : 7
        let style = impactStyle(for: flavor, critical: critical)
        for index in 0..<count {
            let spark = dequeueImpactSpark(critical: critical)
            spark.path = impactPath(for: flavor, critical: critical)
            spark.fillColor = style.palette[index % style.palette.count]
            spark.strokeColor = style.stroke
            spark.lineWidth = style.lineWidth
            spark.glowWidth = style.glow
            spark.position = position
            spark.zPosition = 2_000
            spark.alpha = 1
            spark.setScale(1)
            effectsLayer.addChild(spark)
            let angle = CGFloat(index) / CGFloat(count) * .pi * 2 + style.angleOffset
            let distance: CGFloat = (critical ? 38 : 24) * style.distanceMultiplier
            let move = SKAction.moveBy(
                x: cos(angle) * distance,
                y: sin(angle) * distance + style.verticalLift,
                duration: reducesMotion ? 0.10 : style.duration
            )
            move.timingMode = .easeOut
            let duration = reducesMotion ? 0.10 : style.duration
            spark.run(.group([
                move,
                .fadeOut(withDuration: duration),
                .scale(to: 0.15, duration: duration)
            ])) { [weak self, weak spark] in
                guard let self, let spark else { return }
                spark.removeFromParent()
                self.recycleImpactSpark(spark, critical: critical)
            }
        }
        if critical {
            let label = criticalLabelPool.popLast() ?? makeCriticalLabel()
            label.removeAllActions()
            label.alpha = 1
            label.position = position + CGPoint(x: 0, y: 22)
            label.zPosition = 2_050
            effectsLayer.addChild(label)
            label.run(.group([.moveBy(x: 0, y: 24, duration: 0.35), .fadeOut(withDuration: 0.35)])) {
                [weak self, weak label] in
                guard let self, let label else { return }
                label.removeFromParent()
                if self.criticalLabelPool.count < 8 { self.criticalLabelPool.append(label) }
            }
        }
    }

    private func makeCriticalLabel() -> SKLabelNode {
        let label = SKLabelNode(text: "CRITICAL")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 13
        label.fontColor = SKColor(red: 1, green: 0.78, blue: 0.12, alpha: 1)
        return label
    }

    private struct ImpactStyle {
        let palette: [SKColor]
        let stroke: SKColor
        let lineWidth: CGFloat
        let glow: CGFloat
        let duration: TimeInterval
        let distanceMultiplier: CGFloat
        let verticalLift: CGFloat
        let angleOffset: CGFloat
    }

    private func impactStyle(for flavor: DamageFlavor, critical: Bool) -> ImpactStyle {
        let gold = SKColor(red: 1, green: 0.76, blue: 0.12, alpha: 1)
        let palette: [SKColor] = switch flavor {
        case .fire:
            [.white, SKColor(red: 1, green: 0.62, blue: 0.04, alpha: 1), SKColor(red: 1, green: 0.14, blue: 0.01, alpha: 1)]
        case .ice:
            [.white, SKColor(red: 0.55, green: 0.94, blue: 1, alpha: 1), SKColor(red: 0.08, green: 0.58, blue: 1, alpha: 1)]
        case .reverse:
            [SKColor(red: 0.25, green: 0.92, blue: 1, alpha: 1), SKColor(red: 0.75, green: 0.16, blue: 1, alpha: 1)]
        case .explosive:
            [.white, gold, SKColor(red: 1, green: 0.18, blue: 0.01, alpha: 1)]
        case .split:
            [.white, SKColor(red: 0.06, green: 0.92, blue: 0.42, alpha: 1)]
        case .standard:
            [.white, SKColor(red: 0.18, green: 0.78, blue: 1, alpha: 1)]
        }
        return ImpactStyle(
            palette: critical ? [gold] + palette : palette,
            stroke: flavor == .reverse ? palette[0] : .clear,
            lineWidth: flavor == .reverse ? 1.8 : 0,
            glow: flavor == .fire || flavor == .explosive ? 2.5 : 0,
            duration: flavor == .fire ? 0.34 : 0.24,
            distanceMultiplier: flavor == .explosive ? 1.35 : 1,
            verticalLift: flavor == .fire ? 11 : 0,
            angleOffset: flavor == .reverse ? .pi * 0.18 : 0
        )
    }

    private func impactPath(for flavor: DamageFlavor, critical: Bool) -> CGPath {
        let radius: CGFloat = critical ? 3.5 : 2.5
        let path = CGMutablePath()
        switch flavor {
        case .ice:
            path.move(to: CGPoint(x: 0, y: radius * 1.7))
            path.addLine(to: CGPoint(x: radius, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -radius * 1.7))
            path.addLine(to: CGPoint(x: -radius, y: 0))
            path.closeSubpath()
        case .fire:
            path.move(to: CGPoint(x: 0, y: radius * 2))
            path.addCurve(
                to: CGPoint(x: 0, y: -radius * 1.2),
                control1: CGPoint(x: radius * 1.6, y: radius * 0.3),
                control2: CGPoint(x: radius, y: -radius * 1.2)
            )
            path.addCurve(
                to: CGPoint(x: 0, y: radius * 2),
                control1: CGPoint(x: -radius, y: -radius * 1.2),
                control2: CGPoint(x: -radius * 1.4, y: radius * 0.2)
            )
            path.closeSubpath()
        case .reverse:
            path.move(to: CGPoint(x: radius * 2.2, y: radius))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: radius * 2.2, y: -radius))
        case .explosive:
            path.move(to: CGPoint(x: 0, y: radius * 1.7))
            path.addLine(to: CGPoint(x: radius * 1.5, y: -radius))
            path.addLine(to: CGPoint(x: -radius * 1.5, y: -radius))
            path.closeSubpath()
        case .standard, .split:
            path.addEllipse(in: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
        }
        return path
    }

    private func spawnSteamReaction(at position: CGPoint) {
        for index in 0..<7 {
            let puff = dequeueImpactSpark(critical: false)
            let radius: CGFloat = 3 + CGFloat(index % 3)
            puff.path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), transform: nil)
            puff.fillColor = SKColor(red: 0.78, green: 0.93, blue: 1, alpha: 0.72)
            puff.strokeColor = .white.withAlphaComponent(0.50)
            puff.lineWidth = 1
            puff.glowWidth = 3
            puff.position = position + CGPoint(x: CGFloat(index - 3) * 3, y: 4)
            puff.zPosition = 2_020
            puff.alpha = 1
            effectsLayer.addChild(puff)
            let duration = reducesMotion ? 0.12 : 0.42 + Double(index) * 0.025
            puff.run(.group([
                .moveBy(x: CGFloat(index - 3) * 2.2, y: 22 + CGFloat(index % 2) * 8, duration: duration),
                .scale(to: 2.1, duration: duration),
                .fadeOut(withDuration: duration)
            ])) { [weak self, weak puff] in
                guard let self, let puff else { return }
                self.recycleImpactSpark(puff, critical: false)
            }
        }
    }

    private func dequeueImpactSpark(critical: Bool) -> SKShapeNode {
        if critical, let spark = criticalImpactPool.popLast() { return spark }
        if !critical, let spark = normalImpactPool.popLast() { return spark }
        return makeImpactSpark(critical: critical)
    }

    private func recycleImpactSpark(_ spark: SKShapeNode, critical: Bool) {
        spark.removeFromParent()
        if critical {
            if criticalImpactPool.count < 12 { criticalImpactPool.append(spark) }
        } else if normalImpactPool.count < 7 {
            normalImpactPool.append(spark)
        }
    }

    private func makeImpactSpark(critical: Bool) -> SKShapeNode {
        SKShapeNode(circleOfRadius: critical ? 3.5 : 2.5)
    }

    private func spawnDamageNumber(
        _ damage: Double,
        flavor: DamageFlavor,
        critical: Bool,
        at position: CGPoint
    ) {
        let container = damageNumberPool.popLast() ?? makeDamageNumber()
        container.removeAllActions()
        container.alpha = 1
        container.position = position + CGPoint(x: critical ? 10 : -7, y: 18)
        container.zPosition = 2_180

        let value = max(1, Int(damage.rounded()))
        let text = critical ? "\(value)!" : "\(value)"
        let fontSize: CGFloat = critical ? 27 : 20
        if let shadow = container.childNode(withName: "damage-shadow") as? SKLabelNode {
            shadow.text = text
            shadow.fontSize = fontSize
        }
        if let label = container.childNode(withName: "damage-value") as? SKLabelNode {
            label.text = text
            label.fontSize = fontSize
            label.fontColor = damageColor(flavor, critical: critical)
        }
        container.setScale(reducesMotion ? 1 : 0.55)
        effectsLayer.addChild(container)

        let rise = SKAction.moveBy(
            x: critical ? 15 : -9,
            y: reducesMotion ? 22 : 48,
            duration: reducesMotion ? 0.26 : 0.62
        )
        rise.timingMode = .easeOut
        container.run(.sequence([
            .group([
                rise,
                .scale(to: critical ? 1.18 : 1, duration: 0.14)
            ]),
            .fadeOut(withDuration: 0.16)
        ])) { [weak self, weak container] in
            guard let self, let container else { return }
            self.recycleDamageNumber(container)
        }
    }

    private func makeDamageNumber() -> SKNode {
        let container = SKNode()
        let shadow = damageLabel(color: .black)
        shadow.name = "damage-shadow"
        shadow.position = CGPoint(x: 2, y: -2)
        shadow.setScale(1.10)
        container.addChild(shadow)

        let label = damageLabel(color: .white)
        label.name = "damage-value"
        container.addChild(label)
        return container
    }

    private func recycleDamageNumber(_ node: SKNode) {
        node.removeFromParent()
        node.removeAllActions()
        if damageNumberPool.count < 24 { damageNumberPool.append(node) }
    }

    private func damageLabel(color: SKColor) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = "0"
        label.fontSize = 20
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        return label
    }

    private func damageColor(_ flavor: DamageFlavor, critical: Bool) -> SKColor {
        if critical { return SKColor(red: 1, green: 0.82, blue: 0.12, alpha: 1) }
        return switch flavor {
        case .standard: .white
        case .explosive: SKColor(red: 1, green: 0.34, blue: 0.06, alpha: 1)
        case .fire: SKColor(red: 1, green: 0.18, blue: 0.04, alpha: 1)
        case .ice: SKColor(red: 0.34, green: 0.90, blue: 1, alpha: 1)
        case .reverse: SKColor(red: 0.82, green: 0.38, blue: 1, alpha: 1)
        case .split: SKColor(red: 0.32, green: 1, blue: 0.54, alpha: 1)
        }
    }

    private func showTemporaryAbility(_ ability: TemporaryBallAbility, at position: CGPoint) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = TemporaryAbilityRules.title(for: ability).uppercased()
        label.fontSize = 16
        label.fontColor = .white
        label.position = position
        label.zPosition = 2_250
        effectsLayer.addChild(label)
        label.run(.sequence([
            .group([
                .moveBy(x: 0, y: reducesMotion ? 24 : 52, duration: reducesMotion ? 0.24 : 0.56),
                .scale(to: reducesMotion ? 1 : 1.14, duration: 0.18)
            ]),
            .fadeOut(withDuration: 0.18),
            .removeFromParent()
        ]))
        spawnAbilityAura()
    }

    private func showWorldEffect(_ rule: WorldRule, at position: CGPoint) {
        switch rule {
        case .lunarCycle:
            showComicCallout("ORBITAL DEBRIS!", at: position, color: SKColor(red: 0.76, green: 0.88, blue: 1, alpha: 1))
        case .volatileCores:
            showComicCallout("CORE ARMED!", at: position, color: SKColor(red: 1, green: 0.46, blue: 0.04, alpha: 1))
        }
    }

    private func showWorldEffectImpact(_ rule: WorldRule, at position: CGPoint) {
        switch rule {
        case .lunarCycle:
            spawnImpact(at: position, flavor: .ice, critical: true)
            showScreenPulse(color: SKColor(red: 0.64, green: 0.78, blue: 1, alpha: 1), strength: 0.20)
            if !reducedEffects { shake(intensity: 5) }
        case .volatileCores:
            break
        }
    }

    private func showComicCallout(_ text: String, at position: CGPoint, color: SKColor) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = 22
        label.fontColor = color
        label.position = position
        label.zPosition = 3_500
        effectsLayer.addChild(label)
        label.run(.sequence([
            .group([
                .moveBy(x: 0, y: reducesMotion ? 22 : 58, duration: reducesMotion ? 0.22 : 0.62),
                .scale(to: reducesMotion ? 1 : 1.18, duration: 0.18)
            ]),
            .fadeOut(withDuration: 0.18),
            .removeFromParent()
        ]))
    }

    private func spawnReward(value: Int, from position: CGPoint) {
        let tokenCount = max(1, value)
        let target = CGPoint(x: size.width * 0.77, y: size.height * 0.90)
        let scatterDuration = reducesMotion ? 0.08 : 0.18
        let pileHold = reducesMotion ? 0.05 : 0.10
        let streamDuration = Self.rewardStreamDuration(for: tokenCount)
            * (reducesMotion ? 0.65 : 1)
        let flightDuration = reducesMotion ? 0.18 : 0.32

        for index in 0..<tokenCount {
            let token = GameNodeFactory.rewardToken()
            token.name = "reward-token"
            token.position = position
            token.zPosition = 2_100 + CGFloat(index % 12)
            token.setScale(reducesMotion ? 0.82 : 0.70)
            effectsLayer.addChild(token)

            let pileOffset = rewardPileOffset(index: index, count: tokenCount)
            let pilePoint = CGPoint(
                x: position.x + pileOffset.x,
                y: position.y + pileOffset.y
            )
            let scatter = SKAction.move(to: pilePoint, duration: scatterDuration)
            scatter.timingMode = .easeOut
            let settle = SKAction.scale(to: 1, duration: scatterDuration)
            settle.timingMode = .easeOut
            let flightDelay = Self.rewardFlightDelay(
                index: index,
                count: tokenCount,
                streamDuration: streamDuration
            )
            let fly = SKAction.move(to: target, duration: flightDuration)
            fly.timingMode = .easeInEaseOut
            let spin = SKAction.rotate(
                byAngle: reducesMotion ? 0 : .pi * 2,
                duration: flightDuration
            )
            let shrink = SKAction.scale(to: 0.64, duration: flightDuration)

            token.run(
                .sequence([
                    .group([scatter, settle]),
                    .wait(forDuration: pileHold + flightDelay),
                    .group([fly, spin, shrink]),
                    .fadeOut(withDuration: 0.06),
                    .removeFromParent()
                ]),
                withKey: "reward-flight"
            )
        }
    }

    static func rewardFlightDelay(
        index: Int,
        count: Int,
        streamDuration: TimeInterval
    ) -> TimeInterval {
        guard count > 1 else { return streamDuration }
        let progress = Double(min(max(index, 0), count - 1)) / Double(count - 1)
        return streamDuration * progress
    }

    static func rewardStreamDuration(for count: Int) -> TimeInterval {
        guard count > 1 else { return 0.12 }
        return min(1.20, 0.12 + 0.085 * sqrt(Double(max(0, count - 2))))
    }

    private func rewardPileOffset(index: Int, count: Int) -> CGPoint {
        let angle = Double(index) * 2.399963229728653
        let fullness = sqrt(Double(index + 1) / Double(max(1, count)))
        let horizontalRadius = 8 + 28 * fullness
        let verticalRadius = 4 + 10 * fullness
        return CGPoint(
            x: cos(angle) * horizontalRadius,
            y: -10 + sin(angle) * verticalRadius
        )
    }

#if DEBUG
    private func showRewardPreviewIfRequested() {
        guard !didShowRewardPreview,
              session.phase == .playing,
              let argumentIndex = ProcessInfo.processInfo.arguments.firstIndex(of: "--reward-preview"),
              ProcessInfo.processInfo.arguments.indices.contains(argumentIndex + 1),
              let value = Int(ProcessInfo.processInfo.arguments[argumentIndex + 1]) else { return }
        didShowRewardPreview = true
        spawnReward(value: value, from: point(x: 0.16, y: 0.53))
    }

    func spawnRewardForTesting(value: Int, from position: CGPoint = .zero) {
        spawnReward(value: value, from: position)
    }

    var rewardTokensForTesting: [SKNode] {
        effectsLayer.children.filter { $0.name == "reward-token" }
    }
#endif

    private func spawnHeal(amount: Double, from position: CGPoint) {
        let label = SKLabelNode(text: "+\(Int(amount)) STAMINA")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 14
        label.fontColor = SKColor(red: 0.20, green: 1, blue: 0.72, alpha: 1)
        label.position = position
        label.zPosition = 2_100
        effectsLayer.addChild(label)
        label.run(.sequence([.group([.moveBy(x: 0, y: 32, duration: 0.42), .fadeOut(withDuration: 0.42)]), .removeFromParent()]))
    }

    private func showDamageFeedback() {
        showScreenPulse(color: .red, strength: 0.34)
        shake(intensity: 7)
    }

    private func showScreenPulse(color: SKColor, strength: CGFloat) {
        let pulse = SKShapeNode(rectOf: size)
        pulse.fillColor = .clear
        pulse.strokeColor = color.withAlphaComponent(strength)
        pulse.lineWidth = 18
        pulse.position = CGPoint(x: size.width / 2, y: size.height / 2)
        pulse.zPosition = 5_000
        addChild(pulse)
        pulse.run(.sequence([.fadeOut(withDuration: reducesMotion ? 0.12 : 0.30), .removeFromParent()]))
    }

    private func shake(intensity: CGFloat) {
        guard !reducesMotion else { return }
        world.removeAction(forKey: "screen-shake")
        world.position = .zero
        world.run(.sequence([
            .moveBy(x: -intensity, y: intensity * 0.35, duration: 0.035),
            .moveBy(x: intensity * 1.7, y: -intensity * 0.7, duration: 0.04),
            .moveBy(x: -intensity * 1.25, y: intensity * 0.45, duration: 0.04),
            .move(to: .zero, duration: 0.06)
        ]), withKey: "screen-shake")
    }

    private func spawnAbilityAura() {
        for index in 0..<3 {
            let ring = SKShapeNode(ellipseOf: .init(width: 48, height: 18))
            ring.strokeColor = SKColor(red: 1, green: 0.75, blue: 0.12, alpha: 0.85)
            ring.lineWidth = 2
            ring.position = playerNode.position
            ring.zPosition = 1_050
            ring.alpha = 1 - CGFloat(index) * 0.2
            effectsLayer.addChild(ring)
            let delay = SKAction.wait(forDuration: Double(index) * 0.08)
            let expand = SKAction.group([.scale(to: 2.4, duration: reducesMotion ? 0.16 : 0.38), .fadeOut(withDuration: reducesMotion ? 0.16 : 0.38)])
            ring.run(.sequence([delay, expand, .removeFromParent()]))
        }
    }

    private func showCharacterAbility(_ ability: CharacterAbility) {
        switch ability {
        case .pinballBlitz:
            spawnPinballLaunch()
            showScreenPulse(color: SKColor(red: 0.10, green: 0.88, blue: 1, alpha: 1), strength: 0.42)
        case .timeBreak:
            showScreenPulse(color: SKColor(red: 0.42, green: 0.92, blue: 1, alpha: 1), strength: 0.55)
            spawnAbilityAura()
        case .meteorVolley:
            showScreenPulse(color: SKColor(red: 1, green: 0.28, blue: 0.08, alpha: 1), strength: 0.58)
            spawnMeteorAura()
            shake(intensity: 9)
        case .lastStand:
            showScreenPulse(color: SKColor(red: 1, green: 0.76, blue: 0.14, alpha: 1), strength: 0.60)
            spawnAbilityAura()
            shake(intensity: 6)
        }
    }

    private func spawnPinballLaunch() {
        for index in 0..<3 {
            let ring = SKShapeNode(circleOfRadius: 13 + CGFloat(index) * 5)
            ring.position = playerNode.position
            ring.zPosition = 3_180
            ring.strokeColor = index.isMultiple(of: 2)
                ? SKColor(red: 0.08, green: 0.92, blue: 1, alpha: 0.95)
                : SKColor(red: 1, green: 0.79, blue: 0.13, alpha: 0.95)
            ring.lineWidth = 3
            ring.glowWidth = 7
            effectsLayer.addChild(ring)
            ring.run(.sequence([
                .wait(forDuration: Double(index) * 0.045),
                .group([
                    .scale(to: reducesMotion ? 1.45 : 2.35, duration: 0.24),
                    .fadeOut(withDuration: 0.24)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func spawnPinballRicochet(at position: CGPoint) {
        let flash = ricochetFlashPool.popLast() ?? makeRicochetFlash()
        flash.removeAllActions()
        flash.position = position
        flash.zPosition = 3_250
        flash.alpha = 1
        flash.setScale(1)
        effectsLayer.addChild(flash)
        flash.run(.group([
            .scale(to: reducesMotion ? 1.5 : 2.7, duration: 0.15),
            .fadeOut(withDuration: 0.15)
        ])) { [weak self, weak flash] in
            guard let self, let flash else { return }
            flash.removeFromParent()
            if self.ricochetFlashPool.count < 12 { self.ricochetFlashPool.append(flash) }
        }
    }

    private func makeRicochetFlash() -> SKShapeNode {
        let flash = SKShapeNode(circleOfRadius: 8)
        flash.fillColor = SKColor(red: 0.12, green: 0.92, blue: 1, alpha: 0.78)
        flash.strokeColor = .white
        flash.lineWidth = 2
        flash.glowWidth = 9
        return flash
    }

    private func showCharacterAbilityTargets(_ ability: CharacterAbility, positions: [Vector2]) {
        switch ability {
        case .pinballBlitz:
            break
        case .timeBreak:
            for position in positions {
                let location = point(x: position.x, y: position.y)
                let crystal = freezeCrystalPool.popLast() ?? makeFreezeCrystal()
                crystal.removeAllActions()
                crystal.position = location
                crystal.zPosition = 3_100
                crystal.alpha = 1
                crystal.setScale(1)
                effectsLayer.addChild(crystal)
                crystal.run(.sequence([
                    .group([.scale(to: 1.35, duration: 0.24), .fadeAlpha(to: 0.72, duration: 0.24)]),
                    .wait(forDuration: 0.28),
                    .fadeOut(withDuration: 0.36)
                ])) { [weak self, weak crystal] in
                    guard let self, let crystal else { return }
                    crystal.removeFromParent()
                    if self.freezeCrystalPool.count < 12 { self.freezeCrystalPool.append(crystal) }
                }
            }
        case .meteorVolley, .lastStand:
            break
        }
    }

    private func makeFreezeCrystal() -> SKShapeNode {
        let crystal = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: -6, y: -22, width: 12, height: 44),
            cornerWidth: 5,
            cornerHeight: 5,
            transform: nil
        ))
        crystal.fillColor = SKColor(red: 0.40, green: 0.92, blue: 1, alpha: 0.28)
        crystal.strokeColor = SKColor(red: 0.78, green: 0.98, blue: 1, alpha: 0.92)
        crystal.lineWidth = 2
        crystal.glowWidth = 7
        return crystal
    }

    private func spawnGeneratedMeteorImpact(at position: CGPoint, y: Double) {
        let blast = meteorImpactPool.popLast() ?? SKSpriteNode(texture: meteorImpactTexture)
        blast.removeAllActions()
        blast.texture = meteorImpactTexture
        let scale = perspectiveScale(y)
        blast.position = position
        blast.size = CGSize(width: size.width * 0.52 * scale, height: size.width * 0.35 * scale)
        blast.zPosition = 3_360
        blast.alpha = 1
        blast.setScale(0.28)
        effectsLayer.addChild(blast)
        blast.run(.sequence([
            .group([
                .scale(to: 1.08, duration: reducesMotion ? 0.08 : 0.13),
                .fadeAlpha(to: 1, duration: 0.05)
            ]),
            .group([
                .scale(to: reducesMotion ? 1.16 : 1.42, duration: reducesMotion ? 0.20 : 0.55),
                .fadeOut(withDuration: reducesMotion ? 0.20 : 0.55)
            ])
        ])) { [weak self, weak blast] in
            guard let self, let blast else { return }
            blast.removeFromParent()
            if self.meteorImpactPool.count < 7 { self.meteorImpactPool.append(blast) }
        }
        showScreenPulse(color: SKColor(red: 1, green: 0.28, blue: 0.03, alpha: 1), strength: 0.22)
        shake(intensity: 8)
    }

    private func spawnShockwaveLaunch(at position: CGPoint) {
        let launch = shockwaveLaunchPool.popLast() ?? makeShockwaveLaunch()
        launch.removeAllActions()
        launch.position = position + CGPoint(x: 0, y: 22)
        launch.zPosition = 3_170
        launch.alpha = 1
        launch.setScale(1)
        effectsLayer.addChild(launch)
        launch.run(.group([
            .scale(to: reducesMotion ? 1.25 : 1.75, duration: 0.16),
            .fadeOut(withDuration: 0.16)
        ])) { [weak self, weak launch] in
            guard let self, let launch else { return }
            launch.removeFromParent()
            if self.shockwaveLaunchPool.count < 5 { self.shockwaveLaunchPool.append(launch) }
        }
    }

    private func spawnShockwaveContact(at position: CGPoint) {
        let contact = shockwaveContactPool.popLast() ?? makeShockwaveContact()
        contact.removeAllActions()
        contact.position = position
        contact.zPosition = 3_290
        contact.alpha = 1
        contact.setScale(1)
        effectsLayer.addChild(contact)
        contact.run(.group([
            .scale(to: reducesMotion ? 1.5 : 2.4, duration: 0.14),
            .fadeOut(withDuration: 0.14)
        ])) { [weak self, weak contact] in
            guard let self, let contact else { return }
            contact.removeFromParent()
            if self.shockwaveContactPool.count < 16 { self.shockwaveContactPool.append(contact) }
        }
    }

    private func makeShockwaveLaunch() -> SKShapeNode {
        let launch = SKShapeNode(ellipseOf: CGSize(width: 70, height: 22))
        launch.strokeColor = SKColor(red: 1, green: 0.82, blue: 0.18, alpha: 0.95)
        launch.lineWidth = 4
        launch.glowWidth = 10
        return launch
    }

    private func makeShockwaveContact() -> SKShapeNode {
        let contact = SKShapeNode(circleOfRadius: 7)
        contact.fillColor = .white.withAlphaComponent(0.88)
        contact.strokeColor = SKColor(red: 0.20, green: 0.92, blue: 1, alpha: 1)
        contact.lineWidth = 3
        contact.glowWidth = 9
        return contact
    }

    private func showWaveBanner(wave: Int) {
        let container = SKNode()
        container.position = CGPoint(x: size.width / 2, y: size.height * 0.58)
        container.zPosition = 4_100

        let backplate = SKShapeNode(rectOf: CGSize(width: min(size.width - 48, 320), height: 64), cornerRadius: 22)
        backplate.fillColor = SKColor(red: 0.02, green: 0.10, blue: 0.22, alpha: 0.90)
        backplate.strokeColor = SKColor(red: 0.18, green: 0.88, blue: 1, alpha: 0.80)
        backplate.lineWidth = 2
        container.addChild(backplate)

        let label = SKLabelNode(text: "WAVE \(wave) CLEARED")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 20
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        container.addChild(label)
        addChild(container)

        let appear = SKAction.group([.fadeIn(withDuration: 0.12), .scale(to: 1, duration: 0.18)])
        container.alpha = 0
        container.setScale(reducesMotion ? 1 : 0.78)
        container.run(.sequence([appear, .wait(forDuration: 0.58), .group([
            .fadeOut(withDuration: 0.20),
            .moveBy(x: 0, y: reducesMotion ? 0 : 18, duration: 0.20)
        ]), .removeFromParent()]))
    }

    private func spawnMeteorAura() {
        let ring = SKShapeNode(circleOfRadius: 31)
        ring.strokeColor = SKColor(red: 1, green: 0.34, blue: 0.05, alpha: 0.95)
        ring.lineWidth = 5
        ring.glowWidth = 14
        ring.position = playerNode.position + CGPoint(x: 0, y: 24)
        ring.zPosition = 1_250
        effectsLayer.addChild(ring)
        ring.run(.sequence([.group([
            .scale(to: reducesMotion ? 1.2 : 2.6, duration: reducesMotion ? 0.12 : 0.28),
            .fadeOut(withDuration: reducesMotion ? 0.12 : 0.28)
        ]), .removeFromParent()]))
    }

    private func showComboPopup(count: Int) {
        guard !reducesMotion else { return }
        let label = SKLabelNode(text: "COMBO ×\(count)")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 30
        label.fontColor = SKColor(red: 1.0, green: 0.72, blue: 0.12, alpha: 1)
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.62)
        label.zPosition = 4_050
        label.setScale(0.4)
        addChild(label)
        label.run(.sequence([
            .group([.scale(to: 1, duration: 0.16), .fadeIn(withDuration: 0.1)]),
            .wait(forDuration: 0.55),
            .fadeOut(withDuration: 0.25),
            .removeFromParent()
        ]))
    }
}

private func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}
