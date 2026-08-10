import SwiftUI

struct AtmosphericGameScreen<Content: View>: View {
    let backgroundImage: String
    @ViewBuilder let content: Content

    init(backgroundImage: String, @ViewBuilder content: () -> Content) {
        self.backgroundImage = backgroundImage
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                GoalRushTheme.navy
                    .ignoresSafeArea()

                Image(backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                VStack(spacing: 0) {
                    GoalRushTheme.topScrim
                        .frame(height: max(180, proxy.size.height * 0.30))
                    Spacer(minLength: 0)
                    GoalRushTheme.bottomScrim
                        .frame(height: max(220, proxy.size.height * 0.38))
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
