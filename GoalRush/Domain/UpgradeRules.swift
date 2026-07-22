import Foundation

enum UpgradeRules {
    static let maxRank = 5
    static let costs = [100, 225, 450, 800, 1_300]

    static func cost(forNextRank currentRank: Int) -> Int {
        costs[min(max(currentRank, 0), costs.count - 1)]
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
        case .tempo: "12% shorter kick interval per rank"
        case .impact: "+10% ball damage per rank"
        case .flight: "+6% ball speed per rank"
        case .spin: "+3% critical chance per rank"
        }
    }
}
