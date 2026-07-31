import Foundation

struct WorldJourneyDestination: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let subtitle: String
    let world: WorldID?
    let futureRequirement: String?

    var isFuture: Bool { world == nil }
}

enum WorldJourneyCatalog {
    static let pageSize = 3

    static let destinations: [WorldJourneyDestination] = [
        .init(id: "earth", name: "Earth", subtitle: "Training Grounds", world: .earth, futureRequirement: nil),
        .init(id: "moon", name: "Moon", subtitle: "Lunar League", world: .moon, futureRequirement: nil),
        .init(id: "mars", name: "Mars", subtitle: "Red Frontier", world: .mars, futureRequirement: nil),
        .init(id: "jupiter", name: "Jupiter", subtitle: "Storm Citadel", world: .jupiter, futureRequirement: nil),
        .init(id: "saturn", name: "Saturn", subtitle: "Crown of Rings", world: .saturn, futureRequirement: nil),
        .init(id: "uranus", name: "Uranus", subtitle: "Tilted Frontier", world: .uranus, futureRequirement: nil),
        .init(id: "neptune", name: "Neptune", subtitle: "Tempest Deep", world: .neptune, futureRequirement: nil),
        .init(
            id: "andromeda",
            name: "Andromeda Signal",
            subtitle: "Beyond the Milky Way",
            world: nil,
            futureRequirement: "Clear Neptune to triangulate the signal. Coordinates remain unstable."
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
