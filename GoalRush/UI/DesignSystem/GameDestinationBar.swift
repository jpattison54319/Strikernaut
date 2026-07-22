import SwiftUI

struct GameDestinationBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let trailingText: String
    let onHome: () -> Void
    let onInfo: () -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                    titleLabel
                    controls
                }
            } else {
                ZStack {
                    titleLabel
                        .padding(.horizontal, 110)
                    controls
                }
            }
        }
        .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
        .padding(.vertical, GoalRushTheme.Metrics.compactSpacing)
        .background(GoalRushTheme.navy.opacity(0.72))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(GoalRushTheme.surfaceStroke)
                .frame(height: GoalRushTheme.Metrics.strokeWidth)
        }
    }

    private var titleLabel: some View {
        Text(title)
            .font(.headline.weight(.heavy))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
    }

    private var controls: some View {
        HStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            Button(action: onHome) {
                Label("Home", systemImage: "house.fill")
                    .font(.subheadline.bold())
                    .padding(.horizontal, GoalRushTheme.Metrics.standardSpacing)
                    .frame(minHeight: GoalRushTheme.Metrics.minimumTapTarget)
            }

            Spacer(minLength: GoalRushTheme.Metrics.compactSpacing)

            Button(action: onInfo) {
                HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                    Text(trailingText)
                        .lineLimit(1)
                    Image(systemName: "info.circle.fill")
                        .accessibilityHidden(true)
                }
                .font(.subheadline.bold())
                .padding(.horizontal, GoalRushTheme.Metrics.standardSpacing)
                .frame(minHeight: GoalRushTheme.Metrics.minimumTapTarget)
            }
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
    }
}
