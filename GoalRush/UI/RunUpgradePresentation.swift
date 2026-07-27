import SwiftUI

struct AbilityEffectPresentation {
    let metric: String
    let current: String
    let next: String
    let accent: Color
}

struct RunUpgradePresentation {
    let title: String
    let artAsset: String
    let benefit: String
    let effect: AbilityEffectPresentation

    static func rankLabel(forCurrentRank currentRank: Int) -> String {
        currentRank == 0
            ? "NEW • RANK 1"
            : "RANK \(currentRank) → \(currentRank + 1)"
    }
}
