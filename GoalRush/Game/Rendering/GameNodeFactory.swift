import SpriteKit

@MainActor
enum GameNodeFactory {
    private static var targetPrototypes: [TargetState.Kind: TargetRenderNode] = [:]
    private static let standardKickActions = makeKickActions(reducedMotion: false)
    private static let reducedKickActions = makeKickActions(reducedMotion: true)
    private static let projectileTextures: [String: SKTexture] = {
        let names = [
            "SoccerBall",
            "SoccerBallRapidFire",
            "SoccerBallExplosive",
            "SoccerBallFire",
            "SoccerBallIce",
            "SoccerBallReverse",
            "SoccerBallSplit"
        ]
        return Dictionary(uniqueKeysWithValues: names.map { name in
            let texture = SKTexture(imageNamed: name)
            texture.filteringMode = .linear
            return (name, texture)
        })
    }()
    private static let bossFactionTextures: [WorldID: SKTexture] = {
        Dictionary(uniqueKeysWithValues: WorldID.allCases.map { world in
            let texture = SKTexture(imageNamed: world.factionSigilAsset(isBoss: true))
            texture.filteringMode = .linear
            return (world, texture)
        })
    }()
    static let renderedEnemyAssetNames: [EnemyKind: String] = [
        .coneRunner: "EarthScoutRunner",
        .dummyDefender: "EarthBlockerDefender",
        .tackleBot: "EarthTackleBot",
        .keeperDrone: "EarthAegisKeeper",
        .ballLauncher: "EarthBallLauncher",
        .titanKeeper: "EarthTitanKeeper",
        .regolithRunner: "MoonRegolithRunner",
        .lunarHopper: "MoonLunarHopper",
        .orbitDrone: "MoonOrbitDrone",
        .eclipseKeeper: "MoonEclipseKeeper",
        .gravityStriker: "MoonGravityStriker",
        .lunarWarden: "MoonLunarWarden",
        .dustSprite: "MarsDustSprite",
        .roverRaider: "MarsRoverRaider",
        .craterCrawler: "MarsCraterCrawler",
        .saucerKeeper: "MarsSaucerKeeper",
        .plasmaStriker: "MarsPlasmaStriker",
        .marsColossus: "MarsColossus"
    ]
    private static let renderedEnemyTextures: [EnemyKind: SKTexture] = {
        renderedEnemyAssetNames.mapValues { name in
            let texture = SKTexture(imageNamed: name)
            texture.filteringMode = .linear
            return texture
        }
    }()
    private static let renderedFieldObjectTextures: [FieldObjectKind: SKTexture] = {
        let assets: [FieldObjectKind: String] = [
            .ballCart: "EarthBallCart",
            .waterCooler: "EarthWaterCooler",
            .tacticsBoard: "EarthTacticsBoard",
            .coneBarricade: "EarthConeBarricade",
            .equipmentTrunk: "EarthEquipmentTrunk",
            .roverBattery: "EarthBallCart",
            .satelliteRelay: "EarthTacticsBoard",
            .regolithBarricade: "EarthConeBarricade",
            .gravityCell: "EarthWaterCooler",
            .lunarVault: "EarthEquipmentTrunk",
            .oxygenPod: "MarsOxygenPod",
            .meteorCrate: "MarsMeteorCrate",
            .holoGate: "MarsHoloGate",
            .crystalBarricade: "MarsCrystalBarricade",
            .artifactVault: "MarsArtifactVault"
        ]
        return assets.mapValues { name in
            let texture = SKTexture(imageNamed: name)
            texture.filteringMode = .linear
            return texture
        }
    }()
    private static let characterTextures: [String: SKTexture] = {
        let names = CharacterID.allCases.flatMap { id in
            let stem = CharacterCatalog.character(id).assetStem
            return ["\(stem)Roster", "\(stem)Gameplay"]
        }
        return Dictionary(uniqueKeysWithValues: names.map { name in
            let texture = SKTexture(imageNamed: name)
            texture.filteringMode = .linear
            return (name, texture)
        })
    }()
    private static let aceRigBaseTexture: SKTexture = {
        let texture = SKTexture(imageNamed: "CharacterAceRigBase")
        texture.filteringMode = .linear
        return texture
    }()
    private static let aceRigRightLegTexture: SKTexture = {
        let texture = SKTexture(imageNamed: "CharacterAceRigRightLeg")
        texture.filteringMode = .linear
        return texture
    }()
    private static let aceRightHipPosition = CGPoint(x: 5, y: -4)
    private static let standardRightHipPosition = CGPoint(x: 7.04, y: -5.28)
    private static let gameplaySpriteSize = CGSize(width: 88, height: 88)

    private struct KickActions {
        let kickingLeg: SKAction
        let plantLeg: SKAction
        let body: SKAction
    }

    static func player(
        character: CharacterID,
        presentation: PlayerPresentation = .gameplay
    ) -> SKNode {
        let root = SKNode()
        root.name = "player"
        root.userData = NSMutableDictionary(dictionary: ["characterID": character.rawValue])
        let isGameplay = presentation == .gameplay
        let shadow = ellipse(
            size: isGameplay ? .init(width: 58, height: 15) : .init(width: 88, height: 20),
            color: .black.withAlphaComponent(0.25),
            y: isGameplay ? -45 : -77
        )
        shadow.name = "shadow"
        root.addChild(shadow)

        let body = SKNode()
        body.name = "body"
        let definition = CharacterCatalog.character(character)
        let suffix = isGameplay ? "Gameplay" : "Roster"
        let usesAceGameplayRig = isGameplay && character == .ace
        if usesAceGameplayRig {
            let sprite = SKSpriteNode(texture: aceRigBaseTexture)
            sprite.name = "character-sprite"
            sprite.size = gameplaySpriteSize
            body.addChild(sprite)

            let rightLeg = SKSpriteNode(texture: aceRigRightLegTexture)
            rightLeg.name = "kicking-leg"
            rightLeg.size = .init(width: 50, height: 50)
            rightLeg.anchorPoint = .init(x: 0.53, y: 0.87)
            rightLeg.position = aceRightHipPosition
            rightLeg.zPosition = -1
            body.addChild(rightLeg)
        } else if isGameplay,
                  let texture = characterTextures["\(definition.assetStem)\(suffix)"] {
            addSegmentedCharacterRig(texture: texture, to: body)
        } else {
            let sprite = SKSpriteNode(texture: characterTextures["\(definition.assetStem)\(suffix)"])
            sprite.name = "character-sprite"
            sprite.size = .init(width: 158, height: 158)
            body.addChild(sprite)
        }
        root.addChild(body)
        return root
    }

    static func animateKick(on player: SKNode, reducedMotion: Bool) {
        guard let body = player.childNode(withName: "body") else { return }
        if player.userData?["characterID"] as? String == CharacterID.ace.rawValue,
           let rightLeg = body.childNode(withName: "kicking-leg") as? SKSpriteNode {
            animateLegKick(
                rightLeg: rightLeg,
                restingPosition: aceRightHipPosition,
                body: body,
                reducedMotion: reducedMotion
            )
            return
        }
        guard let legs = body.childNode(withName: "slot-legs"),
              let kickingLeg = legs.childNode(withName: "kicking-leg") as? SKSpriteNode else {
            body.removeAction(forKey: "kick-body")
            let tilt: CGFloat = reducedMotion ? -0.035 : -0.09
            body.run(.sequence([
                .group([.rotate(toAngle: tilt, duration: 0.08), .scale(to: reducedMotion ? 1.01 : 1.06, duration: 0.08)]),
                .group([.rotate(toAngle: 0.035, duration: 0.09), .scale(to: 0.98, duration: 0.09)]),
                .group([.rotate(toAngle: 0, duration: 0.14), .scale(to: 1, duration: 0.14)])
            ]), withKey: "kick-body")
            return
        }

        animateLegKick(
            rightLeg: kickingLeg,
            restingPosition: standardRightHipPosition,
            body: body,
            reducedMotion: reducedMotion
        )
    }

