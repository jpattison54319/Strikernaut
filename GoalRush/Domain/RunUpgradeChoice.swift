import Foundation

enum RunUpgradeChoice: Hashable, Identifiable, Sendable {
    case ability(AbilityKind)
    case specialBall(TemporaryBallAbility)

    var id: String {
        switch self {
        case .ability(let ability):
            "ability-\(ability.rawValue)"
        case .specialBall(let ability):
            "special-ball-\(ability.rawValue)"
        }
    }

    static var endlessPool: [RunUpgradeChoice] {
        AbilityKind.allCases.map(Self.ability)
            + EndlessSpecialBallRules.abilities.map(Self.specialBall)
    }
}
