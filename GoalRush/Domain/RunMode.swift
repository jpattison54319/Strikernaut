import Foundation

enum RunMode: Equatable, Sendable {
    case campaign(level: Int)
    case endless(world: WorldID)

    var isEndless: Bool {
        if case .endless = self { true } else { false }
    }

    var world: WorldID {
        switch self {
        case .campaign(let level): GameContent.level(level).world
        case .endless(let world): world
        }
    }

    var campaignLevel: Int? {
        if case .campaign(let level) = self { level } else { nil }
    }
}
