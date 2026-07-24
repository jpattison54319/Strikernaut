import SwiftUI

struct HomeTopHUD: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: GoalRushTheme.Metrics.compactSpacing))
            : AnyLayout(HStackLayout(spacing: GoalRushTheme.Metrics.standardSpacing))

        layout {
            Label("\(store.progress.trainingTokens)", systemImage: "hexagon.fill")
                .font(GoalRushTheme.Typography.metric(size: 18))
                .foregroundStyle(GoalRushTheme.gold)
                .padding(.horizontal, GoalRushTheme.Metrics.standardSpacing)
                .frame(minHeight: GoalRushTheme.Metrics.minimumTapTarget)
                .gameSurface(.hud)
                .fixedSize(horizontal: true, vertical: false)
                .frame(
                    maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
                    alignment: .leading
                )
                .accessibilityLabel("\(store.progress.trainingTokens) Training Tokens")

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: GoalRushTheme.Metrics.compactSpacing)
            }

            Button(action: openSettings) {
                Label("Settings", systemImage: "gearshape.fill")
                    .font(GoalRushTheme.Typography.subheadlineEmphasized)
                    .padding(.horizontal, GoalRushTheme.Metrics.standardSpacing)
                    .frame(minHeight: GoalRushTheme.Metrics.minimumTapTarget)
                    .gameSurface(.hud)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .frame(
                maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
                alignment: .leading
            )
            .accessibilityIdentifier("settings")
        }
    }

    private func openSettings() {
        store.uiAudio.play(.tap)
        store.route = .settings
    }
}
