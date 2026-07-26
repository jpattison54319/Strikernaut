import Foundation

enum CampaignRoute: Equatable, Sendable {
    case planets(page: Int)
    case worldMap(world: WorldID, focusLevel: Int?)
}
