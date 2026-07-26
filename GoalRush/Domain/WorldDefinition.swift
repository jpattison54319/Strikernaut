import Foundation

enum WorldRule: String, Codable, Sendable {
    case lunarCycle
    case volatileCores
}

struct WorldDefinition: Identifiable, Sendable {
    let id: WorldID
    let name: String
    let subtitle: String
    let chapter: String
    let levelRange: ClosedRange<Int>
    let gameplayAsset: String
    let heroAsset: String
    let mapAsset: String
    let boss: EnemyKind
    let rule: WorldRule?
    let temporaryPowers: [TemporaryBallAbility]
    var finalLevel: Int { levelRange.upperBound }
}
