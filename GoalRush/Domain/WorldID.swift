import Foundation

enum WorldID: String, Codable, CaseIterable, Identifiable, Sendable {
    case earth
    case moon
    case mars

    var id: String { rawValue }

    func factionSigilAsset(isBoss: Bool) -> String {
        switch (self, isBoss) {
        case (.earth, false): "EarthFactionSigil"
        case (.earth, true): "EarthBossFactionSigil"
        case (.moon, false): "MoonFactionSigil"
        case (.moon, true): "MoonBossFactionSigil"
        case (.mars, false): "MarsFactionSigil"
        case (.mars, true): "MarsBossFactionSigil"
        }
    }
}
