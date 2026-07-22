import Foundation

enum WorldID: String, Codable, CaseIterable, Identifiable, Sendable {
    case earth
    case mars

    var id: String { rawValue }
}
