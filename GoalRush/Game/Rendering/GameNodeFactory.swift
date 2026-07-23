import SpriteKit

enum GameNodeFactory {
    static func player(loadout: GearLoadout = .empty) -> SKNode {
        let root = SKNode()
        root.name = "player"
        let shadow = ellipse(size: .init(width: 58, height: 16), color: .black.withAlphaComponent(0.26), y: -31)
        shadow.name = "shadow"
        root.addChild(shadow)

        let body = SKNode()
        body.name = "body"
        root.addChild(body)

        let legs = playerLegs(legID: loadout.item(in: .legs), footID: loadout.item(in: .feet))
        legs.zPosition = 0
        body.addChild(legs)

        let hands = playerHands(loadout.item(in: .hands))
        hands.zPosition = 3
        body.addChild(hands)

        let torso = playerTorso(loadout.item(in: .torso))
        torso.zPosition = 2
        body.addChild(torso)

        let head = playerHead(loadout.item(in: .head))
        head.zPosition = 4
        body.addChild(head)
        return root
    }

    static func animateKick(on player: SKNode, reducedMotion: Bool) {
        guard let body = player.childNode(withName: "body"),
              let legs = body.childNode(withName: "slot-legs"),
              let kickingLeg = legs.childNode(withName: "kicking-leg"),
              let plantLeg = legs.childNode(withName: "plant-leg") else { return }

        body.removeAction(forKey: "kick-body")
        kickingLeg.removeAction(forKey: "kick-leg")
        plantLeg.removeAction(forKey: "plant-leg")

        let windupAngle: CGFloat = reducedMotion ? -0.18 : -0.52
        let strikeAngle: CGFloat = reducedMotion ? 0.38 : 1.02
        kickingLeg.run(.sequence([
            .rotate(toAngle: windupAngle, duration: 0.12, shortestUnitArc: true),
            .rotate(toAngle: strikeAngle, duration: 0.10, shortestUnitArc: true),
            .rotate(toAngle: 0.08, duration: 0.18, shortestUnitArc: true)
        ]), withKey: "kick-leg")
        plantLeg.run(.sequence([
            .rotate(toAngle: -0.20, duration: 0.12, shortestUnitArc: true),
            .rotate(toAngle: -0.08, duration: 0.28, shortestUnitArc: true)
        ]), withKey: "plant-leg")
        body.run(.sequence([
            .group([.moveBy(x: 0, y: reducedMotion ? 1 : 4, duration: 0.10), .rotate(toAngle: -0.07, duration: 0.10, shortestUnitArc: true)]),
            .group([.moveTo(y: 0, duration: 0.22), .rotate(toAngle: 0, duration: 0.22, shortestUnitArc: true)])
        ]), withKey: "kick-body")
    }

    static func target(_ target: TargetState) -> SKNode {
        let root = SKNode()
        switch target.kind {
        case .enemy(let enemy): decorateEnemy(root, enemy: enemy)
        case .fieldObject(let object): decorateObject(root, object: object)
        }
        let health = SKShapeNode(rectOf: .init(width: 48, height: 5), cornerRadius: 2.5)
        health.name = "health-background"
        health.fillColor = .black.withAlphaComponent(0.45)
        health.strokeColor = .clear
        health.position.y = 43
        root.addChild(health)
        let fill = SKShapeNode(rectOf: .init(width: 46, height: 3), cornerRadius: 1.5)
        fill.name = "health-fill"
        fill.fillColor = color(0.16, 0.92, 0.42)
        fill.strokeColor = .clear
        health.addChild(fill)
        return root
    }

