import SpriteKit

/// Caches the nodes touched on every render frame. SpriteKit's name-based tree
/// search is convenient during construction, but repeating it for every enemy,
/// limb, and health update adds avoidable traversal work to the hot loop.
final class TargetRenderNode: SKNode {
    enum StatusVisual: Equatable {
        case none
        case frozen
        case burning
        case stunned
        case reversed
    }

    private struct ShapePalette {
        let node: SKShapeNode
        let fill: SKColor
        let stroke: SKColor
    }

    private struct SpritePalette {
        let node: SKSpriteNode
        let color: SKColor
        let blendFactor: CGFloat
    }

    private(set) weak var motionRig: SKNode?
    private(set) weak var hitReactionRig: SKNode?
    private(set) weak var bodySprite: SKSpriteNode?
    private(set) weak var healthFill: SKNode?
    private(set) weak var regularHealthBackground: SKNode?
    private(set) weak var regularHealthFill: SKNode?
    private(set) weak var bossHealthPlate: SKNode?
    private(set) weak var bossHealthFill: SKNode?
    private(set) weak var bossHealthIcon: SKSpriteNode?
    private(set) var showsBossHealth = false
    private(set) weak var leftLeg: SKNode?
    private(set) weak var rightLeg: SKNode?
    private(set) weak var leftArm: SKNode?
    private(set) weak var rightArm: SKNode?
    private(set) weak var statusUnderlay: SKNode?
    private(set) weak var statusOverlay: SKNode?
    private(set) weak var frostGlaze: SKNode?
    private(set) weak var iceCrystals: SKNode?
    private(set) weak var fireBack: SKNode?
    private(set) weak var fireFront: SKNode?
    private(set) weak var stunArcs: SKNode?
    private(set) weak var reverseTrail: SKNode?
    private(set) var motionLights: [SKNode] = []
    private var tintShapes: [ShapePalette] = []
    private var tintSprites: [SpritePalette] = []
    private var currentStatus: StatusVisual = .none
    private var lastStatusRemaining: Double = 0
    private var cachedReducedMotion = false

    func cacheRenderNodes() {
        motionRig = childNode(withName: "motion-body")
        hitReactionRig = childNode(withName: "//hit-reaction")
        bodySprite = childNode(withName: "//body-sprite") as? SKSpriteNode
        regularHealthBackground = childNode(withName: "health-background")
        regularHealthFill = regularHealthBackground?.childNode(withName: "health-fill")
        bossHealthPlate = childNode(withName: "boss-health")
        bossHealthFill = bossHealthPlate?.childNode(withName: "boss-health-track/boss-health-fill")
        bossHealthIcon = bossHealthPlate?.childNode(withName: "boss-health-icon") as? SKSpriteNode
        healthFill = regularHealthFill
        leftLeg = hitReactionRig?.childNode(withName: "left-leg")
        rightLeg = hitReactionRig?.childNode(withName: "right-leg")
        leftArm = hitReactionRig?.childNode(withName: "left-arm")
        rightArm = hitReactionRig?.childNode(withName: "right-arm")
        statusUnderlay = childNode(withName: "//status-underlay")
        statusOverlay = childNode(withName: "//status-overlay")
        frostGlaze = childNode(withName: "//status-frost-glaze")
        iceCrystals = childNode(withName: "//status-ice-crystals")
        fireBack = childNode(withName: "//status-fire-back")
        fireFront = childNode(withName: "//status-fire-front")
        stunArcs = childNode(withName: "//status-stun-arcs")
        reverseTrail = childNode(withName: "//status-reverse-trail")
        motionLights = hitReactionRig?.children.filter { $0.name == "motion-light" } ?? []
        cacheTintableNodes()
        resetStatusEffects()
        resetHitReaction()
    }

    func configureHealthPresentation(isBoss: Bool, bossIconTexture: SKTexture?) {
        showsBossHealth = isBoss
        regularHealthBackground?.isHidden = isBoss
        bossHealthPlate?.isHidden = !isBoss
        bossHealthIcon?.texture = bossIconTexture
        healthFill = isBoss ? bossHealthFill : regularHealthFill
    }

    func applyStatus(from target: TargetState, reducedMotion: Bool) {
        let next: StatusVisual
        let remaining: Double
        if target.freezeRemaining > 0 {
            next = .frozen
            remaining = target.freezeRemaining
        } else if target.stunRemaining > 0 {
            next = .stunned
            remaining = target.stunRemaining
        } else if target.burnRemaining > 0 {
            next = .burning
            remaining = target.burnRemaining
        } else if target.reverseRemaining > 0 {
            next = .reversed
            remaining = target.reverseRemaining
        } else {
            next = .none
            remaining = 0
        }

        let wasReapplied = next == currentStatus && remaining > lastStatusRemaining + 0.25
        guard next != currentStatus || wasReapplied || reducedMotion != cachedReducedMotion else {
            lastStatusRemaining = remaining
            return
        }

        if next != currentStatus {
            transitionOut(currentStatus, reducedMotion: reducedMotion)
            restoreModelPalette()
            currentStatus = next
        }
        cachedReducedMotion = reducedMotion
        lastStatusRemaining = remaining
        transitionIn(next, reducedMotion: reducedMotion, reapplication: wasReapplied)
    }

