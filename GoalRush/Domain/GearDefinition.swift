import Foundation

struct GearDefinition: Identifiable, Equatable, Sendable {
    let id: GearID
    let slot: GearSlot
    let world: WorldID
    let name: String
    let shortName: String
    let effect: String
    let modifiers: GearModifiers
}
