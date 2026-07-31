import Foundation

enum UpgradeRules {
    /// The authored opening price curve ends here. Ranks remain unlimited.
    static let masteryRank = 5
    static let costs = [100, 275, 600, 1_050, 1_800]
    static let masteryCost = costs[costs.count - 1]
    /// Each post-mastery marginal price adds 14% of the mastery price. This
    /// makes cumulative spending quadratic without placing a cap on ranks.
    static let postMasteryMarginalGrowth = 0.14
    static let minimumKickCooldown = 0.12

    static func cost(forNextRank currentRank: Int) -> Int {
        let safeRank = max(0, currentRank)
        guard safeRank >= masteryRank else { return costs[safeRank] }
        let ranksPastMastery = Double(safeRank - masteryRank)
        let rawCost = Double(masteryCost)
            * (1 + postMasteryMarginalGrowth * ranksPastMastery)
        return Int((rawCost / 25).rounded()) * 25
    }

    static func kickCooldown(for rank: Int) -> Double {
        kickCooldown(for: Double(max(0, rank)))
    }

    static func kickCooldown(for rank: Double) -> Double {
        let safeRank = max(0, rank)
        let openingCooldown = 1.12 * pow(0.88, min(safeRank, Double(masteryRank)))
        guard safeRank > Double(masteryRank) else { return openingCooldown }
        return minimumKickCooldown
            + (openingCooldown - minimumKickCooldown)
                * pow(0.88, safeRank - Double(masteryRank))
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
