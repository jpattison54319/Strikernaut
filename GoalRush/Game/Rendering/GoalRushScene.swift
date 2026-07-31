import SpriteKit

@MainActor
final class GoalRushScene: SKScene {
    // SpriteKit can retain and tick a scene briefly after SwiftUI replaces the
    // surrounding view. Keep the session alive for exactly as long as the scene
    // can use it so retry/navigation teardown cannot become a use-after-free.
    private let session: GameSessionModel
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
    private var galeBounceNodes: [Int: SKNode] = [:]
    private var galeInterceptorNodes: [Int: SKNode] = [:]
    private var haloRingNodes: [Int: SKNode] = [:]
    private var magneticTrapNodes: [Int: SKNode] = [:]
    private var tidalWaveNodes: [Int: SKSpriteNode] = [:]
    private var galeOrbitNode: SKNode?
    private var bossHazardNodes: [Int: SKShapeNode] = [:]
    private var targetKinds: [Int: TargetState.Kind] = [:]
    private var targetNodePools: [TargetState.Kind: [SKNode]] = [:]
    private var friendlyProjectilePool: [SKNode] = []
    private var hostileProjectilePool: [SKNode] = []
    private var kickWavePool: [SKShapeNode] = []
    private var normalImpactPool: [SKShapeNode] = []
    private var criticalImpactPool: [SKShapeNode] = []
    private var criticalRingPool: [SKShapeNode] = []
    private var damageNumberPool: [SKNode] = []
    private var defeatFragmentPool: [SKSpriteNode] = []
    private var meteorAttackPool: [SKSpriteNode] = []
    private var shockwaveAttackPool: [SKSpriteNode] = []
    private var ricochetFlashPool: [SKShapeNode] = []
    private var freezeCrystalPool: [SKShapeNode] = []
    private var voltArcPool: [SKNode] = []
    private var meteorImpactPool: [SKSpriteNode] = []
    private var shockwaveLaunchPool: [SKShapeNode] = []
    private var shockwaveContactPool: [SKShapeNode] = []
    private var criticalLabelPool: [SKLabelNode] = []
    private var liveTargetIDs = Set<Int>()
    private var liveProjectileIDs = Set<Int>()
    private var liveCharacterAttackIDs = Set<Int>()
    private var liveGaleBounceIDs = Set<Int>()
    private var liveGaleInterceptorIDs = Set<Int>()
    private var liveHaloRingIDs = Set<Int>()
    private var liveMagneticTrapIDs = Set<Int>()
    private var liveTidalWaveIDs = Set<Int>()
    private var liveBossHazardIDs = Set<Int>()
    private var targetHealthRatios: [Int: Double] = [:]
    private var targetShieldRatios: [Int: Double] = [:]
    private var fragmentedTargetIDs = Set<Int>()
    private var configuredSize = CGSize.zero
    private var renderedWorldID: WorldID
    private var lastHandledEventPulse = 0
    private var targetPrewarmQueue: [TargetState.Kind]
    private var targetPrewarmIndex = 0
    private var impactPrewarmIndex = 0
    private let reducedEffects: Bool
    private var isPreparedForRemoval = false
#if DEBUG
    private var didShowRewardPreview = false
#endif
    private lazy var meteorTexture = SKTexture(imageNamed: "AbilityMeteor")
    private lazy var shockwaveTexture = SKTexture(imageNamed: "AbilityShockwave")
    private lazy var meteorImpactTexture = SKTexture(imageNamed: "AbilityMeteorImpact")
    private lazy var galeCrackTexture = SKTexture(imageNamed: "GaleImpactCracks")
    private lazy var magneticTrapTexture = SKTexture(imageNamed: "FluxMagneticTrap")
    private lazy var tidalCrestTexture = SKTexture(imageNamed: "SurgeTidalCrest")
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

    func synchronizePlayback(isPaused shouldPause: Bool) {
        guard !isPreparedForRemoval else { return }
        isPaused = shouldPause
        view?.isPaused = shouldPause
    }

