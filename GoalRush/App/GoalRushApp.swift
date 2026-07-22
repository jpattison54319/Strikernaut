import SwiftUI

@main
struct GoalRushApp: App {
    @State private var store = GameStore.bootstrap()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
        }
    }
}
