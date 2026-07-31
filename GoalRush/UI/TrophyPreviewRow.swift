import SwiftUI

struct TrophyPreviewRow: View {
    let id: AchievementID
    let playerProgress: PlayerProgress

    var body: some View {
        let milestoneProgress = AchievementCatalog.progress(
            for: id,
            playerProgress: playerProgress
        )

        HStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            Image(systemName: AchievementCatalog.icon(for: id))
                .font(GoalRushTheme.Typography.headline)
                .foregroundStyle(GoalRushTheme.gold)
                .frame(
                    width: GoalRushTheme.Metrics.minimumTapTarget,
                    height: GoalRushTheme.Metrics.minimumTapTarget
                )
                .background(
                    GoalRushTheme.gold.opacity(0.12),
                    in: Circle()
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(AchievementCatalog.title(for: id))
                    .font(GoalRushTheme.Typography.headline)
                    .foregroundStyle(.white)

                Text(AchievementCatalog.subtitle(for: id))
                    .font(GoalRushTheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)

                if let milestoneProgress {
                    HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                        ProgressView(value: milestoneProgress.fraction)
                            .tint(GoalRushTheme.gold)
                        Text(milestoneProgress.label)
                            .font(GoalRushTheme.Typography.captionEmphasized)
                            .foregroundStyle(GoalRushTheme.gold)
                            .monospacedDigit()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(GoalRushTheme.Metrics.compactSpacing)
        .background(
            GoalRushTheme.surfaceRaised.opacity(0.72),
            in: ComicPanelShape(cut: GoalRushTheme.Metrics.smallRadius)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(progress: milestoneProgress))
        .accessibilityIdentifier("progress-trophy-preview-\(id.rawValue)")
    }

    private func accessibilityLabel(
        progress: AchievementProgress?
    ) -> String {
        var label = "\(AchievementCatalog.title(for: id)). "
            + AchievementCatalog.subtitle(for: id)
        if let progress {
            label += ". Progress \(progress.accessibilityLabel)"
        }
        return label
    }
}