    private static func animateLegKick(
        rightLeg: SKSpriteNode,
        restingPosition: CGPoint,
        body: SKNode,
        reducedMotion: Bool
    ) {
        let wasAlreadyKicking = rightLeg.action(forKey: "kick-leg") != nil
        rightLeg.removeAction(forKey: "kick-leg")
        body.removeAction(forKey: "kick-body")
        rightLeg.position = restingPosition
        rightLeg.zRotation = 0
        rightLeg.xScale = 1
        rightLeg.yScale = 1

        let legAction: SKAction
        if reducedMotion {
            legAction = .sequence([
                .group([
                    .rotate(toAngle: -0.18, duration: 0.06, shortestUnitArc: true),
                    .scaleY(to: 0.80, duration: 0.06)
                ]),
                .group([
                    .rotate(toAngle: 0, duration: 0.10, shortestUnitArc: true),
                    .scaleY(to: 1, duration: 0.10)
                ])
            ])
        } else {
            let windupDuration = wasAlreadyKicking ? 0.018 : 0.065
            let strikeDuration = wasAlreadyKicking ? 0.025 : 0.075
            let recoverDuration = wasAlreadyKicking ? 0.045 : 0.14
            legAction = .sequence([
                .group([
                    .rotate(toAngle: 0.30, duration: windupDuration, shortestUnitArc: true),
                    .scaleY(to: 1.04, duration: windupDuration)
                ]),
                .group([
                    .rotate(toAngle: -0.30, duration: strikeDuration, shortestUnitArc: true),
                    .scaleY(to: 0.68, duration: strikeDuration)
                ]),
                .group([
                    .rotate(toAngle: 0, duration: recoverDuration, shortestUnitArc: true),
                    .scaleY(to: 1, duration: recoverDuration)
                ])
            ])
        }
        rightLeg.run(legAction, withKey: "kick-leg")

        let lift: CGFloat = reducedMotion ? 0.5 : 2
        let rotation: CGFloat = reducedMotion ? -0.008 : -0.025
        body.run(.sequence([
            .group([
                .moveTo(y: lift, duration: 0.08),
                .rotate(toAngle: rotation, duration: 0.08, shortestUnitArc: true)
            ]),
            .group([
                .moveTo(y: 0, duration: reducedMotion ? 0.08 : 0.20),
                .rotate(toAngle: 0, duration: reducedMotion ? 0.08 : 0.20, shortestUnitArc: true)
            ])
        ]), withKey: "kick-body")
    }

    private static func addSegmentedCharacterRig(texture: SKTexture, to body: SKNode) {
        let upperBody = croppedSprite(
            texture: texture,
            rect: .init(x: 0, y: 0.42, width: 1, height: 0.58),
            name: "character-sprite"
        )
        body.addChild(upperBody)

        let legs = SKNode()
        legs.name = "slot-legs"

        let plantLeg = croppedSprite(
            texture: texture,
            rect: .init(x: 0.20, y: 0, width: 0.32, height: 0.46),
            name: "plant-leg",
            anchorPoint: .init(x: 0.6875, y: 0.9565),
            position: .init(x: -7.04, y: -5.28)
        )
        let kickingLeg = croppedSprite(
            texture: texture,
            rect: .init(x: 0.48, y: 0, width: 0.32, height: 0.46),
            name: "kicking-leg",
            anchorPoint: .init(x: 0.3125, y: 0.9565),
            position: standardRightHipPosition
        )
        kickingLeg.zPosition = -1
        legs.addChild(plantLeg)
        legs.addChild(kickingLeg)
        body.addChild(legs)
    }

    private static func croppedSprite(
        texture: SKTexture,
        rect: CGRect,
        name: String,
        anchorPoint: CGPoint = .init(x: 0.5, y: 0.5),
        position: CGPoint? = nil
    ) -> SKSpriteNode {
        let sprite = SKSpriteNode(texture: SKTexture(rect: rect, in: texture))
        sprite.name = name
        sprite.size = .init(
            width: gameplaySpriteSize.width * rect.width,
            height: gameplaySpriteSize.height * rect.height
        )
        sprite.anchorPoint = anchorPoint
        sprite.position = position ?? .init(
            x: (rect.midX - 0.5) * gameplaySpriteSize.width,
            y: (rect.midY - 0.5) * gameplaySpriteSize.height
        )
        return sprite
    }

    /// Forces the reusable action graphs to initialize before live kicks begin.
    static func prewarmKickActions() {
        _ = standardKickActions
        _ = reducedKickActions
        _ = aceRigBaseTexture
        _ = aceRigRightLegTexture
    }

    /// Resolves the full projectile atlas before the first live kick.
    static func prewarmProjectileTextures() {
        _ = projectileTextures
    }

    private static func makeKickActions(reducedMotion: Bool) -> KickActions {
        let windupAngle: CGFloat = reducedMotion ? -0.18 : -0.52
        let strikeAngle: CGFloat = reducedMotion ? 0.38 : 1.02
        return KickActions(
            kickingLeg: .sequence([
                .rotate(toAngle: windupAngle, duration: 0.12, shortestUnitArc: true),
                .rotate(toAngle: strikeAngle, duration: 0.10, shortestUnitArc: true),
                .rotate(toAngle: 0.08, duration: 0.18, shortestUnitArc: true)
            ]),
            plantLeg: .sequence([
                .rotate(toAngle: -0.20, duration: 0.12, shortestUnitArc: true),
                .rotate(toAngle: -0.08, duration: 0.28, shortestUnitArc: true)
            ]),
            body: .sequence([
                .group([
                    .moveBy(x: 0, y: reducedMotion ? 1 : 4, duration: 0.10),
                    .rotate(toAngle: -0.07, duration: 0.10, shortestUnitArc: true)
                ]),
                .group([
                    .moveTo(y: 0, duration: 0.22),
                    .rotate(toAngle: 0, duration: 0.22, shortestUnitArc: true)
                ])
            ])
        )
    }

    static func target(_ target: TargetState, world: WorldID? = nil) -> SKNode {
        let resolvedWorld = world ?? inferredWorld(for: target.kind)
        if let prototype = targetPrototypes[target.kind],
           let node = prototype.copy() as? TargetRenderNode {
            node.cacheRenderNodes()
            configureTarget(node, target: target, world: resolvedWorld)
            return node
        }

        let prototype = makeTarget(kind: target.kind)
        targetPrototypes[target.kind] = prototype
        guard let node = prototype.copy() as? TargetRenderNode else {
            configureTarget(prototype, target: target, world: resolvedWorld)
            return prototype
        }
        node.cacheRenderNodes()
        configureTarget(node, target: target, world: resolvedWorld)
        return node
    }

    static func configureTarget(_ node: SKNode, target: TargetState, world: WorldID) {
        guard let renderNode = node as? TargetRenderNode else { return }
        let isBoss = target.bossTier != .standard
        renderNode.configureHealthPresentation(
            isBoss: isBoss,
            bossIconTexture: isBoss ? bossFactionTextures[world] : nil
        )
        updateHealth(
            on: renderNode,
            ratio: target.hitPoints / max(1, target.maximumHitPoints)
        )
    }

    /// Builds each shape hierarchy once. Copies retain SpriteKit's immutable
    /// geometry instead of recreating dozens of paths on a live spawn frame.
    static func prewarmTarget(kind: TargetState.Kind) {
        guard targetPrototypes[kind] == nil else { return }
        targetPrototypes[kind] = makeTarget(kind: kind)
    }

