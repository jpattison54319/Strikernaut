import SwiftUI

struct AbilityDraftView: View {
    let choices: [RunUpgradeChoice]
    let session: GameSessionModel

    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.84)
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    GoalRushTheme.blue.opacity(0.34),
                    GoalRushTheme.navy.opacity(0.12),
                    .clear,
                ],
                center: .center,
                startRadius: 12,
                endRadius: 360
            )
            .ignoresSafeArea()
            .accessibilityHidden(true)

            ScrollView {
                VStack(spacing: 14) {
                    AbilityDraftHeader(
                        eyebrow: headerEyebrow,
                        title: headerTitle,
                        scope: headerScope
                    )

                    choiceLayout
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear(perform: playEntrance)
    }

    @ViewBuilder
    private var choiceLayout: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 18) {
                choiceCards
            }
        } else {
            HStack(alignment: .top, spacing: 7) {
                choiceCards
            }
            .padding(.horizontal, 2)
        }
    }

    @ViewBuilder
    private var choiceCards: some View {
        ForEach(Array(choices.enumerated()), id: \.element) { index, choice in
            choiceButton(choice, index: index)
        }
    }

    private func choiceButton(
        _ choice: RunUpgradeChoice,
        index: Int
    ) -> some View {
        let currentRank = rank(for: choice)
        let presentation = presentation(for: choice, currentRank: currentRank)

        return AbilityChoiceCard(
            presentation: presentation,
            currentRank: currentRank,
            selectionHint: selectionHint,
            identifier: "ability-\(choice.id)",
            choose: { choose(choice) }
        )
        .shimmer(
            active: session.mode.isEndless
                && currentRank >= 5
                && !reduceMotion
                && !store.settings.reducedFlashes
        )
        .rotationEffect(
            dynamicTypeSize.isAccessibilitySize
                ? .zero
                : .degrees(cardTilt(at: index))
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 26)
        .animation(
            reduceMotion
                ? nil
                : .snappy(duration: 0.34)
                    .delay(Double(index) * 0.09),
            value: appeared
        )
    }

    private var headerEyebrow: String {
        if session.isStarterDraft { return "ENDLESS RUN" }
        if session.mode.isEndless {
            return "ENDLESS • WAVE \(GameNumberFormatter.compact(session.snapshot.wave))"
        }
        return "WAVE \(session.snapshot.wave) OF \(session.snapshot.waveCount)"
    }

    private var headerTitle: String {
        session.isStarterDraft ? "PICK YOUR FIRST POWER" : "PICK A POWER"
    }

    private var headerScope: String {
        session.mode.isEndless
            ? "EFFECTS CAN STACK • NO RANK CAP"
            : "LASTS THIS LEVEL"
    }

    private var selectionHint: String {
        session.mode.isEndless
            ? "Applies for the rest of this endless run"
            : "Applies for the rest of this level"
    }

    private func rank(for choice: RunUpgradeChoice) -> Int {
        switch choice {
        case .ability(let ability):
            session.simulation.abilityRank(ability)
        case .specialBall(let ability):
            session.simulation.specialBallRank(ability)
        }
    }

    private func presentation(
        for choice: RunUpgradeChoice,
        currentRank: Int
    ) -> RunUpgradePresentation {
        switch choice {
        case .ability(let ability):
            return .init(
                title: AbilityPresentation.title(ability),
                artAsset: AbilityPresentation.artAsset(ability),
                benefit: AbilityPresentation.benefit(ability),
                effect: AbilityPresentation.effect(
                    for: ability,
                    currentRank: currentRank,
                    isEndless: session.mode.isEndless,
                    baseKickInterval: session.simulation.kickInterval(atAbilityRank: 0)
                )
            )
        case .specialBall(let ability):
            return SpecialBallPresentation.presentation(
                for: ability,
                currentRank: currentRank
            )
        }
    }

    private func cardTilt(at index: Int) -> Double {
        [-1.2, 0.8, -0.6][index % 3]
    }

    private func choose(_ choice: RunUpgradeChoice) {
        store.uiAudio.requestFeedback(.impact)
        session.choose(choice)
    }

    private func playEntrance() {
        appeared = true
        store.uiAudio.play(.draft, volume: 0.6, feedback: nil)
    }
}
