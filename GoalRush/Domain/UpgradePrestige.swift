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

    static func segment(level: Int, prestigeCount: Int) -> (filled: Int, start: Int, end: Int?) {
        guard let nextTier = nextTier(prestigeCount: prestigeCount) else {
            return (10, UpgradePrestigeTier.diamond.threshold, nil)
        }
        let start = prestigeCount == 0
            ? 0
            : UpgradePrestigeTier.allCases[prestigeCount - 1].threshold
        let span = max(1, nextTier.threshold - start)
        let progress = min(span, max(0, level - start))
        let filled = progress == 0 ? 0 : Int(ceil(Double(progress) / Double(span) * 10))
        return (min(10, filled), start, nextTier.threshold)
    }
}
