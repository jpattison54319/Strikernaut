import Foundation

enum LifetimeMetricKind: String, CaseIterable, Identifiable {
    case runs
    case endlessWaves
    case targets
    case bosses
    case bestCombo
    case runTokens
    case upgrades
    case abilityDefeats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .runs: "Runs"
        case .endlessWaves: "Endless waves"
        case .targets: "Targets"
        case .bosses: "Bosses"
        case .bestCombo: "Best combo"
        case .runTokens: "Run tokens"
        case .upgrades: "Upgrades"
        case .abilityDefeats: "Ability KOs"
        }
    }

    var icon: String {
        switch self {
        case .runs: "play.fill"
        case .endlessWaves: "infinity"
        case .targets: "scope"
        case .bosses: "crown.fill"
        case .bestCombo: "bolt.fill"
        case .runTokens: "hexagon.fill"
        case .upgrades: "arrow.up.circle.fill"
        case .abilityDefeats: "star.circle.fill"
        }
    }

    func value(from stats: LifetimeStats) -> String {
        switch self {
        case .runs:
            GameNumberFormatter.compact(stats.totalRuns)
        case .endlessWaves:
            GameNumberFormatter.compact(stats.totalWavesCleared)
        case .targets:
            GameNumberFormatter.compact(stats.totalTargetsDefeated)
        case .bosses:
            GameNumberFormatter.compact(stats.bossesDefeated)
        case .bestCombo:
            "×\(GameNumberFormatter.compact(stats.bestCombo))"
        case .runTokens:
            GameNumberFormatter.compact(stats.totalTokensEarned)
        case .upgrades:
            GameNumberFormatter.compact(stats.upgradesPurchased)
        case .abilityDefeats:
            GameNumberFormatter.compact(stats.totalCharacterAbilityDefeats)
        }
    }

    func accessibilityValue(from stats: LifetimeStats) -> String {
        let value = switch self {
        case .runs: stats.totalRuns
        case .endlessWaves: stats.totalWavesCleared
        case .targets: stats.totalTargetsDefeated
        case .bosses: stats.bossesDefeated
        case .bestCombo: stats.bestCombo
        case .runTokens: stats.totalTokensEarned
        case .upgrades: stats.upgradesPurchased
        case .abilityDefeats: stats.totalCharacterAbilityDefeats
        }
        return GameNumberFormatter.exact(value)
    }
}
