import SwiftUI

struct GameDestinationBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let trailingText: String?
    let onHome: () -> Void
    let onInfo: (() -> Void)?

    init(
        title: String,
        trailingText: String? = nil,
        onHome: @escaping () -> Void,
        onInfo: (() -> Void)? = nil
    ) {
        self.title = title
        self.trailingText = trailingText
        self.onHome = onHome
        self.onInfo = onInfo
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                    titleLabel
                        .frame(maxWidth: .infinity)
                    accessibilityControls
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    singleRowControls
                    compactTwoRowControls
                }
            }
        }
        .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
        .padding(.vertical, GoalRushTheme.Metrics.compactSpacing)
        .background(GoalRushTheme.ink.opacity(0.90))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(GoalRushTheme.paper.opacity(0.60))
                .frame(height: GoalRushTheme.Metrics.inkStrokeWidth)
        }
        .overlay { ComicInkTexture(opacity: 0.07).allowsHitTesting(false) }
    }

    private var titleLabel: some View {
        Text(title)
            .font(GoalRushTheme.Typography.headline)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var accessibilityControls: some View {
        VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
            homeButton
            if onInfo != nil, trailingText != nil {
                infoButton
            }
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(.white)
        .buttonStyle(.plain)
    }

    private var singleRowControls: some View {
        HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
            homeButton
                .fixedSize(horizontal: true, vertical: false)

            titleLabel
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(minWidth: 88, maxWidth: .infinity)
                .layoutPriority(1)

            trailingControl
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
    }

    private var compactTwoRowControls: some View {
        VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
            titleLabel
                .frame(maxWidth: .infinity)

            HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                homeButton
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: GoalRushTheme.Metrics.compactSpacing)
                if onInfo != nil, trailingText != nil {
                    infoButton
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
    }

    private var homeButton: some View {
        Button(action: onHome) {
            Label("Home", systemImage: "house.fill")
                .font(GoalRushTheme.Typography.subheadlineEmphasized)
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
        Button(action: { onInfo?() }) {
            HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                Text(trailingText ?? "")
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "info.circle.fill")
                    .accessibilityHidden(true)
            }
            .font(GoalRushTheme.Typography.subheadlineEmphasized)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, GoalRushTheme.Metrics.standardSpacing)
            .frame(
                maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
                minHeight: GoalRushTheme.Metrics.minimumTapTarget,
                alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center
            )
        }
    }

    @ViewBuilder
    private var trailingControl: some View {
        if onInfo != nil, trailingText != nil {
            infoButton
                .fixedSize(horizontal: true, vertical: false)
        } else {
            homeButton
                .hidden()
                .accessibilityHidden(true)
                .allowsHitTesting(false)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}
