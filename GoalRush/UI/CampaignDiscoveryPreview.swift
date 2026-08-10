import SpriteKit
import SwiftUI

struct CampaignDiscoveryPreview: View {
    let discovery: CampaignDiscovery
    let accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let scene: CampaignDiscoveryPreviewScene?

    init(discovery: CampaignDiscovery, accent: Color) {
        self.discovery = discovery
        self.accent = accent
        scene = discovery.targetKind.map(CampaignDiscoveryPreviewScene.init)
    }

    var body: some View {
        ZStack {
            ComicPanelShape(cut: 9)
                .fill(accent.opacity(0.24))
            ComicInkTexture(opacity: 0.10)

            if let scene {
                SpriteView(
                    scene: scene,
                    preferredFramesPerSecond: 30,
                    options: [.allowsTransparency]
                )
            } else {
                Image(systemName: discovery.systemImage)
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white, accent)
                    .symbolEffect(.bounce, options: .nonRepeating, isActive: !reduceMotion)
            }
        }
        .frame(width: 106, height: 96)
        .clipShape(ComicPanelShape(cut: 9))
        .overlay {
            ComicPanelShape(cut: 9)
                .stroke(accent.opacity(0.72), lineWidth: 2)
        }
        .accessibilityHidden(true)
    }
}
