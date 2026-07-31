import CoreGraphics
import Foundation

struct LandmarkPlacement: Identifiable, Equatable, Sendable {
    let levelNumber: Int
    let x: CGFloat
    let y: CGFloat

    var id: Int { levelNumber }
}

struct WorldMapDefinition: Identifiable, Equatable, Sendable {
    let id: WorldID
    let backgroundAsset: String
    let landmarkSymbol: String
    let placements: [LandmarkPlacement]
}

enum WorldMapCatalog {
    static func map(for world: WorldID) -> WorldMapDefinition {
        let definition = GameContent.world(world)
        let positions: [(CGFloat, CGFloat)] = [
            (0.30, 0.91), (0.68, 0.82), (0.37, 0.73), (0.72, 0.64), (0.28, 0.55),
            (0.66, 0.46), (0.36, 0.37), (0.72, 0.28), (0.32, 0.19), (0.61, 0.09)
        ]
        let symbol: String = switch world {
        case .earth: "building.2.crop.circle.fill"
        case .moon: "antenna.radiowaves.left.and.right.circle.fill"
        case .mars: "mountain.2.circle.fill"
        case .jupiter: "hurricane.circle.fill"
        case .saturn: "circle.hexagongrid.circle.fill"
        case .uranus: "snowflake.circle.fill"
        case .neptune: "water.waves"
        }
        return WorldMapDefinition(
            id: world,
            backgroundAsset: definition.mapAsset,
            landmarkSymbol: symbol,
            placements: zip(GameContent.levels(in: world), positions).map { level, position in
                LandmarkPlacement(levelNumber: level.number, x: position.0, y: position.1)
            }
        )
    }
}