    func resetStatusEffects() {
        stopAnimations(in: statusUnderlay)
        stopAnimations(in: statusOverlay)
        statusUnderlay?.alpha = 0
        statusOverlay?.alpha = 0
        frostGlaze?.alpha = 0
        iceCrystals?.alpha = 0
        fireBack?.alpha = 0
        fireFront?.alpha = 0
        stunArcs?.alpha = 0
        reverseTrail?.alpha = 0
        restoreModelPalette()
        currentStatus = .none
        lastStatusRemaining = 0
    }

    func playHitReaction(_ impact: ImpactEvent, reducedMotion: Bool) {
        guard let hitReactionRig else { return }
        resetHitTransform()
        flashModel(strength: impact.delivery == .damageOverTime ? 0.34 : 0.82)

        if impact.delivery == .damageOverTime {
            let pulse = reducedMotion ? 1.012 : 1.035
            hitReactionRig.run(.sequence([
                .scale(to: pulse, duration: 0.035),
                .scale(to: 1, duration: 0.075)
            ]), withKey: "hit-reaction")
            return
        }

        if reducedMotion {
            hitReactionRig.run(.sequence([
                .scale(to: impact.isCritical ? 1.04 : 1.025, duration: 0.035),
                .scale(to: 1, duration: 0.085)
            ]), withKey: "hit-reaction")
            return
        }

        let bossMultiplier: CGFloat = showsBossHealth ? 0.42 : 1
        let distance: CGFloat = (impact.isCritical ? 15 : 9) * bossMultiplier
        let squashX: CGFloat = impact.isCritical ? 1.13 : 1.08
        let squashY: CGFloat = impact.isCritical ? 0.78 : 0.85
        let rotation = CGFloat(-impact.impulse.x) * (impact.isCritical ? 0.11 : 0.065) * bossMultiplier
        let recoil = CGPoint(
            x: CGFloat(impact.impulse.x) * distance,
            y: CGFloat(impact.impulse.y) * distance
        )
        let snapDuration = impact.isCritical ? 0.045 : 0.04
        let returnDuration = impact.isCritical ? 0.16 : 0.13
        let snap = SKAction.group([
            .move(to: recoil, duration: snapDuration),
            .scaleX(to: squashX, y: squashY, duration: snapDuration),
            .rotate(toAngle: rotation, duration: snapDuration, shortestUnitArc: true)
        ])
        snap.timingMode = .easeOut
        let settle = SKAction.group([
            .move(to: .zero, duration: returnDuration),
            .scaleX(to: 1, y: 1, duration: returnDuration),
            .rotate(toAngle: 0, duration: returnDuration, shortestUnitArc: true)
        ])
        settle.timingMode = .easeOut
        hitReactionRig.run(.sequence([snap, settle]), withKey: "hit-reaction")
    }

    func resetHitReaction() {
        removeAction(forKey: "hit-flash")
        resetHitTransform()
        restoreActivePalette()
    }

    private func resetHitTransform() {
        hitReactionRig?.removeAction(forKey: "hit-reaction")
        hitReactionRig?.position = .zero
        hitReactionRig?.zRotation = 0
        hitReactionRig?.xScale = 1
        hitReactionRig?.yScale = 1
    }

    private func flashModel(strength: CGFloat) {
        removeAction(forKey: "hit-flash")
        restoreActivePalette()
        tintModel(toward: .white, amount: strength)
        run(.sequence([
            .wait(forDuration: 0.052),
            .run { [weak self] in self?.restoreActivePalette() }
        ]), withKey: "hit-flash")
    }

    private func transitionIn(_ status: StatusVisual, reducedMotion: Bool, reapplication: Bool) {
        switch status {
        case .none:
            statusUnderlay?.alpha = 0
            statusOverlay?.alpha = 0
        case .frozen:
            statusUnderlay?.alpha = 1
            statusOverlay?.alpha = 1
            frostGlaze?.alpha = 0.72
            iceCrystals?.alpha = 1
            applyStatusTintUnlessFlashing(.frozen)
            animateIce(reducedMotion: reducedMotion, pulse: reapplication)
        case .burning:
            statusUnderlay?.alpha = 1
            statusOverlay?.alpha = 1
            fireBack?.alpha = 0.82
            fireFront?.alpha = 1
            applyStatusTintUnlessFlashing(.burning)
            animateFire(reducedMotion: reducedMotion, pulse: reapplication)
        case .stunned:
            statusUnderlay?.alpha = 1
            statusOverlay?.alpha = 1
            stunArcs?.alpha = 1
            applyStatusTintUnlessFlashing(.stunned)
            animateStun(reducedMotion: reducedMotion, pulse: reapplication)
        case .reversed:
            statusUnderlay?.alpha = 1
            statusOverlay?.alpha = 1
            reverseTrail?.alpha = 0.88
            applyStatusTintUnlessFlashing(.reversed)
            animateReverse(reducedMotion: reducedMotion, pulse: reapplication)
        }
    }

