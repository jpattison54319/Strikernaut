import SpriteKit

@MainActor
final class CampaignDiscoveryPreviewScene: SKScene {
    private let targetNode: SKNode

    init(kind: TargetState.Kind) {
        targetNode = GameNodeFactory.target(
            TargetState(
                id: 0,
                kind: kind,
                position: .init(x: 0, y: 0),
                hitPoints: 1,
                maximumHitPoints: 1,
                phase: 0
            )
        )
        targetNode.childNode(withName: "health-background")?.removeFromParent()
        super.init(size: CGSize(width: 116, height: 104))
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func didMove(to view: SKView) {
        view.allowsTransparency = true
        if targetNode.parent == nil {
            addChild(targetNode)
        }
        layoutTarget()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutTarget()
    }

    private func layoutTarget() {
        targetNode.position = .zero
        targetNode.setScale(1)
        let naturalFrame = targetNode.calculateAccumulatedFrame()
        guard naturalFrame.width > 0, naturalFrame.height > 0 else { return }

        let scale = min(
            size.width * 0.68 / naturalFrame.width,
            size.height * 0.68 / naturalFrame.height
        )
        targetNode.setScale(scale)
        let fittedFrame = targetNode.calculateAccumulatedFrame()
        targetNode.position = CGPoint(
            x: size.width / 2 - fittedFrame.midX,
            y: size.height / 2 - fittedFrame.midY
        )
    }
}
