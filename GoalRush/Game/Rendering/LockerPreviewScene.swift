import SpriteKit

@MainActor
final class LockerPreviewScene: SKScene {
    private var playerNode = SKNode()

    init(loadout: GearLoadout) {
        super.init(size: CGSize(width: 340, height: 470))
        scaleMode = .resizeFill
        backgroundColor = .clear
        update(loadout: loadout, animated: false)
    }

    required init?(coder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        view.allowsTransparency = true
        layoutPlayer()
        startIdleAnimation()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutPlayer()
    }

    func update(loadout: GearLoadout, animated: Bool = true) {
        playerNode.removeFromParent()
        playerNode = GameNodeFactory.player(loadout: loadout)
        addChild(playerNode)
        layoutPlayer()
        startIdleAnimation()
        if animated {
            playerNode.setScale(playerNode.xScale * 0.88)
            playerNode.run(.scale(to: targetScale, duration: 0.24))
            GameNodeFactory.animateKick(on: playerNode, reducedMotion: UIAccessibility.isReduceMotionEnabled)
        }
    }

    private var targetScale: CGFloat {
        min(2.70, max(2.15, min(size.width / 135, size.height / 175)))
    }

    private func layoutPlayer() {
        playerNode.position = CGPoint(x: size.width / 2, y: size.height * 0.43)
        playerNode.setScale(targetScale)
        playerNode.zPosition = 10
    }

    private func startIdleAnimation() {
        guard let body = playerNode.childNode(withName: "body") else { return }
        body.removeAction(forKey: "locker-idle")
        body.position = .zero
        body.zRotation = 0
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let bob = SKAction.sequence([
            .group([.moveBy(x: 0, y: 1.4, duration: 0.70), .rotate(toAngle: 0.018, duration: 0.70)]),
            .group([.moveBy(x: 0, y: -1.4, duration: 0.70), .rotate(toAngle: -0.018, duration: 0.70)])
        ])
        bob.timingMode = .easeInEaseOut
        body.run(.repeatForever(bob), withKey: "locker-idle")
    }
}
