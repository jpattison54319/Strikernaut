import Foundation

struct LifetimeStats: Codable, Equatable, Sendable {
    var totalTokensEarned = 0
    var totalRuns = 0
    var totalWavesCleared = 0
    var totalTargetsDefeated = 0
    var bossesDefeated = 0
    var bestCombo = 0
    var upgradesPurchased = 0
}
