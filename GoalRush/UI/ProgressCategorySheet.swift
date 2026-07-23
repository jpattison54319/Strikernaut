import SwiftUI

enum ProgressCategory: String, CaseIterable, Identifiable {
    case trophies
    case lifetime
    case streak
    case collections

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trophies: "Trophies"
        case .lifetime: "Lifetime"
        case .streak: "Streak"
        case .collections: "Collections"
        }
    }

    var subtitle: String {
        switch self {
        case .trophies: "Achievements"
        case .lifetime: "Journey totals"
        case .streak: "Daily rewards"
        case .collections: "World gear"
        }
    }

    var icon: String {
        switch self {
        case .trophies: "trophy.fill"
        case .lifetime: "chart.bar.fill"
        case .streak: "flame.fill"
        case .collections: "tshirt.fill"
        }
    }

    var accent: Color {
        switch self {
        case .trophies: GoalRushTheme.gold
        case .lifetime: GoalRushTheme.cyan
        case .streak: GoalRushTheme.orange
        case .collections: GoalRushTheme.positive
        }
    }
}

struct ProgressCategorySheet: View {
    @Environment(GameStore.self) private var store
    let category: ProgressCategory

    var body: some View {
        GameSheetScaffold(title: category.title, subtitle: category.subtitle) {
            switch category {
            case .trophies:
                trophies
            case .lifetime:
                lifetime
            case .streak:
                streak
            case .collections:
                collections
            }
        }
    }

    private var trophies: some View {
        LazyVStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            ForEach(AchievementCatalog.ordered, id: \.self) { id in
                trophyRow(id)
            }
        }
    }

    private func trophyRow(_ id: AchievementID) -> some View {
        let unlocked = store.progress.unlockedAchievements.contains(id)

        return HStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            Image(systemName: AchievementCatalog.icon(for: id))
                .font(.title3.bold())
                .foregroundStyle(unlocked ? GoalRushTheme.navy : .white.opacity(0.48))
                .frame(width: 44, height: 44)
                .background(unlocked ? GoalRushTheme.gold : .white.opacity(0.08), in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(AchievementCatalog.title(for: id))
                    .font(.headline)
                    .foregroundStyle(unlocked ? .white : .white.opacity(0.62))
                Text(AchievementCatalog.subtitle(for: id))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            Image(systemName: unlocked ? "checkmark.seal.fill" : "lock.fill")
                .foregroundStyle(unlocked ? GoalRushTheme.gold : .white.opacity(0.42))
                .accessibilityHidden(true)
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .gameSurface(.panel)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(AchievementCatalog.title(for: id)), \(unlocked ? "unlocked" : "locked"). \(AchievementCatalog.subtitle(for: id))")
        .accessibilityIdentifier("trophy-\(id.rawValue)")
    }

    private var lifetime: some View {
        let stats = store.progress.lifetimeStats

        return VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            metric("Runs played", value: stats.totalRuns.formatted(), icon: "play.fill")
            metric("Endless waves cleared", value: stats.totalWavesCleared.formatted(), icon: "infinity")
            metric("Best combo", value: "×\(stats.bestCombo)", icon: "bolt.fill")
            metric("Lifetime tokens", value: stats.totalTokensEarned.formatted(), icon: "hexagon.fill")
        }
    }

    private func metric(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            Image(systemName: icon)
                .foregroundStyle(GoalRushTheme.cyan)
                .frame(width: 44, height: 44)
                .background(GoalRushTheme.cyan.opacity(0.12), in: .circle)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Spacer(minLength: 8)
            Text(value)
                .font(.headline.bold().monospacedDigit())
                .foregroundStyle(GoalRushTheme.gold)
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .gameSurface(.panel)
        .accessibilityElement(children: .combine)
    }

    private var streak: some View {
        VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
            HStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                Image(systemName: "flame.fill")
                    .font(.title.bold())
                    .foregroundStyle(GoalRushTheme.orange)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("CURRENT STREAK")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.68))
                    Text("\(store.dailyStreak) day\(store.dailyStreak == 1 ? "" : "s")")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(.white)
                }
            }

            Divider().overlay(.white.opacity(0.18))

            Label(claimStatus, systemImage: store.isDailyRewardClaimable ? "gift.fill" : "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(store.isDailyRewardClaimable ? GoalRushTheme.gold : GoalRushTheme.positive)

            Text(streakGuidance)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .gameSurface(.panel)
        .accessibilityElement(children: .combine)
    }

    private var claimStatus: String {
        if store.isDailyRewardClaimable {
            return "Day \(store.nextStreakDay) claim: \(store.nextDailyReward) Tokens"
        }
        let nextDay = min(store.dailyStreak + 1, DailyRewardEngine.rewards.count)
        return "Today secured • Next claim: \(DailyRewardEngine.reward(forStreakDay: nextDay)) Tokens"
    }

    private var streakGuidance: String {
        if !store.isDailyRewardClaimable {
            return "Come back tomorrow to continue your streak."
        }
        if store.dailyStreak > 0 && store.nextStreakDay == 1 {
            return "Your previous streak ended. Claim today's daily reward to begin a new one."
        }
        if store.dailyStreak == 0 {
            return "Claim today's daily reward from Home to start your streak."
        }
        return "Claim today's daily reward from Home to extend your streak."
    }

    private var collections: some View {
        VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            ForEach(GameContent.worlds) { world in
                let earned = world.gearRewards.filter { store.progress.unlockedGear.contains($0) }.count
                let equipped = world.gearRewards.filter { store.progress.equippedGear.values.contains($0) }.count

                VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.compactSpacing) {
                    Label(world.gearSetName, systemImage: world.id.icon)
                        .font(.headline.bold())
                        .foregroundStyle(world.id.accentColor)
                    Text(GearCatalog.setBonus(for: world.id))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        GameStatusBadge(text: "\(earned)/5 EARNED", tone: earned == 5 ? .positive : .neutral)
                        GameStatusBadge(text: "\(equipped)/5 EQUIPPED", tone: equipped == 5 ? .positive : .neutral)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(GoalRushTheme.Metrics.standardSpacing)
                .gameSurface(.panel)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
