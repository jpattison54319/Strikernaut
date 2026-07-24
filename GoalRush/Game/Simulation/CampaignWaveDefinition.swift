import Foundation

struct CampaignWaveDefinition: Equatable, Sendable {
    let number: Int
    let totalWaves: Int
    let duration: TimeInterval
    let healthMultiplier: Double
    let damageMultiplier: Double
    let speedMultiplier: Double
    let spawnInterval: TimeInterval
    let boss: EnemyKind
    let bossTier: CampaignBossTier
}
