import SwiftUI

struct EndlessRelicProgressHint: View {
    var body: some View {
        Label("Clear Wave 5 for a Relic", systemImage: "diamond")
            .font(GoalRushTheme.Typography.subheadlineEmphasized)
            .foregroundStyle(.white.opacity(0.78))
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(GoalRushTheme.surfaceRaised.opacity(0.94), in: ComicPanelShape(cut: 8))
            .overlay {
                ComicPanelShape(cut: 8)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            }
            .accessibilityIdentifier("result-relic-progress")
    }
}
