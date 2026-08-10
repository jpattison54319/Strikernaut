import SwiftUI

extension EndlessRelicRarity {
    var color: Color {
        switch self {
        case .common:
            Color(red: 232 / 255, green: 237 / 255, blue: 242 / 255)
        case .uncommon:
            Color(red: 57 / 255, green: 211 / 255, blue: 83 / 255)
        case .rare:
            Color(red: 47 / 255, green: 125 / 255, blue: 255 / 255)
        case .epic:
            Color(red: 168 / 255, green: 85 / 255, blue: 247 / 255)
        case .legendary:
            Color(red: 255 / 255, green: 138 / 255, blue: 31 / 255)
        }
    }
}
