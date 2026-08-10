import SwiftUI

struct ProgressTrophyWidget: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let playerProgress: PlayerProgress
    let showAll: () -> Void

    var body: some View {
        let closest = AchievementCatalog.closestIncomplete(
            in: playerProgress
        )

        VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
            header

            if closest.isEmpty {
                Label(
                    "Every trophy complete",
                    systemImage: "checkmark.seal.fill"
                )
                .font(GoalRushTheme.Typography.headline)
                .foregroundStyle(GoalRushTheme.positive)
                .frame(
                    maxWidth: .infinity,
                    minHeight: GoalRushTheme.Metrics.minimumTapTarget,
                    alignment: .leading
                )
            } else {
                ForEach(closest, id: \.self) { id in
                    TrophyPreviewRow(
                        id: id,
                        playerProgress: playerProgress
                    )
                }
            }
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .gameSurface(.panel)
        .accessibilityElement(children: .contain)
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityLabel("Trophy progress widget")
                .accessibilityIdentifier("progress-trophy-widget")
        }
    }

    @ViewBuilder
    private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            HStack(
                alignment: .top,
                spacing: GoalRushTheme.Metrics.compactSpacing
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    trophyTitle

                    Text(
                        "\(playerProgress.unlockedAchievements.count) of "
                            + "\(AchievementID.allCases.count) unlocked"
                    )
                    .font(GoalRushTheme.Typography.captionEmphasized)
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                    .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                showAllButton
            }
        } else {
            HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                trophyTitle

                Spacer(minLength: GoalRushTheme.Metrics.compactSpacing)

                Text(
                    "\(playerProgress.unlockedAchievements.count)/"
                        + "\(AchievementID.allCases.count)"
                )
                .font(GoalRushTheme.Typography.captionEmphasized)
                .foregroundStyle(.white.opacity(0.68))
                .monospacedDigit()

                showAllButton
            }
        }
    }

    private var trophyTitle: some View {
        Label("Trophies", systemImage: "trophy.fill")
            .font(GoalRushTheme.Typography.title2)
            .foregroundStyle(GoalRushTheme.gold)
            .lineLimit(1)
            .minimumScaleFactor(0.60)
            .layoutPriority(1)
    }

    private var showAllButton: some View {
        Button(
            "View all trophies",
            systemImage: "chevron.right",
            action: showAll
        )
        .labelStyle(.iconOnly)
        .font(GoalRushTheme.Typography.headline)
        .foregroundStyle(.white)
        .frame(
            width: GoalRushTheme.Metrics.minimumTapTarget,
            height: GoalRushTheme.Metrics.minimumTapTarget
        )
        .background(
            GoalRushTheme.blue,
            in: ComicPanelShape(cut: GoalRushTheme.Metrics.smallRadius)
        )
        .overlay {
            ComicPanelShape(cut: GoalRushTheme.Metrics.smallRadius)
                .stroke(GoalRushTheme.ink, lineWidth: 2)
        }
        .accessibilityIdentifier("progress-trophies-all")
    }
}
