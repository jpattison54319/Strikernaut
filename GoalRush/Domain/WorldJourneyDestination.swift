import Foundation

struct WorldJourneyDestination: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let subtitle: String
    let action: WorldJourneyAction

    var world: WorldID? {
        if case .world(let world) = action { world } else { nil }
    }
}

enum WorldJourneyAction: Equatable, Sendable {
    case world(WorldID)
    case newGamePlus
}

enum WorldJourneyCatalog {
    static let pageSize = 3

    static let destinations: [WorldJourneyDestination] = [
        .init(id: "earth", name: "Earth", subtitle: "Training Grounds", action: .world(.earth)),
        .init(id: "moon", name: "Moon", subtitle: "Lunar League", action: .world(.moon)),
        .init(id: "mars", name: "Mars", subtitle: "Red Frontier", action: .world(.mars)),
        .init(id: "jupiter", name: "Jupiter", subtitle: "Storm Citadel", action: .world(.jupiter)),
        .init(id: "saturn", name: "Saturn", subtitle: "Crown of Rings", action: .world(.saturn)),
        .init(id: "uranus", name: "Uranus", subtitle: "Tilted Frontier", action: .world(.uranus)),
        .init(id: "neptune", name: "Neptune", subtitle: "Tempest Deep", action: .world(.neptune)),
        .init(
            id: "new-game-plus",
            name: "New Game+",
            subtitle: "A Harder Journey",
            action: .newGamePlus
        )
    ]

    static var pages: [[WorldJourneyDestination]] {
        stride(from: 0, to: destinations.count, by: pageSize).map { start in
            Array(destinations[start..<min(start + pageSize, destinations.count)])
        }
    }

    /// Keeps logical progression starting at page zero while placing later
    /// destinations physically above earlier ones in the vertical journey.
    static var pageIndicesTopToBottom: [Int] {
        Array(pages.indices.reversed())
    }
}
