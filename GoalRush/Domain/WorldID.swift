import Foundation

enum WorldID: String, Codable, CaseIterable, Identifiable, Sendable {
    case earth
    case moon
    case mars

    var id: String { rawValue }
}