    static func animateTarget(on node: SKNode, kind: TargetState.Kind, phase: Double, reducedMotion: Bool) {
        guard case .enemy(let enemy) = kind,
              let rig = node.childNode(withName: "motion-body") else { return }

        let intensity: CGFloat = reducedMotion ? 0.28 : 1
        let time = CGFloat(phase)
        let pulse = CGFloat(0.78 + sin(phase * 5.2) * 0.22)
        for child in rig.children where child.name == "motion-light" {
            child.alpha = pulse
        }

        if enemy == .coneRunner {
            let wobble = sin(time * 9.5)
            rig.position = CGPoint(x: wobble * 1.5 * intensity, y: abs(cos(time * 9.5)) * 2.8 * intensity)
            rig.zRotation = wobble * 0.13 * intensity
            return
        }

        if enemy == .saucerKeeper {
            let hover = sin(time * 5.4)
            rig.position = CGPoint(x: hover * 1.4 * intensity, y: hover * 4.2 * intensity)
            rig.zRotation = sin(time * 3.1) * 0.055 * intensity
            setLimbPose(on: rig, stride: sin(time * 4.2) * 0.08 * intensity, armSwing: 0.06 * intensity)
            return
        }

        let movement: (cadence: CGFloat, stride: CGFloat, bob: CGFloat, sway: CGFloat) = switch enemy {
        case .tackleBot, .craterCrawler:
            (11.2, 0.43, 3.8, 0.045)
        case .dustSprite:
            (9.6, 0.36, 3.4, 0.035)
        case .dummyDefender, .roverRaider:
            (6.3, 0.28, 2.5, 0.024)
        case .keeperDrone:
            (4.7, 0.21, 2.0, 0.018)
        case .ballLauncher, .plasmaStriker:
            (5.5, 0.24, 2.2, 0.020)
        case .titanKeeper, .marsColossus:
            (3.5, 0.15, 2.8, 0.014)
        case .coneRunner, .saucerKeeper:
            (6, 0.2, 2, 0.02)
        }

        let step = sin(time * movement.cadence)
        rig.position = CGPoint(x: 0, y: abs(cos(time * movement.cadence)) * movement.bob * intensity)
        rig.zRotation = step * movement.sway * intensity
        setLimbPose(
            on: rig,
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
        let ball = circle(radius: hostile ? 9 : 8, color: hostile ? color(1, 0.28, 0.08) : .white)
        ball.strokeColor = hostile ? color(0.45, 0.04, 0.02) : color(0.05, 0.18, 0.55)
        ball.lineWidth = 3
        ball.name = "ball"
        root.addChild(ball)
        return root
    }

    static func rewardToken() -> SKNode {
        let token = SKShapeNode(path: hexagon(radius: 13))
        token.fillColor = color(1, 0.72, 0.10)
        token.strokeColor = .white
        token.lineWidth = 2
        token.glowWidth = 4
        return token
    }

    static func updateHealth(on node: SKNode, ratio: Double) {
        guard let fill = node.childNode(withName: "health-background/health-fill") else { return }
        fill.xScale = max(0.02, ratio)
        fill.position.x = CGFloat(-23 * (1 - ratio))
        if let shape = fill as? SKShapeNode {
            shape.fillColor = ratio > 0.5 ? color(0.16, 0.92, 0.42) : (ratio > 0.25 ? color(1, 0.72, 0.10) : color(1, 0.22, 0.08))
        }
    }

    private static func decorateEnemy(_ root: SKNode, enemy: EnemyKind) {
        root.addChild(ellipse(size: .init(width: 48, height: 13), color: .black.withAlphaComponent(0.20), y: -27))
        switch enemy {
        case .coneRunner:
            let rig = motionBody(on: root)
            let cone = SKShapeNode(path: triangle(width: 34, height: 48))
            cone.fillColor = color(1, 0.36, 0.05)
            cone.strokeColor = .white
            cone.lineWidth = 4
            rig.addChild(cone)
            rig.addChild(circle(radius: 6, color: color(0.08, 0.16, 0.25), y: 2))
        case .dummyDefender:
            robot(root, body: color(1, 0.38, 0.08), head: color(0.97, 0.83, 0.58), wide: false)
        case .tackleBot:
            robot(root, body: color(0.96, 0.18, 0.12), head: color(0.18, 0.18, 0.22), wide: true)
        case .keeperDrone:
            let rig = robot(root, body: color(1, 0.72, 0.08), head: color(0.10, 0.26, 0.42), wide: true)
            let shield = SKShapeNode(rectOf: .init(width: 50, height: 34), cornerRadius: 12)
            shield.fillColor = color(0.08, 0.72, 0.92).withAlphaComponent(0.35)
            shield.strokeColor = color(0.30, 0.92, 1)
            shield.lineWidth = 3
            shield.position.y = -2
            rig.addChild(shield)
        case .ballLauncher:
            let rig = robot(root, body: color(0.56, 0.18, 0.74), head: color(0.10, 0.12, 0.18), wide: false)
            rig.addChild(circle(radius: 10, color: color(1, 0.30, 0.08), x: 22, y: 1))
        case .titanKeeper:
            let rig = robot(root, body: color(1, 0.62, 0.06), head: color(0.08, 0.14, 0.22), wide: true)
            let core = circle(radius: 9, color: color(0.08, 0.88, 1), y: 1)
            core.name = "motion-light"
            core.glowWidth = 5
            rig.addChild(core)
        case .dustSprite:
            let rig = alien(root, body: color(0.48, 0.92, 0.36), armor: color(0.42, 0.18, 0.72), wide: false)
            rig.addChild(circle(radius: 3, color: color(0.08, 0.12, 0.22), x: 0, y: 28))
        case .roverRaider:
            let rig = alien(root, body: color(0.76, 0.88, 0.42), armor: color(0.82, 0.24, 0.18), wide: true)
            rig.addChild(rect(size: .init(width: 42, height: 8), color: color(0.14, 0.16, 0.26), radius: 4, y: -25))
        case .craterCrawler:
            let rig = alien(root, body: color(0.68, 0.34, 0.86), armor: color(0.10, 0.72, 0.80), wide: true)
            for x in [-27.0, 27.0] {
                rig.addChild(rect(size: .init(width: 22, height: 7), color: color(0.58, 0.24, 0.76), radius: 3, x: x, y: -16, rotation: x < 0 ? -0.35 : 0.35))
            }
        case .saucerKeeper:
            let rig = alien(root, body: color(0.40, 0.90, 0.72), armor: color(0.18, 0.28, 0.72), wide: false)
            let saucer = SKShapeNode(ellipseOf: .init(width: 64, height: 22))
            saucer.fillColor = color(0.12, 0.72, 0.90).withAlphaComponent(0.38)
            saucer.strokeColor = color(0.40, 0.96, 1)
            saucer.lineWidth = 3
            saucer.position.y = -4
            rig.addChild(saucer)
        case .plasmaStriker:
            let rig = alien(root, body: color(0.84, 0.44, 0.92), armor: color(0.20, 0.14, 0.42), wide: false)
            let plasma = circle(radius: 11, color: color(0.18, 0.92, 1), x: 23, y: 1)
            plasma.name = "motion-light"
            plasma.glowWidth = 6
            rig.addChild(plasma)
        case .marsColossus:
            let rig = alien(root, body: color(0.48, 0.96, 0.42), armor: color(0.72, 0.12, 0.22), wide: true)
            let core = circle(radius: 10, color: color(0.86, 0.24, 1), y: 0)
            core.name = "motion-light"
            core.glowWidth = 7
            rig.addChild(core)
        }
    }

    private static func playerHead(_ id: GearID?) -> SKNode {
        let slot = SKNode()
        slot.name = "slot-head"
        let variant = SKNode()
        variant.name = variantName(id)

        switch id {
        case .earthVisor:
            variant.addChild(rect(size: .init(width: 12, height: 8), color: color(0.06, 0.18, 0.44), radius: 3, y: 21))
            let helmet = circle(radius: 16, color: color(0.025, 0.10, 0.30), y: 33)
            helmet.strokeColor = color(1, 0.72, 0.10)
            helmet.lineWidth = 2.5
            variant.addChild(helmet)
            variant.addChild(rect(size: .init(width: 28, height: 10), color: color(0.10, 0.88, 1).withAlphaComponent(0.86), radius: 5, y: 35))
            variant.addChild(rect(size: .init(width: 22, height: 9), color: color(0.08, 0.26, 0.58), radius: 4, y: 25))
            variant.addChild(rect(size: .init(width: 5, height: 10), color: color(1, 0.72, 0.10), radius: 2, x: -15, y: 31))
            variant.addChild(rect(size: .init(width: 5, height: 10), color: color(1, 0.72, 0.10), radius: 2, x: 15, y: 31))
            variant.addChild(rect(size: .init(width: 8, height: 7), color: color(0.10, 0.84, 0.92), radius: 3, y: 50))
        case .marsLens:
            variant.addChild(rect(size: .init(width: 13, height: 8), color: color(0.22, 0.08, 0.34), radius: 3, y: 21))
            let helmet = circle(radius: 17, color: color(0.22, 0.07, 0.36), y: 33)
            helmet.strokeColor = color(0.24, 0.92, 1)
            helmet.lineWidth = 2.5
            variant.addChild(helmet)
            let faceplate = rect(size: .init(width: 27, height: 20), color: color(0.04, 0.16, 0.30), radius: 8, y: 33)
            faceplate.strokeColor = color(0.22, 0.94, 1)
            faceplate.lineWidth = 1.5
            variant.addChild(faceplate)
            let lens = circle(radius: 7, color: color(0.88, 0.24, 1).withAlphaComponent(0.82), x: 6, y: 34)
            lens.strokeColor = color(0.26, 0.96, 1)
            lens.lineWidth = 2
            lens.glowWidth = 2
            variant.addChild(lens)
            for side in [CGFloat(-1), CGFloat(1)] {
                let pod = rect(size: .init(width: 7, height: 14), color: color(0.42, 0.12, 0.62), radius: 3, x: side * 17, y: 33)
                pod.strokeColor = color(0.22, 0.94, 1)
                pod.lineWidth = 1.5
                variant.addChild(pod)
            }
        default:
            variant.name = "variant-base"
            variant.addChild(rect(size: .init(width: 10, height: 8), color: color(0.94, 0.66, 0.42), radius: 3, y: 22))
            let head = circle(radius: 13, color: color(0.96, 0.70, 0.47), y: 32)
            head.strokeColor = color(0.35, 0.15, 0.08)
            head.lineWidth = 1.5
            variant.addChild(head)
            let hair = SKShapeNode(path: hairPath())
            hair.fillColor = color(0.025, 0.09, 0.29)
            hair.strokeColor = color(0.08, 0.28, 0.64)
            hair.lineWidth = 1.5
            hair.position.y = 38
            variant.addChild(hair)
            variant.addChild(circle(radius: 1.3, color: color(0.08, 0.10, 0.16), x: -5, y: 32))
            variant.addChild(circle(radius: 1.3, color: color(0.08, 0.10, 0.16), x: 5, y: 32))
        }
        slot.addChild(variant)
        return slot
    }

    private static func playerTorso(_ id: GearID?) -> SKNode {
        let slot = SKNode()
        slot.name = "slot-torso"
        let variant = SKNode()
        variant.name = variantName(id)

        switch id {
        case .earthJersey:
            let jersey = SKShapeNode(path: jerseyPath(topWidth: 44, bottomWidth: 34, height: 37))
            jersey.name = "torso-shell"
            jersey.position.y = 2
            jersey.fillColor = color(0.025, 0.10, 0.34)
            jersey.strokeColor = color(1, 0.72, 0.10)
            jersey.lineWidth = 2.5
            variant.addChild(jersey)
            variant.addChild(rect(size: .init(width: 42, height: 9), color: color(1, 0.72, 0.10), radius: 3, y: 13))
            variant.addChild(rect(size: .init(width: 5, height: 18), color: color(0.10, 0.82, 0.90), radius: 2.5, x: -6, y: 3, rotation: -0.38))
            variant.addChild(rect(size: .init(width: 5, height: 18), color: color(0.10, 0.82, 0.90), radius: 2.5, x: 6, y: 3, rotation: 0.38))
            variant.addChild(playerNumber(color: .white, y: -6))
        case .marsCore:
            let armor = SKShapeNode(path: jerseyPath(topWidth: 44, bottomWidth: 34, height: 37))
            armor.name = "torso-shell"
            armor.position.y = 2
            armor.fillColor = color(0.20, 0.07, 0.34)
            armor.strokeColor = color(0.24, 0.94, 1)
            armor.lineWidth = 2.5
            variant.addChild(armor)
            variant.addChild(rect(size: .init(width: 31, height: 30), color: color(0.15, 0.06, 0.27), radius: 8, y: 1))
            variant.addChild(rect(size: .init(width: 14, height: 8), color: color(0.54, 0.18, 0.76), radius: 4, x: -15, y: 14, rotation: -0.14))
            variant.addChild(rect(size: .init(width: 14, height: 8), color: color(0.54, 0.18, 0.76), radius: 4, x: 15, y: 14, rotation: 0.14))
            variant.addChild(rect(size: .init(width: 31, height: 5), color: color(0.22, 0.90, 0.98), radius: 2, y: -14))
            let core = SKShapeNode(path: hexagon(radius: 7.5))
            core.fillColor = color(0.88, 0.20, 1)
            core.strokeColor = color(0.30, 0.96, 1)
            core.lineWidth = 2
            core.glowWidth = 2
            core.position.y = 3
            variant.addChild(core)
        default:
            variant.name = "variant-base"
            let torso = rect(size: .init(width: 42, height: 36), color: color(0.025, 0.25, 0.76), radius: 11, y: 2)
            torso.name = "torso-shell"
            torso.strokeColor = color(0.08, 0.72, 0.96)
            torso.lineWidth = 2
            variant.addChild(torso)
            variant.addChild(rect(size: .init(width: 7, height: 31), color: color(0.05, 0.78, 0.80), radius: 3, x: -12, y: 2))
            variant.addChild(rect(size: .init(width: 7, height: 31), color: color(0.05, 0.78, 0.80), radius: 3, x: 12, y: 2))
            variant.addChild(playerNumber(color: .white, y: 3))
        }
        slot.addChild(variant)
        return slot
    }

    private static func playerHands(_ id: GearID?) -> SKNode {
        let slot = SKNode()
        slot.name = "slot-hands"
        let variant = SKNode()
        variant.name = variantName(id)
        let validID: GearID? = switch id {
        case .earthGloves, .marsGauntlets: id
        default: nil
        }
        if validID == nil { variant.name = "variant-base" }

        for side in [CGFloat(-1), CGFloat(1)] {
            let arm = SKNode()
            arm.name = side < 0 ? "left-arm" : "right-arm"
            arm.position = CGPoint(x: side * 20, y: 11)
            arm.zRotation = side * -0.16
            switch validID {
            case .earthGloves:
                let shoulder = circle(radius: 7, color: color(1, 0.72, 0.10), y: -1)
                shoulder.strokeColor = .white.withAlphaComponent(0.40)
                shoulder.lineWidth = 1.5
                arm.addChild(shoulder)
                arm.addChild(rect(size: .init(width: 11, height: 15), color: color(0.025, 0.12, 0.38), radius: 5, y: -9))
                arm.addChild(rect(size: .init(width: 10, height: 11), color: color(0.08, 0.76, 0.84), radius: 4, y: -19))
                let glove = rect(size: .init(width: 13, height: 10), color: color(1, 0.78, 0.12), radius: 5, y: -25)
                glove.strokeColor = color(0.08, 0.72, 0.82)
                glove.lineWidth = 1.5
                arm.addChild(glove)
            case .marsGauntlets:
                let shoulder = rect(size: .init(width: 16, height: 11), color: color(0.58, 0.18, 0.78), radius: 5, y: -1, rotation: side * 0.10)
                shoulder.strokeColor = color(0.24, 0.94, 1)
                shoulder.lineWidth = 1.5
                arm.addChild(shoulder)
                arm.addChild(rect(size: .init(width: 10, height: 14), color: color(0.16, 0.07, 0.28), radius: 4, y: -10))
                let gauntlet = rect(size: .init(width: 15, height: 17), color: color(0.12, 0.82, 0.94), radius: 6, y: -21)
                gauntlet.strokeColor = color(0.88, 0.26, 1)
                gauntlet.lineWidth = 2
                gauntlet.glowWidth = 1
                arm.addChild(gauntlet)
                arm.addChild(circle(radius: 3, color: color(0.94, 0.30, 1), y: -21))
            default:
                arm.addChild(rect(size: .init(width: 11, height: 14), color: color(0.025, 0.30, 0.82), radius: 5, y: -5))
                arm.addChild(rect(size: .init(width: 8, height: 12), color: color(0.94, 0.66, 0.42), radius: 4, y: -15))
                arm.addChild(circle(radius: 5, color: color(0.96, 0.70, 0.47), y: -23))
            }
            variant.addChild(arm)
        }
        slot.addChild(variant)
        return slot
    }

    private static func playerLegs(legID: GearID?, footID: GearID?) -> SKNode {
        let slot = SKNode()
        slot.name = "slot-legs"
        for side in [CGFloat(-1), CGFloat(1)] {
            let joint = SKNode()
            joint.name = side < 0 ? "plant-leg" : "kicking-leg"
            joint.position = CGPoint(x: side * 10, y: -13)
            joint.zRotation = side * 0.08
            joint.addChild(playerLegVariant(legID, side: side))
            joint.addChild(playerFootVariant(footID, side: side))
            slot.addChild(joint)
        }
        return slot
    }

    private static func playerLegVariant(_ id: GearID?, side: CGFloat) -> SKNode {
        let variant = SKNode()
        variant.name = id.map { "leg-variant-\($0.rawValue)" } ?? "leg-variant-base"
        switch id {
        case .earthGuards:
            variant.addChild(rect(size: .init(width: 15, height: 11), color: color(0.025, 0.11, 0.34), radius: 5, y: -4, rotation: side * 0.04))
            let guardPlate = rect(size: .init(width: 13, height: 18), color: color(0.08, 0.76, 0.84), radius: 5, y: -17)
            guardPlate.strokeColor = color(1, 0.72, 0.10)
            guardPlate.lineWidth = 2
            variant.addChild(guardPlate)
            variant.addChild(rect(size: .init(width: 8, height: 3), color: color(1, 0.78, 0.12), radius: 1.5, y: -17))
        case .marsGuards:
            variant.addChild(rect(size: .init(width: 16, height: 12), color: color(0.20, 0.07, 0.34), radius: 5, y: -4, rotation: side * 0.06))
            let guardPlate = rect(size: .init(width: 15, height: 20), color: color(0.54, 0.17, 0.76), radius: 6, y: -18)
            guardPlate.strokeColor = color(0.22, 0.94, 1)
            guardPlate.lineWidth = 2
            variant.addChild(guardPlate)
            variant.addChild(circle(radius: 3.5, color: color(0.22, 0.94, 1), y: -12))
            variant.addChild(rect(size: .init(width: 4, height: 11), color: color(0.88, 0.26, 1), radius: 2, y: -21))
        default:
            variant.name = "leg-variant-base"
            variant.addChild(rect(size: .init(width: 13, height: 11), color: color(0.04, 0.22, 0.66), radius: 5, y: -4))
            variant.addChild(rect(size: .init(width: 10, height: 17), color: color(0.08, 0.52, 0.78), radius: 5, y: -17))
        }
        return variant
    }

    private static func playerFootVariant(_ id: GearID?, side: CGFloat) -> SKNode {
        let variant = SKNode()
        variant.name = id.map { "foot-variant-\($0.rawValue)" } ?? "foot-variant-base"
        switch id {
        case .earthCleats:
            let cleat = SKShapeNode(path: bootPath(width: 23, height: 10, direction: side))
            cleat.fillColor = color(1, 0.72, 0.10)
            cleat.strokeColor = color(0.16, 0.82, 0.90)
            cleat.lineWidth = 2
            cleat.position = CGPoint(x: side * 2, y: -29)
            variant.addChild(cleat)
            variant.addChild(rect(size: .init(width: 20, height: 3), color: color(0.10, 0.84, 0.92), radius: 1.5, x: side * 2, y: -34))
            variant.addChild(circle(radius: 1.5, color: color(0.025, 0.12, 0.30), x: side * 7, y: -36))
            variant.addChild(circle(radius: 1.5, color: color(0.025, 0.12, 0.30), x: side * -3, y: -36))
        case .marsBoots:
            let boot = SKShapeNode(path: bootPath(width: 24, height: 12, direction: side))
            boot.fillColor = color(0.12, 0.82, 0.94)
            boot.strokeColor = color(0.88, 0.26, 1)
            boot.lineWidth = 2
            boot.glowWidth = 1
            boot.position = CGPoint(x: side * 2, y: -29)
            variant.addChild(boot)
            variant.addChild(rect(size: .init(width: 7, height: 9), color: color(0.48, 0.14, 0.72), radius: 3, x: side * 7, y: -25, rotation: side * 0.18))
            variant.addChild(rect(size: .init(width: 20, height: 3), color: color(0.92, 0.30, 1), radius: 1.5, x: side * 2, y: -35))
        default:
            variant.name = "foot-variant-base"
            variant.addChild(rect(size: .init(width: 18, height: 8), color: color(0.98, 0.68, 0.10), radius: 4, x: side * 2, y: -29))
        }
        return variant
    }

    private static func playerNumber(color: SKColor, y: CGFloat) -> SKLabelNode {
        let number = SKLabelNode(text: "9")
        number.fontName = "AvenirNext-Bold"
        number.fontSize = 13
        number.fontColor = color
        number.verticalAlignmentMode = .center
        number.position = CGPoint(x: 0, y: y)
        return number
    }

    private static func variantName(_ id: GearID?) -> String {
        id.map { "variant-\($0.rawValue)" } ?? "variant-base"
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

    private static func setLimbPose(on rig: SKNode, stride: CGFloat, armSwing: CGFloat) {
        rig.childNode(withName: "left-leg")?.zRotation = -0.09 + stride
        rig.childNode(withName: "right-leg")?.zRotation = 0.09 - stride
        rig.childNode(withName: "left-arm")?.zRotation = -0.18 + armSwing
        rig.childNode(withName: "right-arm")?.zRotation = 0.18 - armSwing
    }

    private static func decorateObject(_ root: SKNode, object: FieldObjectKind) {
        root.addChild(ellipse(size: .init(width: 50, height: 13), color: .black.withAlphaComponent(0.2), y: -25))
        switch object {
        case .ballCart:
            root.addChild(rect(size: .init(width: 54, height: 35), color: color(0.12, 0.34, 0.65), radius: 7))
            root.addChild(circle(radius: 9, color: .white, x: -14, y: 3))
            root.addChild(circle(radius: 9, color: .white, x: 14, y: 3))
        case .waterCooler:
            root.addChild(rect(size: .init(width: 30, height: 44), color: color(0.10, 0.80, 0.88), radius: 8))
            root.addChild(rect(size: .init(width: 34, height: 8), color: .white, radius: 3, y: 17))
        case .tacticsBoard:
            root.addChild(rect(size: .init(width: 58, height: 42), color: color(0.12, 0.55, 0.24), radius: 5))
            let line = SKShapeNode(rectOf: .init(width: 44, height: 28), cornerRadius: 2)
            line.strokeColor = .white
            line.lineWidth = 2
            root.addChild(line)
        case .coneBarricade:
            for x in [-18.0, 0, 18] {
                let cone = SKShapeNode(path: triangle(width: 20, height: 33))
                cone.fillColor = color(1, 0.36, 0.05)
                cone.strokeColor = .white
                cone.lineWidth = 2
                cone.position.x = x
                root.addChild(cone)
            }
        case .equipmentTrunk:
            root.addChild(rect(size: .init(width: 62, height: 42), color: color(0.12, 0.18, 0.28), radius: 8))
            root.addChild(rect(size: .init(width: 18, height: 9), color: color(1, 0.72, 0.1), radius: 2, y: 2))
        case .oxygenPod:
            root.addChild(rect(size: .init(width: 30, height: 46), color: color(0.18, 0.88, 0.96), radius: 12))
            root.addChild(circle(radius: 8, color: .white.withAlphaComponent(0.86), y: 9))
            root.addChild(rect(size: .init(width: 18, height: 6), color: color(0.54, 0.18, 0.76), radius: 3, y: -11))
        case .meteorCrate:
            root.addChild(rect(size: .init(width: 56, height: 38), color: color(0.54, 0.20, 0.12), radius: 10))
            root.addChild(circle(radius: 11, color: color(0.92, 0.42, 0.16), y: 2))
        case .holoGate:
            let gate = SKShapeNode(rectOf: .init(width: 58, height: 44), cornerRadius: 8)
            gate.fillColor = color(0.18, 0.86, 1).withAlphaComponent(0.20)
            gate.strokeColor = color(0.26, 0.94, 1)
            gate.lineWidth = 3
            root.addChild(gate)
            root.addChild(circle(radius: 6, color: color(0.84, 0.26, 1), y: 1))
        case .crystalBarricade:
            for x in [-18.0, 0, 18] {
                let crystal = SKShapeNode(path: triangle(width: 19, height: 38))
                crystal.fillColor = color(0.62, 0.22, 0.88)
                crystal.strokeColor = color(0.22, 0.94, 1)
                crystal.lineWidth = 2
                crystal.position.x = x
                crystal.glowWidth = 3
                root.addChild(crystal)
            }
        case .artifactVault:
            root.addChild(rect(size: .init(width: 64, height: 44), color: color(0.22, 0.12, 0.34), radius: 12))
            let lock = circle(radius: 10, color: color(0.92, 0.32, 1), y: 1)
            lock.glowWidth = 5
            root.addChild(lock)
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

    private static func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> SKColor {
        SKColor(red: red, green: green, blue: blue, alpha: 1)
    }
}
