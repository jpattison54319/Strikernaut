import Foundation

struct GearLoadout: Equatable, Sendable {
    var equipped: [GearSlot: GearID]

    static let empty = GearLoadout(equipped: [:])

    func item(in slot: GearSlot) -> GearID? { equipped[slot] }

    func wearsCompleteSet(for world: WorldID) -> Bool {
        let expected = Set(GearCatalog.items(for: world).map(\.id))
        return expected.count == GearSlot.allCases.count && Set(equipped.values).isSuperset(of: expected)
    }
}
