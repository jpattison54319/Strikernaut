import Foundation

enum Celebration: Equatable, Identifiable, Sendable {
    case achievement(AchievementID)

    var id: String {
        switch self {
        case .achievement(let achievement): "achievement-\(achievement.rawValue)"
        }
    }
}
