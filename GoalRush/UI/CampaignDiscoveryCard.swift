import SwiftUI

struct CampaignDiscoveryCard: View {
    let discovery: CampaignDiscovery
    let accent: Color

    var body: some View {
        HStack(spacing: 14) {
            CampaignDiscoveryPreview(discovery: discovery, accent: accent)

            VStack(alignment: .leading, spacing: 7) {
                Text(discovery.title)
                    .font(GoalRushTheme.Typography.headline)
                    .foregroundStyle(.white)
                Text(discovery.detail)
                    .font(GoalRushTheme.Typography.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .gameSurface(.panel)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("discovery-\(discovery.id)")
    }
}
