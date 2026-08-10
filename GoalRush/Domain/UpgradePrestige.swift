import Foundation

enum UpgradePrestigeTier: Int, Codable, CaseIterable, Identifiable, Sendable {
    case bronze = 1
    case silver
    case gold
    case platinum
    case diamond

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .bronze: "Bronze"
        case .silver: "Silver"
        case .gold: "Gold"
        case .platinum: "Platinum"
        case .diamond: "Diamond"
        }
    }

    var threshold: Int {
        switch self {
        case .bronze: 10
        case .silver: 20
        case .gold: 50
        case .platinum: 100
        case .diamond: 200
        }
    }

}

enum UpgradePrestigeRules {
    static let prestigeCost = 2_600

    static func earnedTiers(prestigeCount: Int) -> ArraySlice<UpgradePrestigeTier> {
        UpgradePrestigeTier.allCases.prefix(min(max(prestigeCount, 0), UpgradePrestigeTier.allCases.count))
    }

    static func nextTier(prestigeCount: Int) -> UpgradePrestigeTier? {
        let index = min(max(prestigeCount, 0), UpgradePrestigeTier.allCases.count)
        guard UpgradePrestigeTier.allCases.indices.contains(index) else { return nil }
        return UpgradePrestigeTier.allCases[index]
    }

    static func currentTier(prestigeCount: Int) -> UpgradePrestigeTier? {
        earnedTiers(prestigeCount: prestigeCount).last
    }

    /// The level shown inside the currently earned badge.
    ///
    /// Global rank remains the permanent combat value. The badge threshold is
    /// only subtracted for presentation, so rank 10 with Bronze earned is
    /// "Bronze 0", rank 20 with Silver earned is "Silver 0", and so on.
    static func localLevel(level: Int, prestigeCount: Int) -> Int {
        let badgeStart = currentTier(prestigeCount: prestigeCount)?.threshold ?? 0
        return max(0, level - badgeStart)
    }

    static func requiresPrestige(level: Int, prestigeCount: Int) -> Bool {
        guard let nextTier = nextTier(prestigeCount: prestigeCount) else { return false }
        return level >= nextTier.threshold
    }

    static func purchaseCost(level: Int, prestigeCount: Int) -> Int {
        requiresPrestige(level: level, prestigeCount: prestigeCount)
            ? prestigeCost
            : UpgradeRules.cost(forNextRank: level)
    }

    static func migratedPrestigeCount(for level: Int) -> Int {
        UpgradePrestigeTier.allCases.filter { level > $0.threshold }.count
    }

    /// Total tokens needed to take one track from rank zero to `rank`,
    /// including every prestige payment required to cross a threshold.
    static func totalInvestment(toReachRank rank: Int) -> Int {
        let safeRank = max(0, rank)
        let upgradeSpend = (0..<safeRank).reduce(0) {
            $0 + UpgradeRules.cost(forNextRank: $1)
        }
        let prestigeSpend = UpgradePrestigeTier.allCases.count {
            $0.threshold < safeRank
        } * prestigeCost
        return upgradeSpend + prestigeSpend
    }

    /// One progress marker represents one real level toward the next badge.
    static func segment(
        level: Int,
        prestigeCount: Int
    ) -> (filled: Int, total: Int, start: Int, end: Int?) {
        guard let nextTier = nextTier(prestigeCount: prestigeCount) else {
            return (0, 0, UpgradePrestigeTier.diamond.threshold, nil)
        }
        let start = currentTier(prestigeCount: prestigeCount)?.threshold ?? 0
        let total = max(1, nextTier.threshold - start)
        let filled = min(total, max(0, level - start))
        return (filled, total, start, nextTier.threshold)
    }
}
