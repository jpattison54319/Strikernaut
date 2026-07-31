import Foundation

nonisolated enum RunMode: Codable, Equatable, Sendable {
    case campaign(level: Int)
    case endless

    var isEndless: Bool {
        if case .endless = self { true } else { false }
    }

    @MainActor
    var world: WorldID {
        switch self {
        case .campaign(let level): GameContent.level(level).world
        case .endless: EndlessRules.world(for: 1)
        }
    }

    var campaignLevel: Int? {
        if case .campaign(let level) = self { level } else { nil }
    }
}