    private static func makeTarget(kind: TargetState.Kind) -> TargetRenderNode {
        let root = TargetRenderNode()
        switch kind {
        case .enemy(let enemy): decorateEnemy(root, enemy: enemy)
        case .fieldObject(let object): decorateObject(root, object: object)
        case .powerUp(let ability): decoratePowerUp(root, ability: ability)
        case .volatileCore: decorateVolatileCore(root)
        }
        if case .powerUp = kind {
            root.cacheRenderNodes()
            return root
        }
        if case .volatileCore = kind {
            root.cacheRenderNodes()
            return root
        }
        let health = SKShapeNode(rectOf: .init(width: 48, height: 5), cornerRadius: 2.5)
        health.name = "health-background"
        health.fillColor = .black.withAlphaComponent(0.45)
        health.strokeColor = .clear
        health.position.y = healthBarHeight(for: kind)
        root.addChild(health)
        let fill = SKShapeNode(rectOf: .init(width: 46, height: 3), cornerRadius: 1.5)
        fill.name = "health-fill"
        fill.fillColor = color(0.16, 0.92, 0.42)
        fill.strokeColor = .clear
        health.addChild(fill)

        let bossHealth = SKNode()
        bossHealth.name = "boss-health"
        bossHealth.position.y = healthBarHeight(for: kind)
        bossHealth.zPosition = 1_200
        bossHealth.isHidden = true

        let iconBackdrop = SKShapeNode(circleOfRadius: 11)
        iconBackdrop.name = "boss-health-icon-backdrop"
        iconBackdrop.position.x = -40
        iconBackdrop.fillColor = color(0.08, 0.01, 0.02).withAlphaComponent(0.96)
        iconBackdrop.strokeColor = color(1, 0.12, 0.08)
        iconBackdrop.lineWidth = 1.6
        bossHealth.addChild(iconBackdrop)

        let bossIcon = SKSpriteNode()
        bossIcon.name = "boss-health-icon"
        bossIcon.position.x = -40
        bossIcon.size = CGSize(width: 18, height: 18)
        bossIcon.zPosition = 1
        bossHealth.addChild(bossIcon)

        let bossTrack = SKShapeNode(
            rectOf: CGSize(width: 66, height: 8),
            cornerRadius: 4
        )
        bossTrack.name = "boss-health-track"
        bossTrack.position.x = 5
        bossTrack.fillColor = color(0.08, 0.01, 0.02).withAlphaComponent(0.94)
        bossTrack.strokeColor = color(0.56, 0.04, 0.04)
        bossTrack.lineWidth = 1
        bossHealth.addChild(bossTrack)

        let bossFill = SKShapeNode(
            rectOf: CGSize(width: 62, height: 4),
            cornerRadius: 2
        )
        bossFill.name = "boss-health-fill"
        bossFill.fillColor = color(1, 0.10, 0.07)
        bossFill.strokeColor = .clear
        bossFill.glowWidth = 1.5
        bossTrack.addChild(bossFill)
        root.addChild(bossHealth)

        installStatusEffects(on: root, kind: kind)
        root.cacheRenderNodes()
        return root
    }

    static func animateTarget(
        on node: SKNode,
        kind: TargetState.Kind,
        phase: Double,
        reducedMotion: Bool,
        frozen: Bool = false
    ) {
        guard case .enemy(let enemy) = kind,
              let renderNode = node as? TargetRenderNode,
              let rig = renderNode.motionRig else { return }

        if frozen {
            rig.position = .zero
            rig.zRotation = 0
            rig.xScale = 1
            rig.yScale = 1
            setLimbPose(on: renderNode, stride: 0, armSwing: 0)
            return
        }

        let intensity: CGFloat = reducedMotion ? 0.28 : 1
        let time = CGFloat(phase)
        let pulse = CGFloat(0.78 + sin(phase * 5.2) * 0.22)
        for child in renderNode.motionLights {
            child.alpha = pulse
        }

        if enemy == .coneRunner {
            let wobble = sin(time * 9.5)
            rig.position = CGPoint(x: wobble * 1.5 * intensity, y: abs(cos(time * 9.5)) * 2.8 * intensity)
            rig.zRotation = wobble * 0.13 * intensity
            let compression = abs(wobble) * 0.025 * intensity
            rig.xScale = 1 + compression
            rig.yScale = 1 - compression
            return
        }

        if enemy == .saucerKeeper {
            let hover = sin(time * 5.4)
            rig.position = CGPoint(x: hover * 1.4 * intensity, y: hover * 4.2 * intensity)
            rig.zRotation = sin(time * 3.1) * 0.055 * intensity
            setLimbPose(on: renderNode, stride: sin(time * 4.2) * 0.08 * intensity, armSwing: 0.06 * intensity)
            return
        }

        let movement: (cadence: CGFloat, stride: CGFloat, bob: CGFloat, sway: CGFloat) = switch enemy {
        case .tackleBot, .craterCrawler, .lunarHopper:
            (11.2, 0.43, 3.8, 0.045)
        case .dustSprite, .regolithRunner:
            (9.6, 0.36, 3.4, 0.035)
        case .dummyDefender, .roverRaider, .eclipseKeeper:
            (6.3, 0.28, 2.5, 0.024)
        case .keeperDrone, .orbitDrone:
            (4.7, 0.21, 2.0, 0.018)
        case .ballLauncher, .plasmaStriker, .gravityStriker:
            (5.5, 0.24, 2.2, 0.020)
        case .titanKeeper, .lunarWarden, .marsColossus:
            (3.5, 0.15, 2.8, 0.014)
        case .coneRunner, .saucerKeeper:
            (6, 0.2, 2, 0.02)
        }

        let step = sin(time * movement.cadence)
        rig.position = CGPoint(x: 0, y: abs(cos(time * movement.cadence)) * movement.bob * intensity)
        rig.zRotation = step * movement.sway * intensity
        let compression = abs(step) * 0.012 * intensity
        rig.xScale = 1 + compression
        rig.yScale = 1 - compression
        setLimbPose(
            on: renderNode,
            stride: step * movement.stride * intensity,
            armSwing: -step * movement.stride * 0.72 * intensity
        )
    }

    static func projectile(hostile: Bool) -> SKNode {
        let root = SKNode()
        let trail = rect(size: .init(width: 5, height: hostile ? 18 : 24), color: hostile ? color(1, 0.20, 0.06).withAlphaComponent(0.38) : color(0.14, 0.76, 1).withAlphaComponent(0.34), radius: 2.5, y: hostile ? 13 : -16)
        trail.name = "trail"
        root.addChild(trail)
        root.addChild(ellipse(size: .init(width: 18, height: 6), color: .black.withAlphaComponent(0.18), y: -12))
        let halo = circle(radius: hostile ? 11 : 10, color: .clear)
        halo.name = "ball-halo"
        halo.fillColor = .clear
        halo.strokeColor = .clear
        halo.lineWidth = 2
        halo.zPosition = -1
        root.addChild(halo)
        let ball = SKSpriteNode(texture: projectileTextures["SoccerBall"])
        ball.size = CGSize(width: hostile ? 25 : 27, height: hostile ? 25 : 27)
        ball.color = hostile ? color(1, 0.20, 0.04) : .white
        ball.colorBlendFactor = hostile ? 0.48 : 0
        ball.name = "ball"
        root.addChild(ball)
        return root
    }

    static func configureProjectile(
        _ node: SKNode,
        hostile: Bool,
        critical: Bool,
        temporaryAbility: TemporaryBallAbility?,
        characterProjectile: CharacterProjectileKind? = nil
    ) {
        guard let ball = node.childNode(withName: "ball") as? SKSpriteNode,
              let trail = node.childNode(withName: "trail") as? SKShapeNode,
              let halo = node.childNode(withName: "ball-halo") as? SKShapeNode else { return }
        if hostile {
            ball.texture = projectileTextures["SoccerBall"]
            ball.size = CGSize(width: 25, height: 25)
            ball.color = color(1, 0.20, 0.04)
            ball.colorBlendFactor = 0.48
            halo.strokeColor = .clear
            halo.glowWidth = 0
            trail.fillColor = color(1, 0.20, 0.06).withAlphaComponent(0.38)
            return
        }
        if characterProjectile == .pinballBlitz {
            ball.texture = projectileTextures["SoccerBallRapidFire"] ?? projectileTextures["SoccerBall"]
            ball.size = CGSize(width: 39, height: 39)
            ball.color = .white
            ball.colorBlendFactor = 0
            halo.strokeColor = color(0.08, 0.90, 1)
            halo.glowWidth = 12
            trail.fillColor = color(1, 0.72, 0.08).withAlphaComponent(0.74)
            return
        }
        let presentation: (asset: String, accent: SKColor, size: CGFloat) = switch temporaryAbility {
        case .rapidFire: ("SoccerBallRapidFire", color(1, 0.58, 0.03), 34)
        case .explosive: ("SoccerBallExplosive", color(0.92, 0.04, 0.02), 34)
        case .fire: ("SoccerBallFire", color(1, 0.28, 0.02), 36)
        case .ice: ("SoccerBallIce", color(0.04, 0.64, 1), 34)
        case .reverse: ("SoccerBallReverse", color(0.58, 0.12, 1), 34)
        case .split: ("SoccerBallSplit", color(0.02, 0.68, 0.22), 36)
        case .heatSeeking: ("SoccerBallRapidFire", color(0.10, 0.86, 1), 34)
        case .orbitShot: ("SoccerBallReverse", color(0.55, 0.48, 1), 36)
        case .solarPierce: ("SoccerBallFire", color(1, 0.72, 0.08), 36)
        case nil: ("SoccerBall", color(0.05, 0.30, 0.78), 27)
        }
        ball.texture = projectileTextures[presentation.asset]
        ball.size = CGSize(width: presentation.size, height: presentation.size)
        ball.color = .white
        ball.colorBlendFactor = 0
        halo.strokeColor = temporaryAbility == .heatSeeking
            ? color(0.10, 0.86, 1)
            : (critical ? color(1, 0.78, 0.12) : .clear)
        halo.glowWidth = temporaryAbility == .heatSeeking ? 7 : (critical ? 7 : 0)
        trail.fillColor = presentation.accent.withAlphaComponent(0.46)
    }

