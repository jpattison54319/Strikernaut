import SwiftUI

struct NewGamePlusConfirmationView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let cycle: Int

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.sectionSpacing) {
                    header
                    retainedProgress
                    resetProgress
                    permanentChange
                }
                .padding(GoalRushTheme.Metrics.horizontalPadding)
                .padding(.bottom, GoalRushTheme.Metrics.sectionSpacing)
            }
            .background(GoalRushTheme.navy.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
            .navigationTitle("Start NG+\(cycle)?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
            }
        }
        .interactiveDismissDisabled()
        .presentationDetents([.large])
        .accessibilityIdentifier("new-game-plus-confirmation")
    }

    private var header: some View {
        VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: 58, weight: .black))
                .foregroundStyle(Color.purple)
                .accessibilityHidden(true)

            Text("RETURN TO EARTH")
                .font(GoalRushTheme.Typography.display)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("NG+\(cycle) starts beyond the difficulty of your current Neptune finale and climbs faster through every world.")
                .font(GoalRushTheme.Typography.body)
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .gameSurface(.modal)
    }

    private var retainedProgress: some View {
        informationPanel(
            title: "YOU KEEP",
            systemImage: "checkmark.shield.fill",
            tint: GoalRushTheme.cyan,
            lines: [
                "Training Tokens and every upgrade or prestige rank",
                "Characters, achievements, lifetime stats, and level bests",
                "Endless records, Scrap, and every relic",
            ]
        )
    }

    private var resetProgress: some View {
        informationPanel(
            title: "CAMPAIGN RESETS",
            systemImage: "arrow.counterclockwise",
            tint: GoalRushTheme.orange,
            lines: [
                "Earth Level 1 becomes the only unlocked campaign level",
                "Every world must be cleared again in this cycle",
                "Earlier campaign difficulties cannot be restored",
            ]
        )
    }

    private var permanentChange: some View {
        informationPanel(
            title: "THE NEW RULES",
            systemImage: "shield.lefthalf.filled",
            tint: Color.purple,
            lines: [
                "Enemies scale faster and shields appear throughout the campaign",
                "Endless relic drops gain NG+\(cycle) rarity and power bonuses",
                "Beating Neptune unlocks the next, harder NG+ cycle",
            ]
        )
    }

    private func informationPanel(
        title: String,
        systemImage: String,
        tint: Color,
        lines: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
            Label(title, systemImage: systemImage)
                .font(GoalRushTheme.Typography.headline)
                .foregroundStyle(tint)

            ForEach(lines, id: \.self) { line in
                Label(line, systemImage: "circle.fill")
                    .font(GoalRushTheme.Typography.subheadline)
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gameSurface(.panel)
    }

    private var actionBar: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: GoalRushTheme.Metrics.standardSpacing))
            : AnyLayout(HStackLayout(spacing: GoalRushTheme.Metrics.standardSpacing))

        return layout {
            Button("Cancel", action: dismiss.callAsFunction)
                .buttonStyle(SecondaryGameButton())

            Button("Start NG+\(cycle)", systemImage: "arrow.clockwise") {
                guard store.beginNextCampaignCycle() else { return }
                store.uiAudio.play(.fanfare, feedback: .success)
                dismiss()
            }
            .buttonStyle(PrimaryGameButton())
            .accessibilityIdentifier("new-game-plus-start")
            .accessibilityHint(
                "Returns campaign progress to Earth Level 1. Permanent progress is kept."
            )
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .background(.ultraThinMaterial)
    }
}
