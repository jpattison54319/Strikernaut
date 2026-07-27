import Foundation

enum TemporaryBallAbility: String, CaseIterable, Identifiable, Sendable {
    case rapidFire
    case explosive
    case fire
    case ice
    case reverse
    case split
    case heatSeeking
    case orbitShot
    case solarPierce
    case volt

    var id: String { rawValue }
}