    static func rewardToken() -> SKNode {
        let token = SKSpriteNode(imageNamed: "TrainingToken")
        token.size = CGSize(width: 31, height: 31)
        return token
    }

    static func updateHealth(on node: SKNode, ratio: Double) {
        guard let renderNode = node as? TargetRenderNode,
              let fill = renderNode.healthFill else { return }
        let clampedRatio = min(1, max(0, ratio))
        fill.xScale = max(0.02, clampedRatio)
        if renderNode.showsBossHealth {
            fill.position.x = CGFloat(-31 * (1 - clampedRatio))
        } else {
            fill.position.x = CGFloat(-23 * (1 - clampedRatio))
        }
        if let shape = fill as? SKShapeNode {
            shape.fillColor = renderNode.showsBossHealth
                ? color(1, 0.10, 0.07)
                : (clampedRatio > 0.5
                    ? color(0.16, 0.92, 0.42)
                    : (clampedRatio > 0.25
                        ? color(1, 0.72, 0.10)
                        : color(1, 0.22, 0.08)))
        }
    }

    static func updateStatus(on node: SKNode, target: TargetState, reducedMotion: Bool) {
        (node as? TargetRenderNode)?.applyStatus(from: target, reducedMotion: reducedMotion)
    }

    static func resetStatus(on node: SKNode) {
        (node as? TargetRenderNode)?.resetStatusEffects()
    }

    private static func installStatusEffects(on root: TargetRenderNode, kind: TargetState.Kind) {
        let parent = root.childNode(withName: "motion-body") ?? root
        let profile = statusProfile(for: kind)

        let underlay = SKNode()
        underlay.name = "status-underlay"
        underlay.zPosition = -12
        underlay.alpha = 0
        parent.addChild(underlay)

        let fireBack = SKNode()
        fireBack.name = "status-fire-back"
        underlay.addChild(fireBack)
        addFlames(
            to: fireBack,
            anchors: [
                (-0.34, -0.25, 0.76), (0.32, -0.22, 0.90),
                (-0.24, 0.17, 0.82), (0.26, 0.20, 0.72)
            ],
            profile: profile,
            foreground: false
        )

        let reverseBack = SKNode()
        reverseBack.name = "status-reverse-trail"
        underlay.addChild(reverseBack)
        addReverseStreaks(to: reverseBack, profile: profile)

        let overlay = SKNode()
        overlay.name = "status-overlay"
        overlay.zPosition = 30
        overlay.alpha = 0
        parent.addChild(overlay)

        let frostGlaze = SKNode()
        frostGlaze.name = "status-frost-glaze"
        overlay.addChild(frostGlaze)
        addFrostBands(to: frostGlaze, profile: profile)

        let crystals = SKNode()
        crystals.name = "status-ice-crystals"
        overlay.addChild(crystals)
        addIceCrystals(to: crystals, profile: profile)

        let fireFront = SKNode()
        fireFront.name = "status-fire-front"
        overlay.addChild(fireFront)
        addFlames(
            to: fireFront,
            anchors: [
                (-0.42, -0.42, 0.58), (0.40, -0.38, 0.66),
                (-0.12, -0.02, 0.62), (0.17, 0.39, 0.52)
            ],
            profile: profile,
            foreground: true
        )
        addEmbers(to: fireFront, profile: profile)

        let stunArcs = SKNode()
        stunArcs.name = "status-stun-arcs"
        overlay.addChild(stunArcs)
        addStunArcs(to: stunArcs, profile: profile)
    }

    private struct StatusProfile {
        let width: CGFloat
        let height: CGFloat
        let centerY: CGFloat
    }

    private static func statusProfile(for kind: TargetState.Kind) -> StatusProfile {
        switch kind {
        case .enemy(let enemy):
            return switch enemy {
            case .coneRunner: .init(width: 56, height: 70, centerY: 4)
            case .dummyDefender: .init(width: 70, height: 72, centerY: 2)
            case .tackleBot: .init(width: 76, height: 68, centerY: 10)
            case .keeperDrone: .init(width: 78, height: 76, centerY: 10)
            case .ballLauncher: .init(width: 80, height: 78, centerY: 7)
            case .titanKeeper: .init(width: 86, height: 90, centerY: 13)
            case .regolithRunner: .init(width: 60, height: 72, centerY: 4)
            case .lunarHopper: .init(width: 82, height: 68, centerY: 9)
            case .orbitDrone: .init(width: 82, height: 80, centerY: 10)
            case .eclipseKeeper: .init(width: 76, height: 78, centerY: 5)
            case .gravityStriker: .init(width: 82, height: 88, centerY: 8)
            case .lunarWarden: .init(width: 100, height: 106, centerY: 13)
            case .dustSprite: .init(width: 60, height: 70, centerY: 4)
            case .roverRaider: .init(width: 76, height: 78, centerY: 5)
            case .craterCrawler: .init(width: 88, height: 62, centerY: 4)
            case .saucerKeeper: .init(width: 82, height: 84, centerY: 6)
            case .plasmaStriker: .init(width: 78, height: 90, centerY: 8)
            case .marsColossus: .init(width: 98, height: 104, centerY: 12)
            }
        case .fieldObject(let object):
            return switch object {
            case .ballCart: .init(width: 70, height: 76, centerY: 8)
            case .waterCooler: .init(width: 52, height: 82, centerY: 10)
            case .tacticsBoard: .init(width: 62, height: 84, centerY: 11)
            case .coneBarricade: .init(width: 92, height: 42, centerY: -5)
            case .equipmentTrunk: .init(width: 88, height: 52, centerY: 0)
            case .roverBattery: .init(width: 74, height: 76, centerY: 8)
            case .satelliteRelay: .init(width: 70, height: 88, centerY: 11)
            case .regolithBarricade: .init(width: 94, height: 48, centerY: -4)
            case .gravityCell: .init(width: 58, height: 86, centerY: 10)
            case .lunarVault: .init(width: 90, height: 58, centerY: 0)
            case .oxygenPod: .init(width: 62, height: 88, centerY: 12)
            case .meteorCrate: .init(width: 78, height: 92, centerY: 12)
            case .holoGate: .init(width: 98, height: 58, centerY: 0)
            case .crystalBarricade: .init(width: 86, height: 92, centerY: 12)
            case .artifactVault: .init(width: 86, height: 94, centerY: 12)
            }
        case .powerUp:
            return .init(width: 58, height: 64, centerY: 2)
        case .volatileCore:
            return .init(width: 54, height: 54, centerY: 0)
        }
    }

    private static func decorateVolatileCore(_ root: SKNode) {
        root.addChild(ellipse(size: .init(width: 46, height: 12), color: .black.withAlphaComponent(0.26), y: -27))
        let outer = circle(radius: 25, color: color(0.42, 0.03, 0.08).withAlphaComponent(0.88))
        outer.strokeColor = color(1, 0.46, 0.04)
        outer.lineWidth = 3
        outer.glowWidth = 10
        root.addChild(outer)
        let core = circle(radius: 13, color: color(1, 0.64, 0.06))
        core.strokeColor = .white
        core.lineWidth = 2
        root.addChild(core)
        for index in 0..<6 {
            let ray = rect(
                size: .init(width: 4, height: 12),
                color: color(1, 0.28, 0.02),
                radius: 2,
                y: 33,
                rotation: CGFloat(index) * .pi / 3
            )
            ray.position = CGPoint(
                x: sin(CGFloat(index) * .pi / 3) * 4,
                y: cos(CGFloat(index) * .pi / 3) * 4
            )
            outer.addChild(ray)
        }
    }

