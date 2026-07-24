import SwiftUI

struct CampaignBriefingView: View {
    let level: LevelDefinition
    let discoveries: [CampaignDiscovery]
    let session: GameSessionModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.84)
                .ignoresSafeArea()

            RadialGradient(
                colors: [level.world.accentColor.opacity(0.24), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 430
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                VStack(spacing: 7) {
                    Label("NEW THIS LEVEL", systemImage: "sparkles")
                        .font(GoalRushTheme.Typography.captionEmphasized)
                        .tracking(1.2)
                        .foregroundStyle(level.world.accentColor)
                    Text(level.name)
                        .font(GoalRushTheme.Typography.display)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                    Text("LEVEL \(level.worldLevel)")
                        .font(GoalRushTheme.Typography.captionEmphasized)
                        .foregroundStyle(.white.opacity(0.58))
                }
                .accessibilityElement(children: .combine)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(discoveries) { discovery in
                            CampaignDiscoveryCard(
                                discovery: discovery,
                                accent: level.world.accentColor
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)

                Button("Kick Off", systemImage: "play.fill") {
                    session.startCampaignLevel()
                }
                .buttonStyle(PrimaryGameButton())
                .accessibilityIdentifier("briefing-start")
            }
            .frame(maxWidth: 430)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
