import SwiftUI

struct AbilityChoiceCard: View {
    let presentation: RunUpgradePresentation
    let currentRank: Int
    let selectionHint: String
    let identifier: String
    let choose: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: choose) {
            VStack(spacing: 0) {
                rankStrip
                artwork
                effectSummary
                Spacer(minLength: 8)
                chooseStrip
            }
            .frame(minHeight: usesPortraitDeck ? 408 : nil)
            .frame(maxWidth: .infinity)
            .foregroundStyle(GoalRushTheme.navy)
            .background {
                RoundedRectangle(cornerRadius: 13)
                    .fill(GoalRushTheme.paper)
            }
            .overlay {
                AbilityCardPrintTexture()
            }
            .clipShape(.rect(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(GoalRushTheme.ink, lineWidth: 3)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        presentation.effect.accent.opacity(0.82),
                        lineWidth: 2
                    )
                    .padding(4)
            }
            .shadow(
                color: GoalRushTheme.ink.opacity(0.52),
                radius: 6,
                y: 6
            )
        }
        .buttonStyle(AbilityChoiceButtonStyle(accent: presentation.effect.accent))
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(selectionHint)
        .accessibilityIdentifier(identifier)
    }

    private var rankStrip: some View {
        Text(rankLabel)
            .font(GoalRushTheme.Typography.captionEmphasized)
            .foregroundStyle(GoalRushTheme.paper)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .frame(minHeight: 30)
            .background(GoalRushTheme.ink)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(presentation.effect.accent)
                    .frame(height: 3)
            }
    }

    private var artwork: some View {
        ZStack {
            LinearGradient(
                colors: [
                    presentation.effect.accent.opacity(0.48),
                    GoalRushTheme.surfaceRaised,
                    GoalRushTheme.ink,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ComicInkTexture(opacity: 0.10)

            Image(presentation.artAsset)
                .resizable()
                .scaledToFit()
                .padding(3)
                .shadow(
                    color: presentation.effect.accent.opacity(0.38),
                    radius: 8
                )
                .accessibilityHidden(true)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: usesPortraitDeck ? .infinity : 190)
        .clipShape(.rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(GoalRushTheme.ink, lineWidth: 2)
        }
        .padding(.horizontal, 7)
        .padding(.top, 7)
    }

    private var effectSummary: some View {
        VStack(spacing: 5) {
            Text(presentation.title)
                .font(GoalRushTheme.Typography.title3)
                .bold()
                .lineLimit(2, reservesSpace: usesPortraitDeck)
                .minimumScaleFactor(0.72)

            if !presentation.benefit.isEmpty {
                Text(presentation.benefit)
                    .font(GoalRushTheme.Typography.captionEmphasized)
                    .foregroundStyle(GoalRushTheme.navy.opacity(0.86))
                    .lineLimit(2, reservesSpace: usesPortraitDeck)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(.center)
            }

            chanceSummary

            Text(presentation.effect.metric.uppercased())
                .font(GoalRushTheme.Typography.captionEmphasized)
                .foregroundStyle(GoalRushTheme.navy.opacity(0.78))
                .lineLimit(2, reservesSpace: usesPortraitDeck)
                .minimumScaleFactor(0.72)

            Text(presentation.effect.next)
                .font(GoalRushTheme.Typography.metric(size: 20))
                .foregroundStyle(GoalRushTheme.navy)
                .lineLimit(2, reservesSpace: usesPortraitDeck)
                .minimumScaleFactor(0.62)
                .multilineTextAlignment(.center)

            Text("FROM \(presentation.effect.current.uppercased())")
                .font(GoalRushTheme.Typography.captionEmphasized)
                .foregroundStyle(GoalRushTheme.navy.opacity(0.72))
                .lineLimit(2, reservesSpace: usesPortraitDeck)
                .minimumScaleFactor(0.62)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 8)
        .padding(.top, 7)
    }

    @ViewBuilder
    private var chanceSummary: some View {
        if let current = presentation.effect.chanceCurrent,
           let next = presentation.effect.chanceNext {
            VStack(spacing: 1) {
                Text("CHANCE PER BALL")
                    .font(GoalRushTheme.Typography.captionEmphasized)
                Text(current == next ? next : "\(current) → \(next)")
                    .font(GoalRushTheme.Typography.metric(size: 17))
                    .monospacedDigit()
            }
            .foregroundStyle(GoalRushTheme.navy)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(presentation.effect.accent.opacity(0.18))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        presentation.effect.accent.opacity(0.82),
                        lineWidth: 1.5
                    )
            }
            .clipShape(.rect(cornerRadius: 5))
        }
    }

    private var chooseStrip: some View {
        Text("CHOOSE")
            .font(GoalRushTheme.Typography.subheadlineEmphasized)
            .foregroundStyle(presentation.effect.accent)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(GoalRushTheme.ink)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(presentation.effect.accent)
                    .frame(height: 2)
            }
            .clipShape(
                .rect(
                    bottomLeadingRadius: 10,
                    bottomTrailingRadius: 10
                )
            )
    }

    private var usesPortraitDeck: Bool {
        !dynamicTypeSize.isAccessibilitySize
    }

    private var rankLabel: String {
        RunUpgradePresentation.rankLabel(forCurrentRank: currentRank)
    }

    private var accessibilityLabel: String {
        let chance = if let current = presentation.effect.chanceCurrent,
                        let next = presentation.effect.chanceNext {
            " Chance per ball changes from \(current) to \(next)."
        } else {
            ""
        }
        return "\(presentation.title), \(accessibilityRankLabel). \(presentation.benefit)\(chance) \(presentation.effect.metric) changes from \(presentation.effect.current) to \(presentation.effect.next)."
    }

    private var accessibilityRankLabel: String {
        currentRank == 0
            ? "New, rank 1"
            : "Rank \(GameNumberFormatter.exact(currentRank)) to \(GameNumberFormatter.exact(currentRank + 1))"
    }
}