    private func transitionOut(_ status: StatusVisual, reducedMotion: Bool) {
        stopAnimations(in: statusUnderlay)
        stopAnimations(in: statusOverlay)
        let duration = reducedMotion ? 0.06 : 0.18
        switch status {
        case .frozen:
            iceCrystals?.run(.group([
                .scale(to: 1.16, duration: duration),
                .fadeOut(withDuration: duration)
            ]))
            frostGlaze?.run(.fadeOut(withDuration: duration))
        case .burning:
            fireBack?.run(.group([.scaleY(to: 0.35, duration: duration), .fadeOut(withDuration: duration)]))
            fireFront?.run(.group([.scaleY(to: 0.35, duration: duration), .fadeOut(withDuration: duration)]))
        case .stunned:
            stunArcs?.run(.fadeOut(withDuration: duration))
        case .reversed:
            reverseTrail?.run(.fadeOut(withDuration: duration))
        case .none:
            break
        }
    }

    private func animateIce(reducedMotion: Bool, pulse: Bool) {
        guard let frostGlaze, let iceCrystals else { return }
        frostGlaze.removeAllActions()
        iceCrystals.removeAllActions()
        frostGlaze.setScale(1)
        iceCrystals.setScale(1)
        if pulse {
            iceCrystals.run(.sequence([
                .scale(to: reducedMotion ? 1.04 : 1.14, duration: 0.08),
                .scale(to: 1, duration: 0.13)
            ]))
        }
        guard !reducedMotion else { return }
        frostGlaze.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.88, duration: 0.55),
            .fadeAlpha(to: 0.62, duration: 0.75)
        ])), withKey: "frost-shimmer")
        for (index, crystal) in iceCrystals.children.enumerated() {
            crystal.run(.repeatForever(.sequence([
                .fadeAlpha(to: index.isMultiple(of: 2) ? 0.68 : 0.82, duration: 0.42 + Double(index) * 0.04),
                .fadeAlpha(to: 1, duration: 0.52)
            ])), withKey: "ice-glint")
        }
    }

    private func animateFire(reducedMotion: Bool, pulse: Bool) {
        guard let fireBack, let fireFront else { return }
        stopAnimations(in: fireBack)
        stopAnimations(in: fireFront)
        fireBack.setScale(1)
        fireFront.setScale(1)
        if pulse {
            fireFront.run(.sequence([
                .scale(to: reducedMotion ? 1.03 : 1.18, duration: 0.08),
                .scale(to: 1, duration: 0.13)
            ]), withKey: "ignition")
        }
        for (index, flame) in (fireBack.children + fireFront.children).enumerated() {
            let baseScale = flame.xScale
            flame.alpha = index.isMultiple(of: 3) ? 0.72 : 1
            guard !reducedMotion else { continue }
            let duration = 0.20 + Double(index % 4) * 0.045
            flame.run(.repeatForever(.sequence([
                .group([
                    .moveBy(x: index.isMultiple(of: 2) ? 1.6 : -1.6, y: 3.5, duration: duration),
                    .scaleX(to: baseScale * 0.84, y: 1.13, duration: duration),
                    .fadeAlpha(to: 0.68, duration: duration)
                ]),
                .group([
                    .moveBy(x: index.isMultiple(of: 2) ? -1.6 : 1.6, y: -3.5, duration: duration),
                    .scaleX(to: baseScale, y: 1, duration: duration),
                    .fadeAlpha(to: 1, duration: duration)
                ])
            ])), withKey: "flame-loop")
        }
    }

    private func animateReverse(reducedMotion: Bool, pulse: Bool) {
        guard let reverseTrail else { return }
        stopAnimations(in: reverseTrail)
        reverseTrail.setScale(1)
        if pulse {
            reverseTrail.run(.sequence([
                .scale(to: reducedMotion ? 1.03 : 1.16, duration: 0.08),
                .scale(to: 1, duration: 0.14)
            ]), withKey: "rewind-pulse")
        }
        guard !reducedMotion else { return }
        for (index, streak) in reverseTrail.children.enumerated() {
            let distance: CGFloat = index.isMultiple(of: 2) ? -9 : 9
            streak.run(.repeatForever(.sequence([
                .group([
                    .moveBy(x: distance, y: 0, duration: 0.28),
                    .fadeOut(withDuration: 0.28)
                ]),
                .moveBy(x: -distance, y: 0, duration: 0),
                .fadeIn(withDuration: 0)
            ])), withKey: "reverse-loop")
        }
    }

    private func animateStun(reducedMotion: Bool, pulse: Bool) {
        guard let stunArcs else { return }
        stopAnimations(in: stunArcs)
        stunArcs.setScale(1)
        if pulse {
            stunArcs.run(.sequence([
                .scale(to: reducedMotion ? 1.04 : 1.18, duration: 0.07),
                .scale(to: 1, duration: 0.11)
            ]), withKey: "stun-pulse")
        }
        guard !reducedMotion else { return }
        for (index, arc) in stunArcs.children.enumerated() {
            arc.run(.repeatForever(.sequence([
                .fadeAlpha(to: index.isMultiple(of: 2) ? 0.30 : 0.55, duration: 0.06),
                .fadeAlpha(to: 1, duration: 0.07),
                .wait(forDuration: 0.04 + Double(index) * 0.015)
            ])), withKey: "stun-flicker")
        }
    }

    private func cacheTintableNodes() {
        tintShapes.removeAll(keepingCapacity: true)
        tintSprites.removeAll(keepingCapacity: true)
        collectTintableNodes(in: motionRig ?? self, insideStatusRig: false)
    }

    private func collectTintableNodes(in node: SKNode, insideStatusRig: Bool) {
        let isEffectNode = insideStatusRig
            || node.name?.hasPrefix("status-") == true
            || node.name?.hasPrefix("health-") == true
        if !isEffectNode {
            if let sprite = node as? SKSpriteNode {
                tintSprites.append(.init(node: sprite, color: sprite.color, blendFactor: sprite.colorBlendFactor))
            } else if let shape = node as? SKShapeNode {
                tintShapes.append(.init(node: shape, fill: shape.fillColor, stroke: shape.strokeColor))
            }
        }
        for child in node.children {
            collectTintableNodes(in: child, insideStatusRig: isEffectNode)
        }
    }

    private func tintModel(toward tint: SKColor, amount: CGFloat) {
        for palette in tintSprites {
            palette.node.color = tint
            palette.node.colorBlendFactor = max(palette.blendFactor, amount)
        }
        for palette in tintShapes {
            if palette.fill != .clear {
                palette.node.fillColor = palette.fill.mixed(with: tint, amount: amount)
            }
            if palette.stroke != .clear {
                palette.node.strokeColor = palette.stroke.mixed(with: tint, amount: amount * 0.75)
            }
        }
    }

    private func restoreModelPalette() {
        for palette in tintSprites {
            palette.node.color = palette.color
            palette.node.colorBlendFactor = palette.blendFactor
        }
        for palette in tintShapes {
            palette.node.fillColor = palette.fill
            palette.node.strokeColor = palette.stroke
        }
    }

    private func restoreActivePalette() {
        restoreModelPalette()
        applyStatusTint(currentStatus)
    }

    private func applyStatusTintUnlessFlashing(_ status: StatusVisual) {
        guard action(forKey: "hit-flash") == nil else { return }
        applyStatusTint(status)
    }

    private func applyStatusTint(_ status: StatusVisual) {
        switch status {
        case .none:
            break
        case .frozen:
            tintModel(toward: SKColor(red: 0.16, green: 0.66, blue: 1, alpha: 1), amount: 0.46)
        case .burning:
            tintModel(toward: SKColor(red: 1, green: 0.31, blue: 0.03, alpha: 1), amount: 0.24)
        case .stunned:
            tintModel(toward: SKColor(red: 0.24, green: 0.88, blue: 1, alpha: 1), amount: 0.22)
        case .reversed:
            tintModel(toward: SKColor(red: 0.68, green: 0.20, blue: 1, alpha: 1), amount: 0.18)
        }
    }

    private func stopAnimations(in node: SKNode?) {
        guard let node else { return }
        node.removeAllActions()
        for child in node.children {
            stopAnimations(in: child)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        cacheRenderNodes()
    }

    override init() {
        super.init()
    }
}

private extension SKColor {
    func mixed(with other: SKColor, amount: CGFloat) -> SKColor {
        let amount = min(max(amount, 0), 1)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        var otherRed: CGFloat = 0
        var otherGreen: CGFloat = 0
        var otherBlue: CGFloat = 0
        var otherAlpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha),
              other.getRed(&otherRed, green: &otherGreen, blue: &otherBlue, alpha: &otherAlpha) else {
            return other
        }
        return SKColor(
            red: red + (otherRed - red) * amount,
            green: green + (otherGreen - green) * amount,
            blue: blue + (otherBlue - blue) * amount,
            alpha: alpha + (otherAlpha - alpha) * amount
        )
    }
}
