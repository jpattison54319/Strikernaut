import Foundation

nonisolated enum TemporaryBallAbility: String, Codable, CaseIterable, Identifiable, Sendable {
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
    case gravityWell
    case ringReturn
    case polarLink
    case undertow

    var id: String { rawValue }
}
