import SwiftUI

enum ProgressCategory: String, CaseIterable, Identifiable {
    case trophies
    case lifetime
    case collections

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trophies: "Trophies"
        case .lifetime: "Lifetime"
        case .collections: "Collections"
        }
    }

    var subtitle: String {
        switch self {
        case .trophies: "Achievements"
        case .lifetime: "Journey totals"
        case .collections: "Characters"
        }
    }

    var icon: String {
        switch self {
        case .trophies: "trophy.fill"
        case .lifetime: "chart.bar.fill"
        case .collections: "person.3.fill"
        }
    }

    var accent: Color {
        switch self {
        case .trophies: GoalRushTheme.gold
        case .lifetime: GoalRushTheme.cyan
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

    private var collections: some View {
        VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            ForEach(CharacterCatalog.characters) { character in
                let unlocked = store.progress.unlockedCharacters.contains(character.id)
                VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.compactSpacing) {
                    Label(character.name, systemImage: unlocked ? "person.crop.circle.fill.badge.checkmark" : "lock.fill")
                        .font(.headline.bold())
                        .foregroundStyle(unlocked ? GoalRushTheme.cyan : .secondary)
                    Text("\(character.abilityName): \(character.abilityDescription)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                    GameStatusBadge(
                        text: unlocked ? (store.progress.selectedCharacter == character.id ? "SELECTED" : "UNLOCKED") : character.unlockDescription.uppercased(),
                        tone: unlocked ? .positive : .neutral
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(GoalRushTheme.Metrics.standardSpacing)
                .gameSurface(.panel)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
