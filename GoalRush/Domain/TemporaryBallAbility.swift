import Foundation

enum TemporaryBallAbility: String, CaseIterable, Identifiable, Sendable {
    case rapidFire
    case explosive
    case fire
    case ice
    case reverse
    case split

    var id: String { rawValue }
}