    func prepareForRemoval() {
        isPreparedForRemoval = true
        isPaused = true
        view?.isPaused = true
        eventHandler = nil
    }

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
        } else if impactPrewarmIndex < 63 {
            // A single small node per frame keeps impact feedback allocation-free
            // without concentrating setup work into navigation or gameplay events.
            if impactPrewarmIndex < 19 {
                let critical = impactPrewarmIndex >= 7
                recycleImpactSpark(makeImpactSpark(critical: critical), critical: critical)
            } else if impactPrewarmIndex < 35 {
                recycleDamageNumber(makeDamageNumber())
            } else if impactPrewarmIndex < 59 {
                defeatFragmentPool.append(makeDefeatFragment())
            } else {
                criticalRingPool.append(makeCriticalRing())
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
        syncGaleBounces(snapshot.galeBounces)
        syncGaleInterceptors(snapshot.galeInterceptors)
        syncGaleOrbit(count: snapshot.galeOrbitCount, elapsed: snapshot.elapsed)
        syncHaloRings(snapshot.haloRings)
        syncMagneticTraps(snapshot.magneticTraps, targets: snapshot.targets)
        syncTidalWaves(snapshot.tidalWaves)
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
            targetShieldRatios.removeValue(forKey: id)
        }
        let reduceMotion = reducesMotion
        for target in targets {
            let existingNode = targetNodes[target.id]
            let node = existingNode ?? {
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
            if !isFrozen || existingNode == nil {
                node.position = targetPoint
            }
            let bossMultiplier = scale * CGFloat(CampaignBalance.bossScale(tier: target.bossTier))
            if case .volatileCore = target.kind {
                let arming = min(1, max(0, target.phase / 2.75))
                let pulse = reducesMotion ? 0 : (sin(target.phase * 13) + 1) * 0.035
                node.setScale(bossMultiplier * CGFloat(1 + arming * 0.14 + pulse))
            } else {
                node.setScale(bossMultiplier)
            }
            if !isFrozen || existingNode == nil {
                if case .enemy(let enemy) = target.kind,
                   enemy == .tackleBot || enemy == .craterCrawler {
                    node.zRotation = 0.08 + CGFloat(sin(target.phase * 8)) * 0.045
                } else {
                    node.zRotation = CGFloat(sin(target.phase * 5.5)) * 0.025
                }
            }
            node.zPosition = CGFloat(900 - target.position.y * 700)
            if !isFrozen || existingNode == nil {
                GameNodeFactory.animateTarget(
                    on: node,
                    kind: target.kind,
                    phase: target.phase,
                    reducedMotion: reduceMotion,
                    frozen: isFrozen
                )
            }
            if case .powerUp = target.kind {
                targetHealthRatios.removeValue(forKey: target.id)
            } else {
                let healthRatio = target.hitPoints / target.maximumHitPoints
                if targetHealthRatios[target.id] != healthRatio {
                    GameNodeFactory.updateHealth(on: node, ratio: healthRatio)
                    targetHealthRatios[target.id] = healthRatio
                }
                let shieldRatio = target.shieldHitPoints
                    / max(1, target.maximumShieldHitPoints)
                if targetShieldRatios[target.id] != shieldRatio {
                    GameNodeFactory.updateShield(
                        on: node,
                        ratio: shieldRatio,
                        isActive: target.isShielded,
                        reducedMotion: reduceMotion
                    )
                    targetShieldRatios[target.id] = shieldRatio
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

    private func syncGaleBounces(_ bounces: [GaleBounceState]) {
        liveGaleBounceIDs = Set(bounces.map(\.id))
        for id in galeBounceNodes.keys where !liveGaleBounceIDs.contains(id) {
            galeBounceNodes.removeValue(forKey: id)?.removeFromParent()
        }

        for bounce in bounces {
            let node = galeBounceNodes[bounce.id] ?? {
                let newNode = makeFloatingAbilityBall(
                    temporaryAbility: nil,
                    characterProjectile: .pinballBlitz,
                    shadowColor: SKColor(red: 0.10, green: 0.03, blue: 0, alpha: 0.42)
                )
                projectileLayer.addChild(newNode)
                galeBounceNodes[bounce.id] = newNode
                return newNode
            }()
            let scale = perspectiveScale(bounce.position.y)
            node.position = point(x: bounce.position.x, y: bounce.position.y)
            node.setScale(scale * 1.72)
            node.zPosition = CGFloat(1_060 - bounce.position.y * 520)
            if let ball = node.childNode(withName: "ability-ball") {
                ball.position.y = CGFloat(bounce.visualHeight)
                    * size.height
                    * 0.115
                    / max(scale, 0.01)
                ball.zRotation += reducesMotion ? 0.05 : 0.19
            }
            if let shadow = node.childNode(withName: "ability-shadow") {
                shadow.alpha = 0.42 - CGFloat(bounce.visualHeight) * 0.22
                shadow.xScale = 1 - CGFloat(bounce.visualHeight) * 0.38
            }
        }
    }

    private func syncGaleInterceptors(_ interceptors: [GaleInterceptorState]) {
        liveGaleInterceptorIDs = Set(interceptors.map(\.id))
        for id in galeInterceptorNodes.keys where !liveGaleInterceptorIDs.contains(id) {
            galeInterceptorNodes.removeValue(forKey: id)?.removeFromParent()
        }

        for interceptor in interceptors {
            let node = galeInterceptorNodes[interceptor.id] ?? {
                let newNode = makeFloatingAbilityBall(
                    temporaryAbility: .heatSeeking,
                    characterProjectile: nil,
                    shadowColor: .clear
                )
                projectileLayer.addChild(newNode)
                galeInterceptorNodes[interceptor.id] = newNode
                return newNode
            }()
            node.position = point(
                x: interceptor.position.x,
                y: interceptor.position.y
            )
            node.setScale(perspectiveScale(interceptor.position.y) * 1.08)
            node.zPosition = 3_260
            if let ball = node.childNode(withName: "ability-ball") {
                ball.position.y = sin(CGFloat(interceptor.progress) * .pi) * 34
                ball.zRotation += 0.26
            }
        }
    }

    private func makeFloatingAbilityBall(
        temporaryAbility: TemporaryBallAbility?,
        characterProjectile: CharacterProjectileKind?,
        shadowColor: SKColor
    ) -> SKNode {
        let root = SKNode()
        let shadow = SKShapeNode(ellipseOf: .init(width: 34, height: 10))
        shadow.name = "ability-shadow"
        shadow.fillColor = shadowColor
        shadow.strokeColor = .clear
        shadow.zPosition = -2
        root.addChild(shadow)
        let ball = GameNodeFactory.projectile(hostile: false)
        ball.name = "ability-ball"
        GameNodeFactory.configureProjectile(
            ball,
            hostile: false,
            critical: true,
            temporaryAbility: temporaryAbility,
            characterProjectile: characterProjectile
        )
        root.addChild(ball)
        return root
    }

    private func syncGaleOrbit(count: Int, elapsed: Double) {
        if count == 0 {
            galeOrbitNode?.removeFromParent()
            galeOrbitNode = nil
            return
        }
        if galeOrbitNode?.children.count != count {
            galeOrbitNode?.removeFromParent()
            let orbit = SKNode()
            orbit.name = "gale-orbit"
            for _ in 0..<count {
                let ball = GameNodeFactory.projectile(hostile: false)
                GameNodeFactory.configureProjectile(
                    ball,
                    hostile: false,
                    critical: true,
                    temporaryAbility: .heatSeeking
                )
                ball.setScale(0.72)
                orbit.addChild(ball)
            }
            effectsLayer.addChild(orbit)
            galeOrbitNode = orbit
        }
        guard let orbit = galeOrbitNode else { return }
        orbit.position = playerNode.position + CGPoint(x: 0, y: 18)
        orbit.zPosition = 3_080
        let countValue = max(1, orbit.children.count)
        for (index, ball) in orbit.children.enumerated() {
            let angle = elapsed * 4.2
                + Double(index) / Double(countValue) * .pi * 2
            ball.position = .init(
                x: cos(angle) * 42,
                y: sin(angle) * 14
            )
            ball.zPosition = sin(angle) > 0 ? -1 : 1
            ball.zRotation = angle
        }
    }

    private func syncHaloRings(_ rings: [HaloRingState]) {
        liveHaloRingIDs = Set(rings.map(\.id))
        for id in haloRingNodes.keys where !liveHaloRingIDs.contains(id) {
            haloRingNodes.removeValue(forKey: id)?.removeFromParent()
        }

        for ring in rings {
            let node = haloRingNodes[ring.id] ?? {
                let newNode = SKNode()
                newNode.name = "halo-orbital-crown"
                for _ in 0..<28 {
                    let ball = GameNodeFactory.projectile(hostile: false)
                    GameNodeFactory.configureProjectile(
                        ball,
                        hostile: false,
                        critical: true,
                        temporaryAbility: .ringReturn
                    )
                    ball.setScale(0.68)
                    newNode.addChild(ball)
                }
                characterAttackLayer.addChild(newNode)
                haloRingNodes[ring.id] = newNode
                return newNode
            }()
            node.position = .zero
            node.zPosition = 2_980
            for (index, ball) in node.children.enumerated() {
                let angle = ring.elapsed * 4.4
                    + Double(index) / Double(max(1, node.children.count)) * .pi * 2
                let worldPosition = Vector2(
                    x: ring.center.x + cos(angle) * ring.radius,
                    y: ring.center.y + sin(angle) * ring.radius * 0.58
                )
                ball.position = point(x: worldPosition.x, y: worldPosition.y)
                ball.setScale(perspectiveScale(worldPosition.y) * 0.72)
                ball.zPosition = CGFloat(950 - worldPosition.y * 620)
                ball.zRotation = -angle
            }
        }
    }

    private func syncMagneticTraps(
        _ traps: [MagneticTrapState],
        targets: [TargetState]
    ) {
        liveMagneticTrapIDs = Set(traps.map(\.id))
        for id in magneticTrapNodes.keys where !liveMagneticTrapIDs.contains(id) {
            magneticTrapNodes.removeValue(forKey: id)?.removeFromParent()
        }

        for trap in traps {
            let node = magneticTrapNodes[trap.id] ?? {
                let newNode = makeMagneticTrapNode()
                characterAttackLayer.addChild(newNode)
                magneticTrapNodes[trap.id] = newNode
                return newNode
            }()
            let scale = perspectiveScale(trap.position.y)
            node.position = point(x: trap.position.x, y: trap.position.y)
            node.setScale(scale)
            node.zPosition = CGFloat(1_020 - trap.position.y * 520)
            if !trap.hasLanded {
                node.position.y += sin(CGFloat(trap.flightProgress) * .pi)
                    * size.height
                    * 0.10
                node.zRotation = CGFloat(trap.flightProgress) * .pi * 2
            } else {
                node.zRotation = 0
            }
            let active = trap.captureRemaining > 0
            let snapProgress = active
                ? min(1, CGFloat(3.2 - trap.captureRemaining) / 0.16)
                : 0
            let jawScaleY = 0.54 + snapProgress * 0.58
            let jawSeparation = 6 * (1 - snapProgress)
            if let upperJaw = node.childNode(withName: "trap-upper-jaw") {
                upperJaw.yScale = jawScaleY
                upperJaw.position.y = jawSeparation
                upperJaw.zRotation = active
                    ? sin(CGFloat(trap.captureRemaining) * 17) * 0.025
                    : 0
            }
            if let lowerJaw = node.childNode(withName: "trap-lower-jaw") {
                lowerJaw.yScale = jawScaleY
                lowerJaw.position.y = -jawSeparation
                lowerJaw.zRotation = active
                    ? -sin(CGFloat(trap.captureRemaining) * 17) * 0.025
                    : 0
            }
            if let tether = node.childNode(withName: "trap-tether") as? SKShapeNode {
                if let targetID = trap.targetID,
                   let target = targets.first(where: { $0.id == targetID }),
                   trap.hasLanded {
                    let targetPoint = point(x: target.position.x, y: target.position.y)
                    let localTarget = node.convert(targetPoint, from: world)
                    let path = CGMutablePath()
                    path.move(to: .zero)
                    path.addLine(to: localTarget)
                    tether.path = path
                    tether.alpha = trap.captureRemaining > 0 ? 0.86 : 0.45
                } else {
                    tether.path = nil
                }
            }
        }
    }

    private func makeMagneticTrapNode() -> SKNode {
        let root = SKNode()
        root.name = "magnetic-trap"
        let underlay = SKShapeNode(ellipseOf: .init(width: 82, height: 25))
        underlay.fillColor = SKColor(red: 0.02, green: 0.16, blue: 0.22, alpha: 0.66)
        underlay.strokeColor = SKColor(red: 0.38, green: 1, blue: 0.86, alpha: 0.88)
        underlay.lineWidth = 2
        underlay.glowWidth = 6
        root.addChild(underlay)

        let upperTexture = SKTexture(
            rect: .init(x: 0, y: 0.5, width: 1, height: 0.5),
            in: magneticTrapTexture
        )
        let upperJaw = SKSpriteNode(texture: upperTexture)
        upperJaw.name = "trap-upper-jaw"
        upperJaw.anchorPoint = .init(x: 0.5, y: 0)
        upperJaw.size = .init(width: 92, height: 36)
        upperJaw.position.y = 6
        upperJaw.yScale = 0.54
        upperJaw.zPosition = 2
        root.addChild(upperJaw)

        let lowerTexture = SKTexture(
            rect: .init(x: 0, y: 0, width: 1, height: 0.5),
            in: magneticTrapTexture
        )
        let lowerJaw = SKSpriteNode(texture: lowerTexture)
        lowerJaw.name = "trap-lower-jaw"
        lowerJaw.anchorPoint = .init(x: 0.5, y: 1)
        lowerJaw.size = .init(width: 92, height: 36)
        lowerJaw.position.y = -6
        lowerJaw.yScale = 0.54
        lowerJaw.zPosition = 3
        root.addChild(lowerJaw)

        let tether = SKShapeNode()
        tether.name = "trap-tether"
        tether.strokeColor = SKColor(red: 0.38, green: 1, blue: 0.84, alpha: 0.82)
        tether.lineWidth = 2
        tether.glowWidth = 5
        tether.zPosition = -1
        root.addChild(tether)
        return root
    }

    private func syncTidalWaves(_ waves: [TidalWaveState]) {
        liveTidalWaveIDs = Set(waves.map(\.id))
        for id in tidalWaveNodes.keys where !liveTidalWaveIDs.contains(id) {
            tidalWaveNodes.removeValue(forKey: id)?.removeFromParent()
        }

        for wave in waves where wave.delayRemaining <= 0 {
            let node = tidalWaveNodes[wave.id] ?? {
                let newNode = SKSpriteNode(texture: tidalCrestTexture)
                newNode.name = "surge-tidal-wave"
                newNode.blendMode = .alpha
                characterAttackLayer.addChild(newNode)
                tidalWaveNodes[wave.id] = newNode
                return newNode
            }()
            let center = point(x: wave.centerX, y: wave.positionY)
            let left = point(
                x: wave.centerX - wave.halfWidth,
                y: wave.positionY
            )
            let right = point(
                x: wave.centerX + wave.halfWidth,
                y: wave.positionY
            )
            let laneWidth = max(54, abs(right.x - left.x))
            node.position = center + CGPoint(x: 0, y: laneWidth * 0.28)
            node.size = .init(
                width: laneWidth * 1.12,
                height: laneWidth * 0.72
            )
            node.xScale = 1
            node.yScale = 1
            node.alpha = wave.progress > 0.90
                ? CGFloat(max(0, (1 - wave.progress) / 0.10))
                : 0.96
            node.zPosition = CGFloat(2_820 - wave.positionY * 460)
            node.zRotation = sin(CGFloat(wave.elapsed) * 8) * 0.012
            node.color = wave.round == 3
                ? SKColor(red: 0.20, green: 0.82, blue: 1, alpha: 1)
                : .white
            node.colorBlendFactor = wave.round == 3 ? 0.10 : 0
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
        case .orbitalLaser, .eclipseLane, .lunarDebris, .windRail,
             .ringSegment, .frozenRail, .pressureWall:
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
        case .windRail:
            SKColor(red: 1, green: 0.64, blue: 0.18, alpha: 1)
        case .ringSegment:
            SKColor(red: 0.94, green: 0.82, blue: 0.34, alpha: 1)
        case .frozenRail:
            SKColor(red: 0.34, green: 0.94, blue: 0.84, alpha: 1)
        case .pressureWall:
            SKColor(red: 0.10, green: 0.60, blue: 1, alpha: 1)
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
        (node as? TargetRenderNode)?.resetHitReaction()
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
            endlessEffects: projectile.endlessEffects,
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
        fragmentedTargetIDs.removeAll(keepingCapacity: true)
        for event in events {
            switch event {
            case .kick:
                GameNodeFactory.animateKick(on: playerNode, reducedMotion: reducesMotion)
                spawnKickWave()
            case .impact(let impact):
                let location = point(x: impact.position.x, y: impact.position.y)
                animateTargetImpact(impact)
                spawnImpact(at: location, flavor: impact.flavor, critical: impact.isCritical)
                spawnDamageNumber(
                    impact.damage,
                    flavor: impact.flavor,
                    critical: impact.isCritical,
                    at: location
                )
            case .enemyShieldBroken(let position):
                spawnEnemyShieldPulse(
                    at: point(x: position.x, y: position.y),
                    restored: false
                )
            case .enemyShieldRefreshed(let position):
                spawnEnemyShieldPulse(
                    at: point(x: position.x, y: position.y),
                    restored: true
                )
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
            case .upgradeChosen:
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
            case .characterAbilityEffect(let effect):
                showCharacterAbilityEffect(effect)
            case .specialBallEffect(let effect):
                showSpecialBallEffect(effect)
            case .voltChain(let chain):
                showVoltChain(chain)
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
        case .windRail:
            text = "WIND RAIL!"
            color = SKColor(red: 1, green: 0.64, blue: 0.18, alpha: 1)
        case .ringSegment:
            text = "FIND THE GAP!"
            color = SKColor(red: 0.94, green: 0.82, blue: 0.34, alpha: 1)
        case .frozenRail:
            text = "BRAKE EARLY!"
            color = SKColor(red: 0.34, green: 0.94, blue: 0.84, alpha: 1)
        case .pressureWall:
            text = "FOLLOW THE CHANNEL!"
            color = SKColor(red: 0.10, green: 0.60, blue: 1, alpha: 1)
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
            let ring = criticalRingPool.popLast() ?? makeCriticalRing()
            ring.removeAllActions()
            ring.position = position
            ring.zPosition = 2_030
            ring.strokeColor = impactStyle(for: flavor, critical: true).palette[0]
            ring.alpha = 0.92
            ring.setScale(reducesMotion ? 0.92 : 0.54)
            effectsLayer.addChild(ring)
            let ringDuration = reducesMotion ? 0.10 : 0.22
            ring.run(.group([
                .scale(to: reducesMotion ? 1.16 : 2.25, duration: ringDuration),
                .fadeOut(withDuration: ringDuration)
            ])) { [weak self, weak ring] in
                guard let self, let ring else { return }
                ring.removeFromParent()
                if self.criticalRingPool.count < 4 {
                    self.criticalRingPool.append(ring)
                }
            }

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

    private func animateTargetImpact(_ impact: ImpactEvent) {
        guard let kind = targetKinds[impact.targetID],
              case .enemy = kind,
              let node = targetNodes[impact.targetID] as? TargetRenderNode else {
            return
        }

        if impact.isDefeating {
            guard fragmentedTargetIDs.insert(impact.targetID).inserted else { return }
            spawnDefeatFragments(from: node, impact: impact)
        } else {
            node.playHitReaction(impact, reducedMotion: reducesMotion)
        }

        guard impact.delivery != .damageOverTime,
              impact.isCritical || impact.isDefeating else {
            return
        }
        let intensity: CGFloat
        if node.showsBossHealth {
            intensity = 1.4
        } else if impact.isDefeating {
            intensity = 3.2
        } else {
            intensity = 2.2
        }
        shake(intensity: intensity)
    }

    private func spawnDefeatFragments(from node: TargetRenderNode, impact: ImpactEvent) {
        guard let source = node.bodySprite, let texture = source.texture else { return }

        let isExpandedBurst = impact.isCritical || node.showsBossHealth
        let columns = 2
        let rows = isExpandedBurst ? 3 : 2
        let fragmentCount = reducesMotion ? 1 : columns * rows
        let center = source.convert(CGPoint.zero, to: effectsLayer)
        let xUnit = source.convert(CGPoint(x: 1, y: 0), to: effectsLayer)
        let yUnit = source.convert(CGPoint(x: 0, y: 1), to: effectsLayer)
        let scaleX = hypot(xUnit.x - center.x, xUnit.y - center.y)
        let scaleY = hypot(yUnit.x - center.x, yUnit.y - center.y)
        let rotation = atan2(xUnit.y - center.y, xUnit.x - center.x)
        let tint = fragmentTint(for: impact.flavor)

        for index in 0..<fragmentCount {
            let column = reducesMotion ? 0 : index % columns
            let row = reducesMotion ? 0 : index / columns
            let rect = reducesMotion
                ? CGRect(x: 0, y: 0, width: 1, height: 1)
                : CGRect(
                    x: CGFloat(column) / CGFloat(columns),
                    y: CGFloat(row) / CGFloat(rows),
                    width: 1 / CGFloat(columns),
                    height: 1 / CGFloat(rows)
                )
            let fragment = dequeueDefeatFragment()
            let fragmentTexture = SKTexture(rect: rect, in: texture)
            fragmentTexture.filteringMode = .linear
            fragment.texture = fragmentTexture
            fragment.size = CGSize(
                width: source.size.width * rect.width * scaleX,
                height: source.size.height * rect.height * scaleY
            )
            let localCenter = CGPoint(
                x: (rect.midX - source.anchorPoint.x) * source.size.width,
                y: (rect.midY - source.anchorPoint.y) * source.size.height
            )
            fragment.position = source.convert(localCenter, to: effectsLayer)
            fragment.zRotation = rotation
            fragment.zPosition = 2_040
            fragment.alpha = 1
            fragment.color = tint
            fragment.colorBlendFactor = impact.isCritical ? 0.62 : 0.42
            fragment.setScale(1)
            effectsLayer.addChild(fragment)

            if reducesMotion {
                fragment.run(.group([
                    .scale(to: 1.04, duration: 0.12),
                    .fadeOut(withDuration: 0.12)
                ])) { [weak self, weak fragment] in
                    guard let self, let fragment else { return }
                    self.recycleDefeatFragment(fragment)
                }
                continue
            }

            let outwardX = (CGFloat(column) - CGFloat(columns - 1) * 0.5) * 22
            let outwardY = (CGFloat(row) - CGFloat(rows - 1) * 0.5) * 19
            let impulseDistance: CGFloat = isExpandedBurst ? 18 : 13
            let destination = CGPoint(
                x: outwardX + CGFloat(impact.impulse.x) * impulseDistance,
                y: outwardY + CGFloat(impact.impulse.y) * impulseDistance + 12
            )
            let duration = isExpandedBurst ? 0.29 : 0.24
            let travel = SKAction.moveBy(
                x: destination.x,
                y: destination.y,
                duration: duration
            )
            travel.timingMode = .easeOut
            let spinDirection: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            fragment.run(.group([
                travel,
                .rotate(byAngle: spinDirection * (0.48 + CGFloat(index % 3) * 0.16), duration: duration),
                .scale(to: 0.72, duration: duration),
                .sequence([
                    .wait(forDuration: duration * 0.38),
                    .fadeOut(withDuration: duration * 0.62)
                ])
            ])) { [weak self, weak fragment] in
                guard let self, let fragment else { return }
                self.recycleDefeatFragment(fragment)
            }
        }
    }

    private func fragmentTint(for flavor: DamageFlavor) -> SKColor {
        switch flavor {
        case .fire, .explosive:
            SKColor(red: 1, green: 0.34, blue: 0.05, alpha: 1)
        case .ice:
            SKColor(red: 0.38, green: 0.86, blue: 1, alpha: 1)
        case .reverse:
            SKColor(red: 0.72, green: 0.28, blue: 1, alpha: 1)
        case .split:
            SKColor(red: 0.18, green: 1, blue: 0.54, alpha: 1)
        case .volt:
            SKColor(red: 0.08, green: 0.86, blue: 1, alpha: 1)
        case .standard:
            .white
        }
    }

    private func dequeueDefeatFragment() -> SKSpriteNode {
        defeatFragmentPool.popLast() ?? makeDefeatFragment()
    }

    private func recycleDefeatFragment(_ fragment: SKSpriteNode) {
        fragment.removeAllActions()
        fragment.removeFromParent()
        fragment.texture = nil
        fragment.colorBlendFactor = 0
        fragment.alpha = 1
        fragment.zRotation = 0
        fragment.setScale(1)
        if defeatFragmentPool.count < 24 {
            defeatFragmentPool.append(fragment)
        }
    }

    private func makeDefeatFragment() -> SKSpriteNode {
        let fragment = SKSpriteNode()
        fragment.name = "defeat-fragment"
        fragment.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        return fragment
    }

    private func makeCriticalLabel() -> SKLabelNode {
        let label = SKLabelNode(text: "CRITICAL")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 13
        label.fontColor = SKColor(red: 1, green: 0.78, blue: 0.12, alpha: 1)
        return label
    }

    private func makeCriticalRing() -> SKShapeNode {
        let ring = SKShapeNode(circleOfRadius: 14)
        ring.name = "critical-impact-ring"
        ring.fillColor = .clear
        ring.strokeColor = .white
        ring.lineWidth = 3
        ring.glowWidth = 6
        return ring
    }

    private func showSpecialBallEffect(_ effect: SpecialBallEffectEvent) {
        switch effect {
        case .gravityVortex(let position, let radius):
            spawnGravityVortex(
                at: point(x: position.x, y: position.y),
                radius: radius
            )
        case .magnetMark(let position, _):
            spawnMagnetMark(at: point(x: position.x, y: position.y))
        case .orbitRedirect(let position):
            spawnOrbitRedirect(at: point(x: position.x, y: position.y))
        case .returnShot(let position):
            spawnReturnArc(at: point(x: position.x, y: position.y))
        case .solarPierce(let position):
            spawnSolarPierce(at: point(x: position.x, y: position.y))
        case .tidalPush(let position):
            spawnTidalSplash(at: point(x: position.x, y: position.y))
        }
    }

    private func spawnGravityVortex(at position: CGPoint, radius: Double) {
        let root = SKNode()
        root.name = "gravity-vortex-effect"
        root.position = position
        root.zPosition = 2_180
        effectsLayer.addChild(root)

        let renderedRadius = max(34, size.width * CGFloat(radius) * 0.42)
        for index in 0..<3 {
            let ring = SKShapeNode(
                ellipseOf: .init(
                    width: renderedRadius * 2,
                    height: renderedRadius * 0.72
                )
            )
            ring.fillColor = SKColor(
                red: 0.35,
                green: 0.04,
                blue: 0.64,
                alpha: 0.10
            )
            ring.strokeColor = index.isMultiple(of: 2)
                ? SKColor(red: 0.82, green: 0.34, blue: 1, alpha: 0.95)
                : .white.withAlphaComponent(0.88)
            ring.lineWidth = 2.5
            ring.glowWidth = reducesMotion ? 2 : 8
            ring.zRotation = CGFloat(index) * 0.34
            ring.setScale(1.30 + CGFloat(index) * 0.22)
            root.addChild(ring)
            ring.run(.sequence([
                .wait(forDuration: Double(index) * 0.035),
                .group([
                    .scale(to: 0.18, duration: reducesMotion ? 0.18 : 0.46),
                    .rotate(
                        byAngle: reducesMotion ? 0 : .pi * 1.4,
                        duration: reducesMotion ? 0.18 : 0.46
                    ),
                    .fadeOut(withDuration: reducesMotion ? 0.18 : 0.46),
                ]),
            ]))
        }
        root.run(.sequence([
            .wait(forDuration: reducesMotion ? 0.24 : 0.58),
            .removeFromParent(),
        ]))
    }

    private func spawnMagnetMark(at position: CGPoint) {
        let root = SKNode()
        root.name = "magnet-mark-effect"
        root.position = position
        root.zPosition = 2_200
        effectsLayer.addChild(root)

        let ring = SKShapeNode(ellipseOf: .init(width: 68, height: 28))
        ring.fillColor = SKColor(red: 0.06, green: 0.52, blue: 0.48, alpha: 0.14)
        ring.strokeColor = SKColor(red: 0.20, green: 1, blue: 0.82, alpha: 0.96)
        ring.lineWidth = 3
        ring.glowWidth = reducesMotion ? 2 : 9
        root.addChild(ring)
        let poles: [(CGFloat, SKColor)] = [
            (-34.0, SKColor(red: 0.08, green: 0.72, blue: 1, alpha: 1)),
            (34.0, SKColor(red: 1, green: 0.18, blue: 0.62, alpha: 1)),
        ]
        for (x, color) in poles {
            let pole = SKShapeNode(circleOfRadius: 5)
            pole.position.x = x
            pole.fillColor = color
            pole.strokeColor = .white
            pole.lineWidth = 1.5
            pole.glowWidth = 5
            root.addChild(pole)
        }
        root.setScale(0.46)
        root.run(.sequence([
            .group([
                .scale(to: 1.12, duration: reducesMotion ? 0.10 : 0.18),
                .fadeIn(withDuration: 0.08),
            ]),
            .scale(to: 1, duration: 0.10),
            .wait(forDuration: reducesMotion ? 0.08 : 0.20),
            .group([
                .scale(to: 1.28, duration: 0.16),
                .fadeOut(withDuration: 0.16),
            ]),
            .removeFromParent(),
        ]))
    }

    private func spawnReturnArc(at position: CGPoint) {
        let path = CGMutablePath()
        path.addArc(
            center: .zero,
            radius: 25,
            startAngle: .pi * 0.18,
            endAngle: .pi * 1.82,
            clockwise: false
        )
        let arc = SKShapeNode(path: path)
        arc.name = "return-shot-effect"
        arc.position = position
        arc.zPosition = 2_190
        arc.fillColor = .clear
        arc.strokeColor = SKColor(red: 1, green: 0.76, blue: 0.12, alpha: 1)
        arc.lineWidth = 4
        arc.glowWidth = reducesMotion ? 2 : 9
        effectsLayer.addChild(arc)

        let arrow = SKLabelNode(text: "➤")
        arrow.fontName = "AvenirNext-Heavy"
        arrow.fontSize = 18
        arrow.fontColor = .white
        arrow.position = .init(x: -25, y: -8)
        arrow.zRotation = -.pi * 0.58
        arc.addChild(arrow)
        arc.setScale(0.70)
        arc.run(.sequence([
            .group([
                .scale(to: 1.20, duration: reducesMotion ? 0.12 : 0.28),
                .rotate(
                    byAngle: reducesMotion ? 0 : .pi * 0.70,
                    duration: reducesMotion ? 0.12 : 0.28
                ),
            ]),
            .group([
                .scale(to: 1.38, duration: 0.16),
                .fadeOut(withDuration: 0.16),
            ]),
            .removeFromParent(),
        ]))
    }

    private func spawnOrbitRedirect(at position: CGPoint) {
        let root = SKNode()
        root.name = "orbit-redirect-effect"
        root.position = position
        root.zPosition = 2_190
        effectsLayer.addChild(root)

        for index in 0..<2 {
            let ring = SKShapeNode(
                ellipseOf: .init(
                    width: 54 + CGFloat(index) * 16,
                    height: 22 + CGFloat(index) * 8
                )
            )
            ring.fillColor = .clear
            ring.strokeColor = index == 0
                ? SKColor(red: 0.62, green: 0.42, blue: 1, alpha: 0.96)
                : .white.withAlphaComponent(0.88)
            ring.lineWidth = 3
            ring.glowWidth = reducesMotion ? 2 : 8
            ring.zRotation = CGFloat(index) * .pi * 0.34
            root.addChild(ring)
        }

        root.setScale(0.62)
        root.run(.sequence([
            .group([
                .scale(to: 1.22, duration: reducesMotion ? 0.12 : 0.26),
                .rotate(
                    byAngle: reducesMotion ? 0 : .pi * 0.72,
                    duration: reducesMotion ? 0.12 : 0.26
                ),
            ]),
            .group([
                .scale(to: 1.42, duration: 0.14),
                .fadeOut(withDuration: 0.14),
            ]),
            .removeFromParent(),
        ]))
    }

    private func spawnSolarPierce(at position: CGPoint) {
        let root = SKNode()
        root.name = "solar-pierce-effect"
        root.position = position
        root.zPosition = 2_205
        effectsLayer.addChild(root)

        let core = SKShapeNode(circleOfRadius: 8)
        core.fillColor = .white
        core.strokeColor = SKColor(red: 1, green: 0.72, blue: 0.08, alpha: 1)
        core.lineWidth = 3
        core.glowWidth = reducesMotion ? 2 : 10
        root.addChild(core)

        for index in 0..<8 {
            let ray = SKShapeNode(
                rectOf: .init(width: 3, height: 18),
                cornerRadius: 1.5
            )
            ray.position.y = 18
            ray.zRotation = CGFloat(index) * .pi / 4
            ray.fillColor = index.isMultiple(of: 2)
                ? .white
                : SKColor(red: 1, green: 0.60, blue: 0.04, alpha: 1)
            ray.strokeColor = .clear
            root.addChild(ray)
        }

        root.setScale(0.54)
        root.run(.sequence([
            .group([
                .scale(to: 1.34, duration: reducesMotion ? 0.10 : 0.20),
                .rotate(
                    byAngle: reducesMotion ? 0 : .pi * 0.24,
                    duration: reducesMotion ? 0.10 : 0.20
                ),
            ]),
            .group([
                .scale(to: 1.62, duration: 0.14),
                .fadeOut(withDuration: 0.14),
            ]),
            .removeFromParent(),
        ]))
    }

    private func showVoltChain(_ chain: VoltChainEvent) {
        spawnVoltOriginPulse(at: point(x: chain.origin.x, y: chain.origin.y))
        for arc in chain.arcs {
            let delay = reducesMotion ? 0 : Double(max(0, arc.generation - 1)) * 0.07
            spawnVoltArc(
                arc,
                seed: UInt64(max(1, chain.originTargetID &* 1_009 + arc.recipientOrder)),
                delay: delay
            )
            effectsLayer.run(.sequence([
                .wait(forDuration: delay),
                .run { [weak self] in
                    guard let self else { return }
                    let destination = self.point(
                        x: arc.destination.x,
                        y: arc.destination.y
                    )
                    self.spawnVoltCorona(at: destination, defeating: arc.isDefeating)
                    self.spawnDamageNumber(
                        arc.damage,
                        flavor: .volt,
                        critical: false,
                        at: destination
                    )
                }
            ]))
        }
    }

    private func spawnVoltArc(_ arc: VoltArc, seed: UInt64, delay: TimeInterval) {
        let node = voltArcPool.popLast() ?? makeVoltArcNode()
        node.removeAllActions()
        node.alpha = 0
        node.zPosition = 2_110
        effectsLayer.addChild(node)

        let source = point(x: arc.source.x, y: arc.source.y)
        let destination = point(x: arc.destination.x, y: arc.destination.y)
        updateVoltArcPath(node, from: source, to: destination, seed: seed)
        let activeDuration = reducesMotion ? 0.12 : 0.30
        let animate = SKAction.customAction(withDuration: activeDuration) { [weak self, weak node] _, elapsed in
            guard let self, let node else { return }
            if self.reducesMotion {
                node.alpha = 0.72
                return
            }
            let phase = UInt64(max(0, Int(elapsed * 42)))
            self.updateVoltArcPath(
                node,
                from: source,
                to: destination,
                seed: seed &+ phase &* 7_919
            )
            node.alpha = phase.isMultiple(of: 3) ? 0.72 : 1
        }
        node.run(.sequence([
            .wait(forDuration: delay),
            .run { node.alpha = 1 },
            animate,
            .fadeOut(withDuration: reducesMotion ? 0.06 : 0.10)
        ])) { [weak self, weak node] in
            guard let self, let node else { return }
            node.removeFromParent()
            node.alpha = 1
            if self.voltArcPool.count < 48 {
                self.voltArcPool.append(node)
            }
        }
    }

    private func makeVoltArcNode() -> SKNode {
        let node = SKNode()
        node.name = "volt-arc"

        let glow = SKShapeNode()
        glow.name = "volt-glow"
        glow.strokeColor = SKColor(red: 0.05, green: 0.58, blue: 1, alpha: 0.52)
        glow.lineWidth = 9
        glow.glowWidth = 13
        glow.lineCap = .round
        node.addChild(glow)

        let body = SKShapeNode()
        body.name = "volt-body"
        body.strokeColor = SKColor(red: 0.06, green: 0.88, blue: 1, alpha: 0.95)
        body.lineWidth = 4
        body.glowWidth = 5
        body.lineCap = .round
        node.addChild(body)

        let core = SKShapeNode()
        core.name = "volt-core"
        core.strokeColor = .white
        core.lineWidth = 1.35
        core.lineCap = .round
        node.addChild(core)
        return node
    }

    private func updateVoltArcPath(
        _ node: SKNode,
        from source: CGPoint,
        to destination: CGPoint,
        seed: UInt64
    ) {
        let path = voltPath(from: source, to: destination, seed: seed)
        for name in ["volt-glow", "volt-body", "volt-core"] {
            (node.childNode(withName: name) as? SKShapeNode)?.path = path
        }
    }

    private func voltPath(from source: CGPoint, to destination: CGPoint, seed: UInt64) -> CGPath {
        let dx = destination.x - source.x
        let dy = destination.y - source.y
        let length = max(1, hypot(dx, dy))
        let segmentCount = max(5, min(13, Int(length / 24)))
        let normal = CGPoint(x: -dy / length, y: dx / length)
        let amplitude = min(14, max(5, length * 0.075))
        var generator = SeededGenerator(seed: seed)
        let path = CGMutablePath()
        path.move(to: source)
        for segment in 1..<segmentCount {
            let progress = CGFloat(segment) / CGFloat(segmentCount)
            let envelope = sin(progress * .pi)
            let jitter = CGFloat(generator.unit() * 2 - 1) * amplitude * envelope
            path.addLine(to: CGPoint(
                x: source.x + dx * progress + normal.x * jitter,
                y: source.y + dy * progress + normal.y * jitter
            ))
        }
        path.addLine(to: destination)
        return path
    }

    private func spawnVoltOriginPulse(at position: CGPoint) {
        let pulse = SKShapeNode(circleOfRadius: 12)
        pulse.position = position
        pulse.zPosition = 2_105
        pulse.fillColor = SKColor(red: 0.08, green: 0.75, blue: 1, alpha: 0.20)
        pulse.strokeColor = .white
        pulse.lineWidth = 2
        pulse.glowWidth = reducesMotion ? 2 : 9
        effectsLayer.addChild(pulse)
        pulse.run(.sequence([
            .group([
                .scale(to: reducesMotion ? 1.25 : 2.2, duration: reducesMotion ? 0.12 : 0.25),
                .fadeOut(withDuration: reducesMotion ? 0.12 : 0.25)
            ]),
            .removeFromParent()
        ]))
    }

    private func spawnVoltCorona(at position: CGPoint, defeating: Bool) {
        let corona = SKShapeNode(circleOfRadius: defeating ? 18 : 14)
        corona.position = position
        corona.zPosition = 2_140
        corona.fillColor = .clear
        corona.strokeColor = SKColor(red: 0.22, green: 0.92, blue: 1, alpha: 0.95)
        corona.lineWidth = 2.5
        corona.glowWidth = reducesMotion ? 2 : 8
        effectsLayer.addChild(corona)
        corona.run(.sequence([
            .group([
                .scale(to: reducesMotion ? 1.12 : 1.65, duration: reducesMotion ? 0.10 : 0.20),
                .fadeOut(withDuration: reducesMotion ? 0.10 : 0.20)
            ]),
            .removeFromParent()
        ]))
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
        case .volt:
            [.white, SKColor(red: 0.12, green: 0.88, blue: 1, alpha: 1), SKColor(red: 0.18, green: 0.34, blue: 1, alpha: 1)]
        case .standard:
            [.white, SKColor(red: 0.18, green: 0.78, blue: 1, alpha: 1)]
        }
        return ImpactStyle(
            palette: critical ? [gold] + palette : palette,
            stroke: flavor == .reverse ? palette[0] : .clear,
            lineWidth: flavor == .reverse ? 1.8 : 0,
            glow: flavor == .fire || flavor == .explosive || flavor == .volt ? 2.5 : 0,
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
        case .volt:
            path.move(to: CGPoint(x: -radius * 1.8, y: radius * 1.8))
            path.addLine(to: CGPoint(x: radius * 0.2, y: radius * 0.35))
            path.addLine(to: CGPoint(x: -radius * 0.35, y: radius * 0.25))
            path.addLine(to: CGPoint(x: radius * 1.8, y: -radius * 1.8))
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
        let compactValue = GameNumberFormatter.compact(value)
        let text = critical ? "\(compactValue)!" : compactValue
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
        case .volt: SKColor(red: 0.24, green: 0.92, blue: 1, alpha: 1)
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
        case .windShear:
            showComicCallout("WIND SHEAR!", at: position, color: SKColor(red: 1, green: 0.70, blue: 0.24, alpha: 1))
        case .ringSweep:
            showComicCallout("FIND THE GAP!", at: position, color: SKColor(red: 1, green: 0.84, blue: 0.36, alpha: 1))
        case .cryoDrift:
            showComicCallout("CRYO DRIFT!", at: position, color: SKColor(red: 0.38, green: 0.94, blue: 0.88, alpha: 1))
        case .pressureTide:
            showComicCallout("PRESSURE TIDE!", at: position, color: SKColor(red: 0.12, green: 0.72, blue: 1, alpha: 1))
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
        case .windShear:
            showScreenPulse(color: SKColor(red: 1, green: 0.64, blue: 0.18, alpha: 1), strength: 0.18)
        case .ringSweep:
            showScreenPulse(color: SKColor(red: 0.92, green: 0.78, blue: 0.32, alpha: 1), strength: 0.22)
        case .cryoDrift:
            showScreenPulse(color: SKColor(red: 0.34, green: 0.92, blue: 0.84, alpha: 1), strength: 0.18)
        case .pressureTide:
            showScreenPulse(color: SKColor(red: 0.08, green: 0.56, blue: 0.94, alpha: 1), strength: 0.24)
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

    func handleImpactForTesting(_ impact: ImpactEvent, target: TargetState) {
        if world.parent == nil {
            addChild(world)
        }
        if targetLayer.parent == nil {
            world.addChild(targetLayer)
        }
        if effectsLayer.parent == nil {
            world.addChild(effectsLayer)
        }
        let node = GameNodeFactory.target(target, world: renderedWorldID)
        node.position = point(x: target.position.x, y: target.position.y)
        node.setScale(perspectiveScale(target.position.y))
        targetLayer.addChild(node)
        targetNodes[target.id] = node
        targetKinds[target.id] = target.kind
        handle([.impact(impact)])
    }

    var defeatFragmentsForTesting: [SKSpriteNode] {
        effectsLayer.children.compactMap { node in
            guard node.name == "defeat-fragment" else { return nil }
            return node as? SKSpriteNode
        }
    }

    var hasImpactCameraKickForTesting: Bool {
        world.action(forKey: "screen-shake") != nil
    }

    var criticalImpactRingsForTesting: [SKNode] {
        effectsLayer.children.filter { $0.name == "critical-impact-ring" }
    }

    func handleVoltChainForTesting(_ chain: VoltChainEvent) {
        if world.parent == nil {
            addChild(world)
        }
        if effectsLayer.parent == nil {
            world.addChild(effectsLayer)
        }
        handle([.voltChain(chain)])
    }

    var voltArcsForTesting: [SKNode] {
        effectsLayer.children.filter { $0.name == "volt-arc" }
    }
#endif

    private func spawnHeal(amount: Double, from position: CGPoint) {
        let label = SKLabelNode(
            text: "+\(GameNumberFormatter.compact(Int(amount))) STAMINA"
        )
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 14
        label.fontColor = SKColor(red: 0.20, green: 1, blue: 0.72, alpha: 1)
        label.position = position
        label.zPosition = 2_100
        effectsLayer.addChild(label)
        label.run(.sequence([.group([.moveBy(x: 0, y: 32, duration: 0.42), .fadeOut(withDuration: 0.42)]), .removeFromParent()]))
    }

    private func spawnEnemyShieldPulse(at position: CGPoint, restored: Bool) {
        let ring = SKShapeNode(ellipseOf: .init(width: 58, height: 72))
        ring.name = restored ? "enemy-shield-refresh" : "enemy-shield-break"
        ring.position = position
        ring.zPosition = 2_060
        ring.fillColor = SKColor(red: 0.08, green: 0.72, blue: 1, alpha: 0.14)
        ring.strokeColor = SKColor(red: 0.24, green: 0.92, blue: 1, alpha: 0.96)
        ring.lineWidth = restored ? 3 : 2
        ring.glowWidth = 4
        effectsLayer.addChild(ring)
        let duration = reducesMotion ? 0.14 : 0.34
        let scale: CGFloat = restored ? 1.28 : 1.65
        ring.run(.sequence([
            .group([
                .scale(to: scale, duration: duration),
                .fadeOut(withDuration: duration),
            ]),
            .removeFromParent(),
        ]))
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
        showUltimateCinematic(ability)
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
        case .stormbreak:
            showScreenPulse(color: SKColor(red: 1, green: 0.66, blue: 0.18, alpha: 1), strength: 0.48)
            spawnGaleLaunch()
        case .ringRelay:
            showScreenPulse(color: SKColor(red: 0.94, green: 0.82, blue: 0.36, alpha: 1), strength: 0.48)
            spawnAbilityAura()
        case .poleShift:
            showScreenPulse(color: SKColor(red: 0.34, green: 0.94, blue: 0.82, alpha: 1), strength: 0.50)
            spawnAbilityAura()
        case .tidalBreak:
            showScreenPulse(color: SKColor(red: 0.10, green: 0.66, blue: 1, alpha: 1), strength: 0.58)
            spawnAbilityAura()
            shake(intensity: 7)
        }
    }

    private func showUltimateCinematic(_ ability: CharacterAbility) {
        let color: SKColor = switch ability {
        case .pinballBlitz:
            SKColor(red: 0.10, green: 0.88, blue: 1, alpha: 1)
        case .timeBreak:
            SKColor(red: 0.42, green: 0.92, blue: 1, alpha: 1)
        case .meteorVolley:
            SKColor(red: 1, green: 0.28, blue: 0.08, alpha: 1)
        case .lastStand:
            SKColor(red: 1, green: 0.76, blue: 0.14, alpha: 1)
        case .stormbreak:
            SKColor(red: 1, green: 0.66, blue: 0.18, alpha: 1)
        case .ringRelay:
            SKColor(red: 0.94, green: 0.82, blue: 0.36, alpha: 1)
        case .poleShift:
            SKColor(red: 0.34, green: 0.94, blue: 0.82, alpha: 1)
        case .tidalBreak:
            SKColor(red: 0.10, green: 0.66, blue: 1, alpha: 1)
        }

        if let body = playerNode.childNode(withName: "body") {
            body.removeAction(forKey: "ultimate-cast")
            body.run(.sequence([
                .group([
                    .scale(to: reducesMotion ? 1.04 : 1.18, duration: 0.08),
                    .moveBy(x: 0, y: reducesMotion ? 2 : 9, duration: 0.08),
                ]),
                .group([
                    .scale(to: 1, duration: reducesMotion ? 0.12 : 0.28),
                    .moveBy(x: 0, y: reducesMotion ? -2 : -9, duration: reducesMotion ? 0.12 : 0.28),
                ]),
            ]), withKey: "ultimate-cast")
        }

        let groundSeal = SKShapeNode(
            ellipseOf: .init(width: size.width * 0.42, height: size.width * 0.105)
        )
        groundSeal.position = point(x: session.snapshot.playerX, y: 0.12)
        groundSeal.zPosition = 2_960
        groundSeal.fillColor = color.withAlphaComponent(0.12)
        groundSeal.strokeColor = .white.withAlphaComponent(0.92)
        groundSeal.lineWidth = 3
        groundSeal.glowWidth = reducesMotion ? 2 : 12
        effectsLayer.addChild(groundSeal)
        groundSeal.run(.sequence([
            .group([
                .scale(to: reducesMotion ? 1.16 : 1.72, duration: reducesMotion ? 0.14 : 0.34),
                .fadeOut(withDuration: reducesMotion ? 0.14 : 0.34),
            ]),
            .removeFromParent(),
        ]))

        guard !reducesMotion else { return }
        let wash = SKShapeNode(rectOf: size)
        wash.position = .init(x: size.width * 0.5, y: size.height * 0.5)
        wash.zPosition = 3_360
        wash.fillColor = color.withAlphaComponent(0.13)
        wash.strokeColor = .clear
        wash.alpha = 0
        effectsLayer.addChild(wash)
        wash.run(.sequence([
            .fadeAlpha(to: 1, duration: 0.045),
            .wait(forDuration: 0.08),
            .fadeOut(withDuration: 0.18),
            .removeFromParent(),
        ]))

        let portrait = GameNodeFactory.player(
            character: session.character.id,
            presentation: .roster
        )
        portrait.position = .init(
            x: size.width * 0.14,
            y: size.height * 0.40
        )
        portrait.zPosition = 3_380
        portrait.alpha = 0
        portrait.setScale(1.28)
        effectsLayer.addChild(portrait)
        portrait.run(.sequence([
            .group([
                .fadeIn(withDuration: 0.055),
                .moveBy(x: size.width * 0.07, y: 0, duration: 0.055),
            ]),
            .wait(forDuration: 0.10),
            .group([
                .moveBy(x: size.width * 0.12, y: 0, duration: 0.19),
                .fadeOut(withDuration: 0.19),
                .scale(to: 1.42, duration: 0.19),
            ]),
            .removeFromParent(),
        ]))
    }

    private func spawnGaleLaunch() {
        let origin = point(x: session.snapshot.playerX, y: 0.18)
        for (index, destinationX) in [-0.72, -0.36, 0, 0.36, 0.72].enumerated() {
            let path = CGMutablePath()
            path.move(to: origin)
            let destination = point(x: destinationX, y: 0.38)
            path.addQuadCurve(
                to: destination,
                control: .init(
                    x: (origin.x + destination.x) * 0.5,
                    y: max(origin.y, destination.y) + size.height * 0.09
                )
            )
            let streak = SKShapeNode(path: path)
            streak.zPosition = 3_160
            streak.strokeColor = index.isMultiple(of: 2)
                ? SKColor(red: 1, green: 0.80, blue: 0.18, alpha: 0.92)
                : .white.withAlphaComponent(0.92)
            streak.lineWidth = 6
            streak.glowWidth = reducesMotion ? 2 : 10
            streak.alpha = 0
            effectsLayer.addChild(streak)
            streak.run(.sequence([
                .wait(forDuration: Double(index) * 0.025),
                .fadeIn(withDuration: 0.035),
                .fadeOut(withDuration: reducesMotion ? 0.12 : 0.24),
                .removeFromParent(),
            ]))
        }
    }

    private func showCharacterAbilityEffect(_ effect: CharacterAbilityEffect) {
        switch effect {
        case .timeShatter(let positions):
            showScreenPulse(
                color: SKColor(red: 0.72, green: 0.96, blue: 1, alpha: 1),
                strength: 0.58
            )
            for position in positions.prefix(14) {
                spawnImpact(
                    at: point(x: position.x, y: position.y),
                    flavor: .ice,
                    critical: true
                )
            }
            if !reducesMotion { shake(intensity: 8) }
        case .galeLanding(let position, let variant):
            spawnGaleCrack(at: position, variant: variant)
            spawnImpact(
                at: point(x: position.x, y: position.y),
                flavor: .explosive,
                critical: true
            )
            if !reducesMotion { shake(intensity: 4) }
        case .galeInterception(let position):
            let location = point(x: position.x, y: position.y)
            spawnPinballRicochet(at: location)
            spawnImpact(at: location, flavor: .standard, critical: true)
            if !reducesMotion { shake(intensity: 7) }
        case .haloContact(let position):
            spawnPinballRicochet(at: point(x: position.x, y: position.y))
        case .magneticTrapSnap(let position):
            let location = point(x: position.x, y: position.y)
            spawnImpact(at: location, flavor: .reverse, critical: true)
            if !reducesMotion { shake(intensity: 3) }
        case .tidalLaunch(let lane, let round, let position):
            let laneColor = SKColor(
                red: 0.08,
                green: round == 3 ? 0.78 : 0.62,
                blue: 1,
                alpha: 1
            )
            let launch = SKShapeNode(ellipseOf: .init(width: 78, height: 20))
            launch.position = point(x: position.x, y: position.y)
            launch.zPosition = 2_760
            launch.strokeColor = laneColor
            launch.fillColor = laneColor.withAlphaComponent(0.16)
            launch.lineWidth = 3
            launch.glowWidth = 9
            launch.xScale = lane == .middle ? 1.08 : 1
            characterAttackLayer.addChild(launch)
            launch.run(.sequence([
                .group([
                    .scale(to: reducesMotion ? 1.3 : 2.1, duration: 0.22),
                    .fadeOut(withDuration: 0.22),
                ]),
                .removeFromParent(),
            ]))
            if round == 3 {
                showScreenPulse(color: laneColor, strength: 0.24)
            }
        case .tidalHit(let position):
            spawnTidalSplash(at: point(x: position.x, y: position.y))
        }
    }

    private func spawnGaleCrack(at position: Vector2, variant: Int) {
        let safeVariant = min(2, max(0, variant))
        let texture = SKTexture(
            rect: CGRect(
                x: CGFloat(safeVariant) / 3,
                y: 0,
                width: 1 / 3,
                height: 1
            ),
            in: galeCrackTexture
        )
        let crack = SKSpriteNode(texture: texture)
        let trackScale = CGFloat(0.43 - 0.22 * position.y)
        let visualWidth = max(74, size.width * trackScale * 0.78)
        crack.size = .init(width: visualWidth, height: visualWidth * 0.40)
        crack.position = point(x: position.x, y: position.y)
        crack.zPosition = CGFloat(910 - position.y * 540)
        crack.alpha = 0.96
        crack.setScale(reducesMotion ? 0.92 : 0.52)
        crack.zRotation = CGFloat(safeVariant - 1) * 0.08
        characterAttackLayer.addChild(crack)
        crack.run(.sequence([
            .group([
                .scale(to: 1, duration: reducesMotion ? 0.08 : 0.14),
                .fadeAlpha(to: 0.92, duration: 0.08),
            ]),
            .wait(forDuration: reducesMotion ? 0.05 : 0.16),
            .group([
                .scale(to: 1.10, duration: 0.20),
                .fadeOut(withDuration: 0.20),
            ]),
            .removeFromParent(),
        ]))
    }

    private func spawnTidalSplash(at position: CGPoint) {
        let splash = SKShapeNode(ellipseOf: .init(width: 62, height: 22))
        splash.position = position
        splash.zPosition = 3_250
        splash.fillColor = SKColor(red: 0.18, green: 0.76, blue: 1, alpha: 0.28)
        splash.strokeColor = .white
        splash.lineWidth = 2
        splash.glowWidth = 7
        effectsLayer.addChild(splash)
        splash.run(.sequence([
            .group([
                .scale(to: reducesMotion ? 1.28 : 2.05, duration: 0.20),
                .fadeOut(withDuration: 0.20),
            ]),
            .removeFromParent(),
        ]))
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
        case .meteorVolley, .lastStand, .stormbreak, .ringRelay, .poleShift, .tidalBreak:
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

        let label = SKLabelNode(
            text: "WAVE \(GameNumberFormatter.compact(wave)) CLEARED"
        )
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
        let label = SKLabelNode(
            text: "COMBO ×\(GameNumberFormatter.compact(count))"
        )
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
