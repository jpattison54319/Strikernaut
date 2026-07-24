import Foundation

enum UpgradeRules {
    /// The authored opening price curve ends here. Ranks remain unlimited.
    static let masteryRank = 5
    static let costs = [100, 225, 450, 800, 1_300]
    static let sustainedCost = costs[costs.count - 1]
    static let minimumKickCooldown = 0.12

    static func cost(forNextRank currentRank: Int) -> Int {
        costs[min(max(currentRank, 0), costs.count - 1)]
    }

    static func kickCooldown(for rank: Int) -> Double {
        let safeRank = max(0, rank)
        let openingCooldown = 1.12 * pow(0.88, Double(min(safeRank, masteryRank)))
        guard safeRank > masteryRank else { return openingCooldown }
        return minimumKickCooldown
            + (openingCooldown - minimumKickCooldown) * pow(0.88, Double(safeRank - masteryRank))
    }

    static func title(for track: UpgradeTrack) -> String {
        switch track {
        case .conditioning: "Conditioning"
        case .footwork: "Footwork"
        case .tempo: "Tempo"
        case .impact: "Impact"
        case .flight: "Flight"
        case .spin: "Spin"
        }
    }

    static func description(for track: UpgradeTrack) -> String {
        switch track {
        case .conditioning: "+8% maximum stamina per rank"
        case .footwork: "+7% lateral response per rank"
        case .tempo: "12% shorter remaining kick interval per rank"
        case .impact: "+10% ball damage per rank"
        case .flight: "+6% ball speed per rank"
        case .spin: "+3% critical power per rank; overflow adds damage tiers"
        }
    }
}
