import SwiftUI

struct HomeBrand: View {
    var body: some View {
        VStack(spacing: 1) {
            Text("STRIKERNAUT")
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .tracking(1.6)
                .foregroundStyle(.white)
                .shadow(color: GoalRushTheme.blue.opacity(0.8), radius: 10)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home-brand")
    }
}
