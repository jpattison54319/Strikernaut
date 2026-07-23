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
                    accessibilityControls
                }
            } else {
                ZStack {
                    titleLabel
                        .padding(.horizontal, 110)
                    standardControls
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
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    private var accessibilityControls: some View {
        VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
            homeButton
            infoButton
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(.white)
        .buttonStyle(.plain)
    }

    private var standardControls: some View {
        HStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            homeButton

            Spacer(minLength: GoalRushTheme.Metrics.compactSpacing)

            infoButton
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
    }

    private var homeButton: some View {
        Button(action: onHome) {
            Label("Home", systemImage: "house.fill")
                .font(.subheadline.bold())
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, GoalRushTheme.Metrics.standardSpacing)
                .frame(
                    maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
                    minHeight: GoalRushTheme.Metrics.minimumTapTarget,
                    alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center
                )
        }
    }

    private var infoButton: some View {
        Button(action: onInfo) {
            HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                Text(trailingText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "info.circle.fill")
                    .accessibilityHidden(true)
            }
            .font(.subheadline.bold())
            .multilineTextAlignment(.leading)
            .padding(.horizontal, GoalRushTheme.Metrics.standardSpacing)
            .frame(
                maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
                minHeight: GoalRushTheme.Metrics.minimumTapTarget,
                alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center
            )
        }
    }
}
