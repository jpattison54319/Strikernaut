import SwiftUI

struct RelicRevealSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let relic: EndlessRelic
    let title: String

    @State private var stage = RelicDropRevealStage.incoming
    @State private var energyTurns = false
    @State private var confirmsScrap = false
    @AccessibilityFocusState private var isRelicNameFocused: Bool

    var body: some View {
        AtmosphericGameScreen(backgroundImage: "EndlessHub") {
            ZStack {
                GoalRushTheme.ink.opacity(0.76)
                    .ignoresSafeArea()

                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityLabel("Forged relic reveal")
                    .accessibilityIdentifier("forge-relic-reveal")

                RelicDropEnergyField(
                    color: relic.rarity.color,
                    stage: stage,
                    isTurning: energyTurns,
                    flashesAllowed: !store.settings.reducedFlashes
                )
                .accessibilityHidden(true)

                VStack(spacing: 0) {
                    revealHeader

                    ScrollView {
                        VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                            revealTitle

                            RelicDropCore(relic: relic, stage: stage)
                                .frame(width: 210, height: 210)

                            if stage == .revealed {
                                rewardDetails

                                RelicComparisonRows(
                                    candidate: relic,
                                    equipped: nil
                                )
                                .padding(GoalRushTheme.Metrics.standardSpacing)
                                .gameSurface(.panel)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            } else {
                                ProgressView()
                                    .tint(GoalRushTheme.cyan)
                                    .controlSize(.large)
                                    .frame(height: 54)
                                    .accessibilityLabel("Forging relic")
                                    .accessibilityIdentifier("forge-reveal-progress")
                            }
                        }
                        .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
                        .padding(.bottom, GoalRushTheme.Metrics.sectionSpacing)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if stage == .revealed {
                    actionBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .task(id: relic.id) {
            await playReveal()
        }
        .interactiveDismissDisabled(stage != .revealed)
        .confirmationDialog(
            "Scrap this new relic?",
            isPresented: $confirmsScrap,
            titleVisibility: .visible
        ) {
            Button(
                "Scrap for \(relic.scrapValue)",
                role: .destructive,
                action: scrap
            )
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Scrapping permanently removes this relic.")
        }
    }

    private var revealHeader: some View {
        HStack {
            Spacer()
            if stage != .revealed {
                Button("Skip", action: revealImmediately)
                    .font(GoalRushTheme.Typography.subheadlineEmphasized)
                    .foregroundStyle(.white.opacity(0.84))
                    .frame(minWidth: 56, minHeight: 44)
                    .contentShape(.rect)
                    .accessibilityIdentifier("forge-reveal-skip")
            } else {
                Color.clear
                    .frame(width: 56, height: 44)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
    }

    private var revealTitle: some View {
        VStack(spacing: 4) {
            Text(stage == .revealed ? title.uppercased() : "FORGING RELIC")
                .font(GoalRushTheme.Typography.display)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(stage == .revealed ? relic.rarity.title.uppercased() : "DECODING")
                .font(GoalRushTheme.Typography.captionEmphasized)
                .tracking(2.2)
                .foregroundStyle(
                    stage == .revealed
                        ? relic.rarity.color
                        : GoalRushTheme.cyan
                )
        }
    }

    private var rewardDetails: some View {
        VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
            Text(relic.name)
                .font(GoalRushTheme.Typography.title)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .accessibilityFocused($isRelicNameFocused)
                .accessibilityIdentifier("forge-reveal-name")

            RelicCompactEffectGrid(
                affixes: relic.affixes,
                color: relic.rarity.color
            )
            .frame(maxWidth: 270)
        }
        .padding(.horizontal, GoalRushTheme.Metrics.standardSpacing)
        .padding(.vertical, GoalRushTheme.Metrics.compactSpacing)
        .transition(.scale(scale: 0.88).combined(with: .opacity))
    }

    private var actionBar: some View {
        VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            Button("Equip Now", systemImage: "checkmark.circle.fill", action: equip)
                .buttonStyle(PrimaryGameButton())
                .accessibilityIdentifier("relic-reveal-equip")

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                    keepAndScrapButtons
                }
            } else {
                HStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                    keepAndScrapButtons
                }
            }
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var keepAndScrapButtons: some View {
        Button("Keep", action: keep)
            .buttonStyle(SecondaryGameButton())
            .accessibilityIdentifier("relic-reveal-keep")
        Button("Scrap", role: .destructive) {
            confirmsScrap = true
        }
        .buttonStyle(SecondaryGameButton())
        .accessibilityIdentifier("relic-reveal-scrap")
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
        withAnimation(
            reduceMotion
                ? .easeOut(duration: 0.16)
                : .spring(duration: 0.45, bounce: 0.16)
        ) {
            stage = .revealed
        }
        store.uiAudio.play(.fanfare, feedback: .success)
        isRelicNameFocused = true
    }

    private func keep() {
        store.uiAudio.play(.tap)
        dismiss()
    }

    private func equip() {
        store.uiAudio.play(.purchase)
        _ = store.equipRelic(relic.id)
        dismiss()
    }

    private func scrap() {
        store.uiAudio.play(.purchase)
        _ = store.scrapRelics([relic.id])
        dismiss()
    }
}
