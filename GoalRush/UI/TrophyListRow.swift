import SwiftUI

struct TrophyListRow: View {
    let id: AchievementID
    let playerProgress: PlayerProgress

    var body: some View {
        let unlocked = playerProgress.unlockedAchievements.contains(id)
        let milestoneProgress = AchievementCatalog.progress(
            for: id,
            playerProgress: playerProgress
        )

        HStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            Image(systemName: AchievementCatalog.icon(for: id))
                .font(GoalRushTheme.Typography.title3)
                .foregroundStyle(
                    unlocked ? GoalRushTheme.navy : .white.opacity(0.48)
                )
                .frame(
                    width: GoalRushTheme.Metrics.minimumTapTarget,
                    height: GoalRushTheme.Metrics.minimumTapTarget
                )
                .background(
                    unlocked
                        ? GoalRushTheme.gold
                        : .white.opacity(0.08),
                    in: Circle()
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(AchievementCatalog.title(for: id))
                    .font(GoalRushTheme.Typography.headline)
                    .foregroundStyle(
                        unlocked ? .white : .white.opacity(0.62)
                    )

                Text(AchievementCatalog.subtitle(for: id))
                    .font(GoalRushTheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)

                if !unlocked, let milestoneProgress {
                    HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                        ProgressView(value: milestoneProgress.fraction)
                            .tint(GoalRushTheme.gold)
                        Text(milestoneProgress.label)
                            .font(GoalRushTheme.Typography.captionEmphasized)
                            .foregroundStyle(GoalRushTheme.gold)
                            .monospacedDigit()
                    }
                    .padding(.top, GoalRushTheme.Metrics.compactSpacing)
                }
            }

            Spacer(minLength: GoalRushTheme.Metrics.compactSpacing)

            Image(systemName: unlocked ? "checkmark.seal.fill" : "lock.fill")
                .foregroundStyle(
                    unlocked ? GoalRushTheme.gold : .white.opacity(0.42)
                )
                .accessibilityHidden(true)
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .gameSurface(.panel)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            accessibilityLabel(
                unlocked: unlocked,
                progress: milestoneProgress
            )
        )
        .accessibilityIdentifier("trophy-\(id.rawValue)")
    }

    private func accessibilityLabel(
        unlocked: Bool,
        progress: AchievementProgress?
    ) -> String {
        var label = "\(AchievementCatalog.title(for: id)), "
            + "\(unlocked ? "unlocked" : "locked"). "
            + AchievementCatalog.subtitle(for: id)
        if !unlocked, let progress {
            label += ". Progress \(progress.accessibilityLabel)"
        }
        return label
    }
}
