import SwiftUI

struct RelicDropRevealView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stage = RelicDropRevealStage.incoming
    @State private var energyTurns = false
    @AccessibilityFocusState private var isRelicNameFocused: Bool

    let result: RunResult

    var body: some View {
        AtmosphericGameScreen(backgroundImage: "EndlessHub") {
            if let relic = result.relicEarned {
                revealContent(relic)
                    .task(id: result.runID) {
                        await playReveal()
                    }
            } else {
                Color.clear
                    .task {
                        store.continueAfterRelicDrop(result)
                    }
            }
        }
    }

    private func revealContent(_ relic: EndlessRelic) -> some View {
        ZStack {
            GoalRushTheme.ink.opacity(0.72)
                .ignoresSafeArea()

            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityLabel("Relic drop reveal")
                .accessibilityIdentifier("relic-drop-reveal")

            RelicDropEnergyField(
                color: relic.rarity.color,
                stage: stage,
                isTurning: energyTurns,
                flashesAllowed: !store.settings.reducedFlashes
            )
            .accessibilityHidden(true)

            VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                skipButton

                Spacer(minLength: 8)

                VStack(spacing: 4) {
                    Text("RELIC DROP")
                        .font(GoalRushTheme.Typography.display)
                        .foregroundStyle(.white)
                    Text(stage == .revealed ? relic.rarity.title.uppercased() : "DECODING")
                        .font(GoalRushTheme.Typography.captionEmphasized)
                        .tracking(2.2)
                        .foregroundStyle(
                            stage == .revealed
                                ? relic.rarity.color
                                : GoalRushTheme.cyan
                        )
                    if stage == .revealed, relic.newGamePlusCycle > 0 {
                        GameStatusBadge(
                            text: "NG+\(relic.newGamePlusCycle)",
                            tone: .info
                        )
                        .accessibilityLabel(
                            "New Game Plus \(relic.newGamePlusCycle) boosted relic"
                        )
                    }
                }

                Spacer(minLength: 4)

                RelicDropCore(relic: relic, stage: stage)
                    .frame(width: 220, height: 220)

                revealedDetails(relic)

                Spacer(minLength: 8)

                revealAction
            }
            .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
            .padding(.vertical, GoalRushTheme.Metrics.standardSpacing)
        }
    }

    @ViewBuilder
    private var skipButton: some View {
        HStack {
            Spacer()
            if stage != .revealed {
                Button("Skip", action: revealImmediately)
                    .font(GoalRushTheme.Typography.subheadlineEmphasized)
                    .foregroundStyle(.white.opacity(0.84))
                    .frame(minWidth: 56, minHeight: 44)
                    .contentShape(.rect)
                    .accessibilityIdentifier("relic-drop-skip")
            } else {
                Color.clear
                    .frame(width: 56, height: 44)
                    .accessibilityHidden(true)
            }
        }
    }

    private func revealedDetails(_ relic: EndlessRelic) -> some View {
        VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
            Text(relic.name)
                .font(GoalRushTheme.Typography.title)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .accessibilityFocused($isRelicNameFocused)
                .accessibilityIdentifier("relic-drop-name")

            RelicCompactEffectGrid(
                affixes: relic.affixes,
                color: relic.rarity.color
            )
            .frame(maxWidth: 270)
        }
        .padding(.horizontal, GoalRushTheme.Metrics.standardSpacing)
        .padding(.vertical, GoalRushTheme.Metrics.compactSpacing)
        .opacity(stage == .revealed ? 1 : 0)
        .scaleEffect(stage == .revealed ? 1 : 0.88)
        .accessibilityHidden(stage != .revealed)
    }

    @ViewBuilder
    private var revealAction: some View {
        if stage == .revealed {
            Button("Continue", systemImage: "arrow.right", action: continueToResult)
                .buttonStyle(PrimaryGameButton())
                .accessibilityIdentifier("relic-drop-continue")
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            ProgressView()
                .tint(GoalRushTheme.cyan)
                .controlSize(.large)
                .frame(height: 54)
                .accessibilityLabel("Revealing relic")
        }
    }

    private func playReveal() async {
        guard stage == .incoming else { return }
        if reduceMotion {
            revealImmediately()
            return
        }

        store.uiAudio.play(.whoosh)
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            energyTurns = true
        }

        do {
            try await Task.sleep(for: .milliseconds(720))
        } catch {
            return
        }
        guard stage == .incoming else { return }

        withAnimation(.easeIn(duration: 0.16)) {
            stage = .impact
        }
        store.uiAudio.play(.claim, feedback: .impact)

        do {
            try await Task.sleep(for: .milliseconds(220))
        } catch {
            return
        }
        guard stage == .impact else { return }

        withAnimation(.spring(duration: 0.72, bounce: 0.24)) {
            stage = .revealed
        }
        store.uiAudio.play(.fanfare, feedback: .success)
        isRelicNameFocused = true
    }

    private func revealImmediately() {
        guard stage != .revealed else { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(duration: 0.45, bounce: 0.16)) {
            stage = .revealed
        }
        store.uiAudio.play(.fanfare, feedback: .success)
        isRelicNameFocused = true
    }

    private func continueToResult() {
        store.uiAudio.play(.tap)
        store.continueAfterRelicDrop(result)
    }
}

enum RelicDropRevealStage: Equatable {
    case incoming
    case impact
    case revealed
}
