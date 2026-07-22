import SpriteKit

@MainActor
final class GoalRushScene: SKScene {
    private unowned let session: GameSessionModel
    private let world = SKNode()
    private let targetLayer = SKNode()
    private let projectileLayer = SKNode()
    private let effectsLayer = SKNode()
    private let playerNode: SKNode
    private let touchGuide = SKNode()
    private var targetNodes: [Int: SKNode] = [:]
    private var projectileNodes: [Int: SKNode] = [:]
    private var configuredSize = CGSize.zero
    private var lastHandledEventPulse = 0
    private let reducedEffects: Bool

    init(session: GameSessionModel, reducedEffects: Bool) {
        self.session = session
        self.reducedEffects = reducedEffects
        self.playerNode = GameNodeFactory.player(loadout: session.loadout)
        super.init(size: .init(width: 390, height: 844))
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.025, green: 0.07, blue: 0.14, alpha: 1)
    }

    required init?(coder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        anchorPoint = .zero
        addChild(world)
        world.addChild(targetLayer)
        world.addChild(projectileLayer)
        world.addChild(effectsLayer)
        world.addChild(playerNode)
        configureTouchGuide()
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
        session.update(currentTime: currentTime)
        if session.eventPulse != lastHandledEventPulse {
            lastHandledEventPulse = session.eventPulse
            handle(session.recentEvents)
        }
        render(session.snapshot)
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

    private func rebuildField() {
        world.childNode(withName: "field")?.removeFromParent()
        let texture = SKTexture(imageNamed: session.world.gameplayAsset)
        let field = SKSpriteNode(texture: texture)
        field.name = "field"
        let textureSize = texture.size()
        let scale = max(size.width / max(textureSize.width, 1), size.height / max(textureSize.height, 1))
        field.size = CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
        field.position = CGPoint(x: size.width / 2, y: size.height / 2)
        field.zPosition = -200
        world.insertChild(field, at: 0)

        let turfTint = SKShapeNode(rectOf: size)
        turfTint.fillColor = session.world.id == .mars
            ? SKColor(red: 0.20, green: 0.02, blue: 0.22, alpha: 0.10)
            : SKColor(red: 0.02, green: 0.10, blue: 0.16, alpha: 0.12)
        turfTint.strokeColor = .clear
        turfTint.position = field.position
        turfTint.zPosition = -190
        turfTint.name = "arena-tint"
        world.insertChild(turfTint, at: 1)
    }

    private func render(_ snapshot: SimulationSnapshot) {
        playerNode.position = point(x: snapshot.playerX, y: 0.08)
        playerNode.zPosition = 1_000
        syncTargets(snapshot.targets)
        syncProjectiles(snapshot.projectiles)
    }

    private func syncTargets(_ targets: [TargetState]) {
        let live = Set(targets.map(\.id))
        for id in targetNodes.keys where !live.contains(id) { targetNodes.removeValue(forKey: id)?.removeFromParent() }
        for target in targets {
            let node = targetNodes[target.id] ?? {
                let newNode = GameNodeFactory.target(target)
                targetLayer.addChild(newNode)
                targetNodes[target.id] = newNode
                return newNode
            }()
            let scale = perspectiveScale(target.position.y)
            var targetPoint = point(x: target.position.x, y: target.position.y)
            targetPoint.y += CGFloat(sin(target.phase * 7.5) * 2.2) * scale
            node.position = targetPoint
            let bossMultiplier: CGFloat = if case .enemy(let enemy) = target.kind,
                                              enemy == .titanKeeper || enemy == .marsColossus {
                1.0
            } else {
                scale
            }
            node.setScale(bossMultiplier)
            if case .enemy(let enemy) = target.kind, enemy == .tackleBot || enemy == .craterCrawler {
                node.zRotation = 0.08 + CGFloat(sin(target.phase * 8)) * 0.045
            } else {
                node.zRotation = CGFloat(sin(target.phase * 5.5)) * 0.025
            }
            node.zPosition = CGFloat(900 - target.position.y * 700)
            GameNodeFactory.animateTarget(
                on: node,
                kind: target.kind,
                phase: target.phase,
                reducedMotion: reducesMotion
            )
            GameNodeFactory.updateHealth(on: node, ratio: target.hitPoints / target.maximumHitPoints)
        }
    }

    private func syncProjectiles(_ projectiles: [ProjectileState]) {
        let live = Set(projectiles.map(\.id))
        for id in projectileNodes.keys where !live.contains(id) { projectileNodes.removeValue(forKey: id)?.removeFromParent() }
        for projectile in projectiles {
            let node = projectileNodes[projectile.id] ?? {
                let newNode = GameNodeFactory.projectile(hostile: projectile.hostile)
                if projectile.isCritical, let ball = newNode.childNode(withName: "ball") as? SKShapeNode {
                    ball.glowWidth = 8
                    ball.strokeColor = SKColor(red: 1, green: 0.72, blue: 0.08, alpha: 1)
                }
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

    private func point(x: Double, y: Double) -> CGPoint {
        let narrowing = 0.43 - 0.22 * y
        return CGPoint(x: size.width * (0.5 + x * narrowing), y: size.height * (0.10 + y * 0.78))
    }

    private func perspectiveScale(_ y: Double) -> CGFloat { CGFloat(1.05 - min(max(y, 0), 1) * 0.48) }

    private func handle(_ events: [SimulationEvent]) {
        for event in events {
            switch event {
            case .kick:
                GameNodeFactory.animateKick(on: playerNode, reducedMotion: reducesMotion)
                spawnKickWave()
            case .impact(let position, let critical):
                spawnImpact(at: point(x: position.x, y: position.y), critical: critical)
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
            case .waveCompleted(let wave):
                showWaveBanner(wave: wave)
                showScreenPulse(color: SKColor(red: 0.18, green: 0.90, blue: 1, alpha: 1), strength: 0.30)
            case .meteorKick:
                showScreenPulse(color: SKColor(red: 1, green: 0.34, blue: 0.08, alpha: 1), strength: 0.22)
                spawnMeteorAura()
            case .finished(let won):
                if won { showScreenPulse(color: SKColor(red: 1, green: 0.78, blue: 0.16, alpha: 1), strength: 0.48) }
            }
        }
    }

    private var reducesMotion: Bool { reducedEffects || UIAccessibility.isReduceMotionEnabled }

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
        let wave = SKShapeNode(ellipseOf: .init(width: 48, height: 18))
        wave.strokeColor = SKColor(red: 0.20, green: 0.84, blue: 1, alpha: 0.75)
        wave.lineWidth = 3
        wave.fillColor = .clear
        wave.position = playerNode.position + CGPoint(x: 0, y: 26)
        wave.zPosition = 1_100
        effectsLayer.addChild(wave)
        let duration = reducesMotion ? 0.12 : 0.24
        wave.run(.sequence([.group([.scale(to: reducesMotion ? 1.15 : 2.1, duration: duration), .fadeOut(withDuration: duration)]), .removeFromParent()]))
    }

    private func spawnImpact(at position: CGPoint, critical: Bool) {
        let count = critical ? 12 : 7
        let palette: [SKColor] = critical
            ? [.white, SKColor(red: 1, green: 0.72, blue: 0.08, alpha: 1), SKColor(red: 0.22, green: 0.88, blue: 1, alpha: 1)]
            : [.white, SKColor(red: 0.18, green: 0.78, blue: 1, alpha: 1)]
        for index in 0..<count {
            let spark = SKShapeNode(circleOfRadius: critical ? 3.5 : 2.5)
            spark.fillColor = palette[index % palette.count]
            spark.strokeColor = .clear
            spark.position = position
            spark.zPosition = 2_000
            effectsLayer.addChild(spark)
            let angle = CGFloat(index) / CGFloat(count) * .pi * 2
            let distance: CGFloat = critical ? 38 : 24
            let move = SKAction.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: reducesMotion ? 0.10 : 0.24)
            move.timingMode = .easeOut
            spark.run(.sequence([.group([move, .fadeOut(withDuration: reducesMotion ? 0.10 : 0.24), .scale(to: 0.15, duration: reducesMotion ? 0.10 : 0.24)]), .removeFromParent()]))
        }
        if critical {
            let label = SKLabelNode(text: "CRITICAL")
            label.fontName = "AvenirNext-Heavy"
            label.fontSize = 13
            label.fontColor = SKColor(red: 1, green: 0.78, blue: 0.12, alpha: 1)
            label.position = position + CGPoint(x: 0, y: 22)
            label.zPosition = 2_050
            effectsLayer.addChild(label)
            label.run(.sequence([.group([.moveBy(x: 0, y: 24, duration: 0.35), .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
        }
    }

    private func spawnReward(value: Int, from position: CGPoint) {
        let container = SKNode()
        container.position = position
        container.zPosition = 2_100
        let token = GameNodeFactory.rewardToken()
        container.addChild(token)
        let label = SKLabelNode(text: "+\(value)")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 15
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.position.x = 27
        container.addChild(label)
        effectsLayer.addChild(container)
        let target = CGPoint(x: size.width * 0.77, y: size.height * 0.90)
        let move = SKAction.move(to: target, duration: reducesMotion ? 0.18 : 0.48)
        move.timingMode = .easeInEaseOut
        container.run(.sequence([.group([move, .rotate(byAngle: .pi * 2, duration: reducesMotion ? 0.18 : 0.48), .scale(to: 0.72, duration: reducesMotion ? 0.18 : 0.48)]), .fadeOut(withDuration: 0.10), .removeFromParent()]))
    }

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
}

private func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}
