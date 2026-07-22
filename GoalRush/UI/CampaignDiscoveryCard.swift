import SwiftUI

struct CampaignDiscoveryCard: View {
    let discovery: CampaignDiscovery
    let accent: Color

    var body: some View {
        HStack(spacing: 14) {
            CampaignDiscoveryPreview(discovery: discovery, accent: accent)

            VStack(alignment: .leading, spacing: 7) {
                Text(discovery.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(discovery.detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(GoalRushTheme.surfaceRaised.opacity(0.92), in: .rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.13))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("discovery-\(discovery.id)")
    }
}
