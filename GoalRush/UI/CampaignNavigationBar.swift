import SwiftUI

struct CampaignNavigationBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let subtitle: String
    let backTitle: String?
    let onBack: (() -> Void)?
    let onHome: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                navigationControls
                Spacer(minLength: GoalRushTheme.Metrics.compactSpacing)
                titleBlock
                Spacer(minLength: GoalRushTheme.Metrics.compactSpacing)
                homeButton
            }
            VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                titleBlock
                HStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                    navigationControls
                    Spacer()
                    homeButton
                }
            }
        }
        .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
        .padding(.vertical, GoalRushTheme.Metrics.compactSpacing)
        .background(GoalRushTheme.ink.opacity(0.94))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(GoalRushTheme.paper.opacity(0.62))
                .frame(height: GoalRushTheme.Metrics.inkStrokeWidth)
        }
        .overlay { ComicInkTexture(opacity: 0.07).allowsHitTesting(false) }
    }

    @ViewBuilder
    private var navigationControls: some View {
        if let backTitle, let onBack {
            Button(backTitle, systemImage: "chevron.left", action: onBack)
                .font(GoalRushTheme.Typography.subheadlineEmphasized)
                .frame(minHeight: GoalRushTheme.Metrics.minimumTapTarget)
                .accessibilityIdentifier("campaign-back")
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(GoalRushTheme.Typography.headline)
                .foregroundStyle(.white)
            Text(subtitle)
                .font(GoalRushTheme.Typography.captionEmphasized)
                .foregroundStyle(GoalRushTheme.gold)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var homeButton: some View {
        Button("Home", systemImage: "house.fill", action: onHome)
            .font(GoalRushTheme.Typography.subheadlineEmphasized)
            .frame(
                minWidth: dynamicTypeSize.isAccessibilitySize ? nil : 72,
                minHeight: GoalRushTheme.Metrics.minimumTapTarget
            )
            .accessibilityIdentifier("campaign-home")
    }
}
