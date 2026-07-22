import SwiftUI

struct HomeLaunchControl: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let eyebrow: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.compactSpacing) {
                        Label(eyebrow, systemImage: "play.fill")
                            .font(.headline.weight(.heavy))
                        Text(title)
                            .font(.title3.weight(.heavy))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                        Image(systemName: "play.fill")
                            .font(.title2.bold())
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.88), in: .circle)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(eyebrow)
                                .font(.caption.weight(.heavy))
                                .tracking(1.1)
                            Text(title)
                                .font(.headline.weight(.heavy))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: GoalRushTheme.Metrics.compactSpacing)
                        Image(systemName: "chevron.right")
                            .font(.headline.bold())
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .buttonStyle(GameLaunchButtonStyle())
        .accessibilityIdentifier("continue-hero")
    }
}
