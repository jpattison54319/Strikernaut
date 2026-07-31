import Foundation

enum WorldRule: String, Codable, Sendable {
    case lunarCycle
    case volatileCores
    case windShear
    case ringSweep
    case cryoDrift
    case pressureTide
}

struct WorldHazardDefinition: Equatable, Sendable {
    let cadence: TimeInterval
    let telegraphDuration: TimeInterval
    let activeDuration: TimeInterval
    let baseDamage: Double
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
    let hazard: WorldHazardDefinition?
    let temporaryPowers: [TemporaryBallAbility]
    let endlessEnemies: [EnemyKind]
    let endlessObjects: [FieldObjectKind]
    var finalLevel: Int { levelRange.upperBound }
}
