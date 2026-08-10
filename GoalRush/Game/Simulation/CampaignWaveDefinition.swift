import Foundation

struct CampaignWaveDefinition: Equatable, Sendable {
    let number: Int
    let totalWaves: Int
    let enemyQuota: Int
    let healthMultiplier: Double
    let damageMultiplier: Double
    let speedMultiplier: Double
    let spawnInterval: TimeInterval
    let boss: EnemyKind?
    let bossTier: CampaignBossTier?

    var isBossWave: Bool { boss != nil }
}
