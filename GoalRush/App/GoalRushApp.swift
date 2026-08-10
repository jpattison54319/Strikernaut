import SwiftUI

@main
struct GoalRushApp: App {
    @State private var store = GameStore.bootstrap()
    @State private var rewardedAds = RewardedAdService()

    var body: some Scene {
        WindowGroup {
            Group {
                if let debugDynamicTypeSize {
                    RootView()
                        .environment(\.dynamicTypeSize, debugDynamicTypeSize)
                } else {
                    RootView()
                }
            }
            .environment(store)
            .environment(rewardedAds)
            .preferredColorScheme(.dark)
        }
    }

    private var debugDynamicTypeSize: DynamicTypeSize? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(
            "--dynamic-type-accessibility-xxxl"
        ) {
            return .accessibility5
        }
        #endif
        return nil
    }
}
