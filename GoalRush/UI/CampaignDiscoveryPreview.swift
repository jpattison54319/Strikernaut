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
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.26), GoalRushTheme.navy.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

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
        .clipShape(.rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(accent.opacity(0.55), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}
