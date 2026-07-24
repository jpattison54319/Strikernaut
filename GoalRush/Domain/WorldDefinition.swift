import Foundation

struct WorldDefinition: Identifiable, Sendable {
    let id: WorldID
    let name: String
    let subtitle: String
    let chapter: String
    let levelRange: ClosedRange<Int>
    let gameplayAsset: String
    let heroAsset: String
    let boss: EnemyKind
    var finalLevel: Int { levelRange.upperBound }
}