    private static func addFrostBands(to parent: SKNode, profile: StatusProfile) {
        for (index, yFactor) in [-0.34, -0.02, 0.28].enumerated() {
            let width = profile.width * (index == 1 ? 0.82 : 0.66)
            let band = SKShapeNode(path: frostBandPath(width: width, height: 8 + CGFloat(index)))
            band.fillColor = color(0.44, 0.88, 1).withAlphaComponent(index == 1 ? 0.34 : 0.25)
            band.strokeColor = color(0.80, 0.97, 1).withAlphaComponent(0.82)
            band.lineWidth = 1.2
            band.glowWidth = 1.5
            band.position = CGPoint(
                x: index.isMultiple(of: 2) ? -profile.width * 0.04 : profile.width * 0.05,
                y: profile.centerY + profile.height * yFactor
            )
            band.zRotation = index.isMultiple(of: 2) ? -0.08 : 0.07
            parent.addChild(band)
        }
    }

    private static func addIceCrystals(to parent: SKNode, profile: StatusProfile) {
        let anchors: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (-0.38, 0.25, 0.10, 0.25, -0.18),
            (0.38, 0.23, 0.11, 0.23, 0.18),
            (-0.24, -0.36, 0.09, 0.28, -0.07),
            (0.24, -0.35, 0.09, 0.25, 0.07),
            (-0.10, 0.43, 0.08, 0.19, -0.04),
            (0.11, 0.42, 0.07, 0.17, 0.04)
        ]
        for (index, anchor) in anchors.enumerated() {
            let shard = SKShapeNode(path: iceShardPath(
                width: max(5, profile.width * anchor.2),
                height: max(13, profile.height * anchor.3)
            ))
            shard.name = "status-ice-shard-\(index)"
            shard.fillColor = color(0.40, 0.84, 1).withAlphaComponent(0.53)
            shard.strokeColor = color(0.88, 0.99, 1)
            shard.lineWidth = 1.3
            shard.glowWidth = 2
            shard.position = CGPoint(
                x: profile.width * anchor.0,
                y: profile.centerY + profile.height * anchor.1
            )
            shard.zRotation = anchor.4
            parent.addChild(shard)
            let facet = SKShapeNode(path: iceFacetPath(
                width: max(5, profile.width * anchor.2),
                height: max(13, profile.height * anchor.3)
            ))
            facet.fillColor = .white.withAlphaComponent(0.24)
            facet.strokeColor = .clear
            shard.addChild(facet)
        }
    }

    private static func addFlames(
        to parent: SKNode,
        anchors: [(CGFloat, CGFloat, CGFloat)],
        profile: StatusProfile,
        foreground: Bool
    ) {
        for (index, anchor) in anchors.enumerated() {
            let height = profile.height * (foreground ? 0.28 : 0.38) * anchor.2
            let width = max(9, height * 0.52)
            let flame = SKShapeNode(path: flamePath(width: width, height: height))
            flame.name = "status-flame"
            flame.fillColor = index.isMultiple(of: 2)
                ? color(1, 0.24, 0.015).withAlphaComponent(foreground ? 0.90 : 0.70)
                : color(1, 0.55, 0.03).withAlphaComponent(foreground ? 0.88 : 0.65)
            flame.strokeColor = color(1, 0.82, 0.16).withAlphaComponent(0.78)
            flame.lineWidth = 1.1
            flame.glowWidth = foreground ? 3 : 5
            flame.position = CGPoint(
                x: profile.width * anchor.0,
                y: profile.centerY + profile.height * anchor.1
            )
            flame.xScale = index.isMultiple(of: 2) ? 1 : -1
            parent.addChild(flame)

            if foreground && index < 3 {
                let core = SKShapeNode(path: flamePath(width: width * 0.46, height: height * 0.58))
                core.fillColor = color(1, 0.88, 0.24).withAlphaComponent(0.92)
                core.strokeColor = .clear
                core.position.y = -height * 0.16
                flame.addChild(core)
            }
        }
    }

    private static func addEmbers(to parent: SKNode, profile: StatusProfile) {
        for index in 0..<6 {
            let ember = SKShapeNode(circleOfRadius: index.isMultiple(of: 2) ? 1.5 : 1)
            ember.name = "status-ember"
            ember.fillColor = index.isMultiple(of: 3) ? color(1, 0.88, 0.28) : color(1, 0.34, 0.03)
            ember.strokeColor = .clear
            ember.glowWidth = 2
            ember.position = CGPoint(
                x: profile.width * (-0.34 + CGFloat(index) * 0.14),
                y: profile.centerY + profile.height * (-0.12 + CGFloat(index % 3) * 0.24)
            )
            parent.addChild(ember)
        }
    }

    private static func addReverseStreaks(to parent: SKNode, profile: StatusProfile) {
        for index in 0..<5 {
            let streak = SKShapeNode(path: reverseChevronPath(width: 15, height: 9))
            streak.name = "status-reverse-streak"
            streak.fillColor = .clear
            streak.strokeColor = index.isMultiple(of: 2)
                ? color(0.24, 0.88, 1).withAlphaComponent(0.72)
                : color(0.74, 0.18, 1).withAlphaComponent(0.82)
            streak.lineWidth = 2.2
            streak.glowWidth = 3
            streak.position = CGPoint(
                x: (index.isMultiple(of: 2) ? -0.46 : 0.38) * profile.width,
                y: profile.centerY + (-0.38 + CGFloat(index) * 0.19) * profile.height
            )
            streak.xScale = index.isMultiple(of: 2) ? 1 : -1
            parent.addChild(streak)
        }
    }

    private static func addStunArcs(to parent: SKNode, profile: StatusProfile) {
        for index in 0..<5 {
            let path = CGMutablePath()
            let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            path.move(to: CGPoint(x: -12 * direction, y: -5))
            path.addLine(to: CGPoint(x: -4 * direction, y: 2))
            path.addLine(to: CGPoint(x: -8 * direction, y: 7))
            path.addLine(to: CGPoint(x: 9 * direction, y: 13))
            let arc = SKShapeNode(path: path)
            arc.name = "status-stun-arc"
            arc.fillColor = .clear
            arc.strokeColor = index.isMultiple(of: 2)
                ? color(0.20, 0.92, 1)
                : color(1, 0.82, 0.18)
            arc.lineWidth = 2.4
            arc.glowWidth = 5
            arc.position = CGPoint(
                x: (index.isMultiple(of: 2) ? -0.28 : 0.30) * profile.width,
                y: profile.centerY + (-0.34 + CGFloat(index) * 0.18) * profile.height
            )
            arc.zRotation = direction * 0.10
            parent.addChild(arc)
        }
    }

    private static func decoratePowerUp(_ root: SKNode, ability: TemporaryBallAbility) {
        root.addChild(ellipse(size: .init(width: 54, height: 14), color: .black.withAlphaComponent(0.24), y: -31))

        let aura = circle(radius: 31, color: powerColor(ability).withAlphaComponent(0.14))
        aura.strokeColor = powerColor(ability)
        aura.lineWidth = 3
        aura.glowWidth = 9
        aura.zPosition = -1
        root.addChild(aura)

        let trophy = SKNode()
        trophy.name = "power-up-trophy"
        root.addChild(trophy)

        for side in [-1.0, 1.0] {
            let handle = SKShapeNode(ellipseOf: .init(width: 22, height: 25))
            handle.position = CGPoint(x: side * 17, y: 7)
            handle.fillColor = .clear
            handle.strokeColor = color(1, 0.62, 0.04)
            handle.lineWidth = 5
            trophy.addChild(handle)
        }

        let cup = SKShapeNode(path: trophyCupPath())
        cup.fillColor = color(1, 0.72, 0.08)
        cup.strokeColor = color(1, 0.94, 0.48)
        cup.lineWidth = 2
        trophy.addChild(cup)
        trophy.addChild(rect(size: .init(width: 8, height: 15), color: color(1, 0.64, 0.04), radius: 3, y: -13))
        trophy.addChild(rect(size: .init(width: 34, height: 8), color: color(1, 0.72, 0.08), radius: 4, y: -23))
        trophy.addChild(rect(size: .init(width: 18, height: 4), color: .white.withAlphaComponent(0.42), radius: 2, x: -5, y: 13, rotation: -0.12))

        let badge = circle(radius: 9, color: color(0.03, 0.16, 0.34), y: 5)
        badge.strokeColor = .white
        badge.lineWidth = 1.5
        trophy.addChild(badge)

        let symbol = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        symbol.text = powerGlyph(ability)
        symbol.fontSize = 11
        symbol.fontColor = .white
        symbol.verticalAlignmentMode = .center
        symbol.horizontalAlignmentMode = .center
        symbol.position.y = 5
        trophy.addChild(symbol)
    }

    private static func powerColor(_ ability: TemporaryBallAbility) -> SKColor {
        switch ability {
        case .rapidFire: color(1, 0.78, 0.08)
        case .explosive: color(1, 0.28, 0.04)
        case .fire: color(1, 0.10, 0.03)
        case .ice: color(0.18, 0.84, 1)
        case .reverse: color(0.72, 0.24, 1)
        case .split: color(0.18, 0.92, 0.44)
        case .heatSeeking: color(0.12, 0.88, 1)
        case .orbitShot: color(0.58, 0.48, 1)
        case .solarPierce: color(1, 0.72, 0.08)
        }
    }

    private static func powerGlyph(_ ability: TemporaryBallAbility) -> String {
        switch ability {
        case .rapidFire: "⚡︎"
        case .explosive: "✹"
        case .fire: "▲"
        case .ice: "✦"
        case .reverse: "↶"
        case .split: "•••"
        case .heatSeeking: "◎"
        case .orbitShot: "◉"
        case .solarPierce: "☀"
        }
    }

    private static func decorateEnemy(_ root: SKNode, enemy: EnemyKind) {
        root.addChild(earthEnemyShadow(for: enemy))
        switch enemy {
        case .coneRunner:
            renderedEnemySprite(root, enemy: enemy, size: 78)
        case .dummyDefender:
            renderedEnemySprite(root, enemy: enemy, size: 80)
        case .tackleBot:
            renderedEnemySprite(root, enemy: enemy, size: 86)
        case .keeperDrone:
            renderedEnemySprite(root, enemy: enemy, size: 90)
        case .ballLauncher:
            renderedEnemySprite(root, enemy: enemy, size: 92)
        case .titanKeeper:
            renderedEnemySprite(root, enemy: enemy, size: 96)
        case .regolithRunner:
            renderedEnemySprite(root, enemy: enemy, size: 80)
        case .lunarHopper:
            renderedEnemySprite(root, enemy: enemy, size: 90)
        case .orbitDrone:
            renderedEnemySprite(root, enemy: enemy, size: 92)
        case .eclipseKeeper:
            renderedEnemySprite(root, enemy: enemy, size: 90)
        case .gravityStriker:
            renderedEnemySprite(root, enemy: enemy, size: 96)
        case .lunarWarden:
            renderedEnemySprite(root, enemy: enemy, size: 110)
        case .dustSprite:
            renderedEnemySprite(root, enemy: enemy, size: 80)
        case .roverRaider:
            renderedEnemySprite(root, enemy: enemy, size: 90)
        case .craterCrawler:
            renderedEnemySprite(root, enemy: enemy, size: 98)
        case .saucerKeeper:
            renderedEnemySprite(root, enemy: enemy, size: 94)
        case .plasmaStriker:
            renderedEnemySprite(root, enemy: enemy, size: 98)
        case .marsColossus:
            renderedEnemySprite(root, enemy: enemy, size: 110)
        }
    }

    @discardableResult
    private static func renderedEnemySprite(
        _ root: SKNode,
        enemy: EnemyKind,
        size: CGFloat
    ) -> SKNode {
        let rig = motionBody(on: root)
        guard let texture = renderedEnemyTextures[enemy] else { return rig }
        let sprite = SKSpriteNode(texture: texture)
        sprite.name = "body-sprite"
        sprite.size = CGSize(width: size, height: size)
        sprite.position.y = enemySpriteVerticalOffset(for: enemy)
        rig.addChild(sprite)
        return rig
    }

    private static func enemySpriteVerticalOffset(for enemy: EnemyKind) -> CGFloat {
        switch enemy {
        case .coneRunner: 3.5
        case .dummyDefender: 0
        case .tackleBot: 9.5
        case .keeperDrone: 9
        case .ballLauncher: 6
        case .titanKeeper: 12.5
        case .regolithRunner: 3
        case .lunarHopper: 8
        case .orbitDrone: 9
        case .eclipseKeeper: 5
        case .gravityStriker: 8
        case .lunarWarden: 13
        case .dustSprite: 3
        case .roverRaider: 5
        case .craterCrawler: 5
        case .saucerKeeper: 6
        case .plasmaStriker: 8
        case .marsColossus: 12
        }
    }

    private static func earthEnemyShadow(for enemy: EnemyKind) -> SKShapeNode {
        let size: CGSize = switch enemy {
        case .coneRunner: .init(width: 30, height: 7)
        case .dummyDefender: .init(width: 50, height: 10)
        case .tackleBot: .init(width: 44, height: 9)
        case .keeperDrone: .init(width: 58, height: 11)
        case .ballLauncher: .init(width: 38, height: 8)
        case .titanKeeper: .init(width: 62, height: 12)
        case .regolithRunner: .init(width: 38, height: 9)
        case .lunarHopper: .init(width: 50, height: 10)
        case .orbitDrone: .init(width: 62, height: 11)
        case .eclipseKeeper: .init(width: 56, height: 11)
        case .gravityStriker: .init(width: 54, height: 10)
        case .lunarWarden: .init(width: 80, height: 15)
        case .dustSprite: .init(width: 38, height: 9)
        case .roverRaider: .init(width: 58, height: 12)
        case .craterCrawler: .init(width: 68, height: 12)
        case .saucerKeeper: .init(width: 64, height: 12)
        case .plasmaStriker: .init(width: 58, height: 11)
        case .marsColossus: .init(width: 78, height: 15)
        }
        let shadow = ellipse(
            size: size,
            color: color(0.02, 0.10, 0.08).withAlphaComponent(0.20),
            y: -28
        )
        shadow.position.x = 2
        shadow.glowWidth = 4
        shadow.zPosition = -2
        return shadow
    }

    private static func healthBarHeight(for kind: TargetState.Kind) -> CGFloat {
        switch kind {
        case .enemy(let enemy):
            return switch enemy {
            case .tackleBot: 51
            case .keeperDrone: 54
            case .ballLauncher: 50
            case .titanKeeper: 66
            case .regolithRunner: 44
            case .lunarHopper: 50
            case .orbitDrone: 55
            case .eclipseKeeper: 52
            case .gravityStriker: 58
            case .lunarWarden: 72
            case .dustSprite: 44
            case .roverRaider: 50
            case .craterCrawler: 45
            case .saucerKeeper: 55
            case .plasmaStriker: 58
            case .marsColossus: 72
            default: 43
            }
        case .fieldObject(let object):
            return switch object {
            case .coneBarricade, .equipmentTrunk, .holoGate, .regolithBarricade, .lunarVault: 40
            case .ballCart: 53
            case .waterCooler, .tacticsBoard, .roverBattery, .satelliteRelay, .gravityCell: 61
            case .oxygenPod: 64
            case .meteorCrate, .crystalBarricade, .artifactVault: 68
            }
        case .powerUp:
            return 43
        case .volatileCore:
            return 0
        }
    }

    private static func inferredWorld(for kind: TargetState.Kind) -> WorldID {
        guard case .enemy(let enemy) = kind else { return .earth }
        if enemy.isLunar { return .moon }
        if enemy.isMartian { return .mars }
        return .earth
    }

    @discardableResult
    private static func robot(_ root: SKNode, body: SKColor, head: SKColor, wide: Bool) -> SKNode {
        let rig = motionBody(on: root)

        for side in [CGFloat(-1), CGFloat(1)] {
            let leg = articulatedLimb(
                name: side < 0 ? "left-leg" : "right-leg",
                position: CGPoint(x: side * 12, y: -12),
                rotation: side * 0.08
            )
            leg.addChild(circle(radius: 4, color: color(0.08, 0.12, 0.18)))
            leg.addChild(rect(size: .init(width: 9, height: 22), color: body, radius: 4, y: -10))
            leg.addChild(rect(size: .init(width: 14, height: 7), color: color(0.08, 0.12, 0.18), radius: 3, x: side * 2, y: -22))
            rig.addChild(leg)

            let arm = articulatedLimb(
                name: side < 0 ? "left-arm" : "right-arm",
                position: CGPoint(x: side * (wide ? 27 : 22), y: 8),
                rotation: side * 0.15
            )
            arm.addChild(rect(size: .init(width: wide ? 11 : 9, height: wide ? 27 : 23), color: body, radius: 4, y: -10))
            arm.addChild(circle(radius: wide ? 5 : 4, color: head, y: wide ? -24 : -21))
            rig.addChild(arm)
        }

        let torso = rect(size: .init(width: wide ? 48 : 38, height: 35), color: body, radius: 11, y: -1)
        torso.strokeColor = .white.withAlphaComponent(0.48)
        torso.lineWidth = 2
        rig.addChild(torso)
        rig.addChild(rect(size: .init(width: wide ? 31 : 24, height: 8), color: .white.withAlphaComponent(0.22), radius: 4, y: 8))
        let face = rect(size: .init(width: 34, height: 25), color: head, radius: 9, y: 24)
        face.strokeColor = .white.withAlphaComponent(0.55)
        face.lineWidth = 2
        rig.addChild(face)
        rig.addChild(circle(radius: 3.5, color: color(0.1, 0.9, 1), x: -7, y: 25))
        rig.addChild(circle(radius: 3.5, color: color(0.1, 0.9, 1), x: 7, y: 25))
        rig.addChild(rect(size: .init(width: 4, height: 8), color: .white.withAlphaComponent(0.65), radius: 2, y: 42))
        let antenna = circle(radius: 3, color: color(1, 0.72, 0.1), y: 47)
        antenna.name = "motion-light"
        rig.addChild(antenna)
        return rig
    }

    @discardableResult
    private static func alien(_ root: SKNode, body: SKColor, armor: SKColor, wide: Bool) -> SKNode {
        let rig = motionBody(on: root)
        let armOffset: CGFloat = wide ? 29 : 23
        for side in [CGFloat(-1), CGFloat(1)] {
            let leg = articulatedLimb(
                name: side < 0 ? "left-leg" : "right-leg",
                position: CGPoint(x: side * 12, y: -12),
                rotation: side * 0.10
            )
            leg.addChild(rect(size: .init(width: 10, height: 22), color: armor, radius: 5, y: -10))
            leg.addChild(rect(size: .init(width: 18, height: 8), color: color(0.10, 0.16, 0.28), radius: 4, x: side * 2, y: -22))
            rig.addChild(leg)

            let arm = articulatedLimb(
                name: side < 0 ? "left-arm" : "right-arm",
                position: CGPoint(x: side * armOffset, y: 8),
                rotation: side * 0.20
            )
            arm.addChild(rect(size: .init(width: 12, height: 27), color: armor, radius: 6, y: -11))
            arm.addChild(circle(radius: wide ? 8 : 7, color: body, x: side * 2, y: -25))
            rig.addChild(arm)
        }

        let torso = rect(size: .init(width: wide ? 48 : 38, height: 32), color: armor, radius: 13, y: -3)
        torso.strokeColor = color(0.28, 0.94, 1).withAlphaComponent(0.70)
        torso.lineWidth = 2
        rig.addChild(torso)
        rig.addChild(rect(size: .init(width: wide ? 36 : 28, height: 13), color: body.withAlphaComponent(0.45), radius: 6, y: 2))
        rig.addChild(rect(size: .init(width: wide ? 40 : 31, height: 5), color: color(0.10, 0.16, 0.30), radius: 2.5, y: -13))
        let chestLight = circle(radius: 4, color: color(0.24, 0.94, 1), y: 2)
        chestLight.name = "motion-light"
        chestLight.glowWidth = 3
        rig.addChild(chestLight)

        let head = SKShapeNode(ellipseOf: .init(width: wide ? 38 : 34, height: 28))
        head.fillColor = body
        head.strokeColor = .white.withAlphaComponent(0.58)
        head.lineWidth = 2
        head.position.y = 24
        rig.addChild(head)
        rig.addChild(circle(radius: 6, color: armor, x: wide ? -21 : -19, y: 24))
        rig.addChild(circle(radius: 6, color: armor, x: wide ? 21 : 19, y: 24))
        let highlight = SKShapeNode(ellipseOf: .init(width: 16, height: 7))
        highlight.fillColor = .white.withAlphaComponent(0.26)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: -5, y: 32)
        rig.addChild(highlight)
        for x in [-8.0, 0.0, 8.0] {
            let eye = circle(radius: 3, color: color(0.06, 0.12, 0.24), x: x, y: 26)
            eye.strokeColor = color(0.42, 1, 0.94)
            eye.lineWidth = 1
            eye.glowWidth = 3
            rig.addChild(eye)
        }
        rig.addChild(rect(size: .init(width: 12, height: 2), color: color(0.08, 0.14, 0.25).withAlphaComponent(0.55), radius: 1, y: 18))
        rig.addChild(rect(size: .init(width: 4, height: 10), color: body, radius: 2, y: 43))
        let antenna = circle(radius: 3, color: color(0.28, 0.94, 1), y: 49)
        antenna.glowWidth = 3
        rig.addChild(antenna)
        return rig
    }

    private static func motionBody(on root: SKNode) -> SKNode {
        let rig = SKNode()
        rig.name = "motion-body"
        root.addChild(rig)
        return rig
    }

    private static func articulatedLimb(name: String, position: CGPoint, rotation: CGFloat) -> SKNode {
        let limb = SKNode()
        limb.name = name
        limb.position = position
        limb.zRotation = rotation
        return limb
    }

    private static func setLimbPose(on node: TargetRenderNode, stride: CGFloat, armSwing: CGFloat) {
        node.leftLeg?.zRotation = -0.09 + stride
        node.rightLeg?.zRotation = 0.09 - stride
        node.leftArm?.zRotation = -0.18 + armSwing
        node.rightArm?.zRotation = 0.18 - armSwing
    }

    private static func decorateObject(_ root: SKNode, object: FieldObjectKind) {
        let presentation = fieldObjectPresentation(for: object)
        let shadow = ellipse(
            size: presentation.shadowSize,
            color: presentation.shadowColor,
            y: -26
        )
        shadow.position.x = 2
        shadow.glowWidth = 4
        shadow.zPosition = -2
        root.addChild(shadow)

        let rig = motionBody(on: root)
        guard let texture = renderedFieldObjectTextures[object] else { return }
        let sprite = SKSpriteNode(texture: texture)
        sprite.name = "body-sprite"
        sprite.size = CGSize(width: presentation.size, height: presentation.size)
        sprite.position.y = presentation.verticalOffset
        if object.isLunar {
            sprite.color = color(0.58, 0.72, 1)
            sprite.colorBlendFactor = 0.42
        }
        rig.addChild(sprite)
    }

    private static func fieldObjectPresentation(
        for object: FieldObjectKind
    ) -> (size: CGFloat, verticalOffset: CGFloat, shadowSize: CGSize, shadowColor: SKColor) {
        let earthShadow = color(0.02, 0.10, 0.08).withAlphaComponent(0.21)
        let marsShadow = color(0.12, 0.025, 0.06).withAlphaComponent(0.25)
        return switch object {
        case .ballCart: (88, 13, .init(width: 54, height: 11), earthShadow)
        case .waterCooler: (90, 15, .init(width: 42, height: 9), earthShadow)
        case .tacticsBoard: (94, 16, .init(width: 54, height: 10), earthShadow)
        case .coneBarricade: (100, -8, .init(width: 78, height: 10), earthShadow)
        case .equipmentTrunk: (96, 0, .init(width: 76, height: 12), earthShadow)
        case .roverBattery: (90, 13, .init(width: 56, height: 11), earthShadow)
        case .satelliteRelay: (96, 16, .init(width: 58, height: 10), earthShadow)
        case .regolithBarricade: (102, -7, .init(width: 80, height: 10), earthShadow)
        case .gravityCell: (92, 15, .init(width: 44, height: 9), earthShadow)
        case .lunarVault: (98, 0, .init(width: 78, height: 12), earthShadow)
        case .oxygenPod: (96, 17, .init(width: 54, height: 11), marsShadow)
        case .meteorCrate: (102, 19, .init(width: 68, height: 13), marsShadow)
        case .holoGate: (106, 0, .init(width: 90, height: 13), marsShadow)
        case .crystalBarricade: (102, 19, .init(width: 76, height: 13), marsShadow)
        case .artifactVault: (104, 20, .init(width: 76, height: 14), marsShadow)
        }
    }

    private static func circle(radius: CGFloat, color: SKColor, x: CGFloat = 0, y: CGFloat = 0) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: radius)
        node.fillColor = color
        node.strokeColor = .clear
        node.position = CGPoint(x: x, y: y)
        return node
    }

    private static func rect(size: CGSize, color: SKColor, radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0, rotation: CGFloat = 0) -> SKShapeNode {
        let node = SKShapeNode(rectOf: size, cornerRadius: radius)
        node.fillColor = color
        node.strokeColor = .clear
        node.position = CGPoint(x: x, y: y)
        node.zRotation = rotation
        return node
    }

    private static func ellipse(size: CGSize, color: SKColor, y: CGFloat) -> SKShapeNode {
        let node = SKShapeNode(ellipseOf: size)
        node.fillColor = color
        node.strokeColor = .clear
        node.position.y = y
        return node
    }

    private static func triangle(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: height / 2))
        path.addLine(to: CGPoint(x: -width / 2, y: -height / 2))
        path.addLine(to: CGPoint(x: width / 2, y: -height / 2))
        path.closeSubpath()
        return path
    }

    private static func trophyCupPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -20, y: 18))
        path.addLine(to: CGPoint(x: 20, y: 18))
        path.addCurve(
            to: CGPoint(x: 11, y: -4),
            control1: CGPoint(x: 20, y: 7),
            control2: CGPoint(x: 17, y: -1)
        )
        path.addCurve(
            to: CGPoint(x: -11, y: -4),
            control1: CGPoint(x: 5, y: -8),
            control2: CGPoint(x: -5, y: -8)
        )
        path.addCurve(
            to: CGPoint(x: -20, y: 18),
            control1: CGPoint(x: -17, y: -1),
            control2: CGPoint(x: -20, y: 7)
        )
        path.closeSubpath()
        return path
    }

    private static func hairPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: .init(x: -13, y: -2))
        path.addLine(to: .init(x: -10, y: 8))
        path.addLine(to: .init(x: -4, y: 4))
        path.addLine(to: .init(x: 0, y: 11))
        path.addLine(to: .init(x: 5, y: 4))
        path.addLine(to: .init(x: 12, y: 8))
        path.addLine(to: .init(x: 13, y: -2))
        path.closeSubpath()
        return path
    }

    private static func jerseyPath(topWidth: CGFloat, bottomWidth: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -topWidth / 2, y: height / 2 - 5))
        path.addLine(to: CGPoint(x: -topWidth / 2 + 5, y: height / 2))
        path.addLine(to: CGPoint(x: topWidth / 2 - 5, y: height / 2))
        path.addLine(to: CGPoint(x: topWidth / 2, y: height / 2 - 5))
        path.addLine(to: CGPoint(x: bottomWidth / 2, y: -height / 2))
        path.addLine(to: CGPoint(x: -bottomWidth / 2, y: -height / 2))
        path.closeSubpath()
        return path
    }

    private static func bootPath(width: CGFloat, height: CGFloat, direction: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let heelX = -direction * width * 0.42
        let toeX = direction * width * 0.58
        path.move(to: CGPoint(x: heelX, y: height * 0.42))
        path.addLine(to: CGPoint(x: direction * width * 0.20, y: height * 0.42))
        path.addLine(to: CGPoint(x: toeX, y: 0))
        path.addLine(to: CGPoint(x: direction * width * 0.42, y: -height * 0.45))
        path.addLine(to: CGPoint(x: heelX, y: -height * 0.45))
        path.closeSubpath()
        return path
    }

    private static func hexagon(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for index in 0..<6 {
            let angle = CGFloat(index) * .pi / 3
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    private static func frostBandPath(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -width * 0.5, y: 0))
        path.addLine(to: CGPoint(x: -width * 0.34, y: height * 0.48))
        path.addLine(to: CGPoint(x: -width * 0.18, y: height * 0.14))
        path.addLine(to: CGPoint(x: 0, y: height * 0.62))
        path.addLine(to: CGPoint(x: width * 0.19, y: height * 0.18))
        path.addLine(to: CGPoint(x: width * 0.36, y: height * 0.52))
        path.addLine(to: CGPoint(x: width * 0.5, y: 0))
        path.addLine(to: CGPoint(x: width * 0.31, y: -height * 0.30))
        path.addLine(to: CGPoint(x: width * 0.08, y: -height * 0.08))
        path.addLine(to: CGPoint(x: -width * 0.20, y: -height * 0.34))
        path.closeSubpath()
        return path
    }

    private static func iceShardPath(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -width * 0.5, y: height * 0.42))
        path.addLine(to: CGPoint(x: width * 0.5, y: height * 0.42))
        path.addLine(to: CGPoint(x: width * 0.22, y: -height * 0.10))
        path.addLine(to: CGPoint(x: 0, y: -height * 0.58))
        path.addLine(to: CGPoint(x: -width * 0.20, y: -height * 0.12))
        path.closeSubpath()
        return path
    }

    private static func iceFacetPath(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -width * 0.18, y: height * 0.34))
        path.addLine(to: CGPoint(x: width * 0.15, y: height * 0.30))
        path.addLine(to: CGPoint(x: 0, y: -height * 0.45))
        path.closeSubpath()
        return path
    }

    private static func flamePath(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: height * 0.58))
        path.addCurve(
            to: CGPoint(x: width * 0.48, y: -height * 0.12),
            control1: CGPoint(x: width * 0.08, y: height * 0.30),
            control2: CGPoint(x: width * 0.54, y: height * 0.18)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: -height * 0.52),
            control1: CGPoint(x: width * 0.42, y: -height * 0.38),
            control2: CGPoint(x: width * 0.18, y: -height * 0.52)
        )
        path.addCurve(
            to: CGPoint(x: -width * 0.46, y: -height * 0.08),
            control1: CGPoint(x: -width * 0.28, y: -height * 0.50),
            control2: CGPoint(x: -width * 0.50, y: -height * 0.34)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: height * 0.58),
            control1: CGPoint(x: -width * 0.32, y: height * 0.12),
            control2: CGPoint(x: -width * 0.11, y: height * 0.30)
        )
        path.closeSubpath()
        return path
    }

    private static func reverseChevronPath(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: width * 0.5, y: height * 0.5))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: width * 0.5, y: -height * 0.5))
        path.move(to: CGPoint(x: 0, y: height * 0.5))
        path.addLine(to: CGPoint(x: -width * 0.5, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -height * 0.5))
        return path
    }

    private static func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> SKColor {
        SKColor(red: red, green: green, blue: blue, alpha: 1)
    }
}

private extension EnemyKind {
    var isLunar: Bool {
        switch self {
        case .regolithRunner, .lunarHopper, .orbitDrone, .eclipseKeeper, .gravityStriker, .lunarWarden:
            true
        default:
            false
        }
    }

    var isMartian: Bool {
        switch self {
        case .dustSprite, .roverRaider, .craterCrawler, .saucerKeeper, .plasmaStriker, .marsColossus:
            true
        default:
            false
        }
    }
}

private extension FieldObjectKind {
    var isLunar: Bool {
        switch self {
        case .roverBattery, .satelliteRelay, .regolithBarricade, .gravityCell, .lunarVault:
            true
        default:
            false
        }
    }
}
