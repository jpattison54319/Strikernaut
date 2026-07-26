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
        .init(
            id: "jupiter",
            name: "Jupiter Citadel",
            subtitle: "Future Transmission",
            world: nil,
            futureRequirement: "Clear Mars to recruit Aegis. Jupiter Citadel arrives in a future chapter."
        )
    ]

    static var pages: [[WorldJourneyDestination]] {
        stride(from: 0, to: destinations.count, by: pageSize).map { start in
            Array(destinations[start..<min(start + pageSize, destinations.count)])
        }
    }
}
