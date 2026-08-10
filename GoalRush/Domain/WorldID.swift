import Foundation

nonisolated enum WorldID: String, Codable, CaseIterable, Identifiable, Sendable {
    case earth
    case moon
    case mars
    case jupiter
    case saturn
    case uranus
    case neptune

    var id: String { rawValue }

    func factionSigilAsset(isBoss: Bool) -> String {
        switch (self, isBoss) {
        case (.earth, false): "EarthFactionSigil"
        case (.earth, true): "EarthBossFactionSigil"
        case (.moon, false): "MoonFactionSigil"
        case (.moon, true): "MoonBossFactionSigil"
        case (.mars, false): "MarsFactionSigil"
        case (.mars, true): "MarsBossFactionSigil"
        case (.jupiter, false): "JupiterFactionSigil"
        case (.jupiter, true): "JupiterBossFactionSigil"
        case (.saturn, false): "SaturnFactionSigil"
        case (.saturn, true): "SaturnBossFactionSigil"
        case (.uranus, false): "UranusFactionSigil"
        case (.uranus, true): "UranusBossFactionSigil"
        case (.neptune, false): "NeptuneFactionSigil"
        case (.neptune, true): "NeptuneBossFactionSigil"
        }
    }
}
