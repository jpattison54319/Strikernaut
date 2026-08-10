import SwiftUI

struct CampaignNavigationView: View {
    let route: CampaignRoute

    var body: some View {
        switch route {
        case .planets(let page):
            PlanetJourneyView(initialPage: page)
        case .worldMap(let world, let focusLevel):
            WorldLandmarkMapView(world: world, focusLevel: focusLevel)
        }
    }
}
