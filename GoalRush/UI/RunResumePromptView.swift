import SwiftUI

struct RunResumePromptView: View {
    let checkpoint: RunCheckpoint
    let isStartingOver: Bool
    let continueRun: () -> Void
    let startOver: () -> Void

    var body: some View {
        ZStack {
            background

            VStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 58, weight: .black))
                    .foregroundStyle(world.accentColor)
                    .accessibilityHidden(true)

                VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                    Text("RUN RECOVERED")
                        .font(GoalRushTheme.Typography.title)
                        .multilineTextAlignment(.center)

                    Text(runName)
                        .font(GoalRushTheme.Typography.headline)
                        .foregroundStyle(world.accentColor)

                    Text(
                        "Continue from the start of Wave \(GameNumberFormatter.compact(checkpoint.wave)), or begin a new run."
                    )
                        .font(GoalRushTheme.Typography.body)
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                    metric(
                        title: "CHECKPOINT",
                        value: "Wave \(GameNumberFormatter.compact(checkpoint.wave))",
                        accessibilityValue:
                            "Wave \(GameNumberFormatter.exact(checkpoint.wave))",
                        systemImage: "flag.checkered"
                    )
                    metric(
                        title: "BANKED",
                        value: GameNumberFormatter.compact(checkpoint.creditedRunTokens),
                        accessibilityValue:
                            GameNumberFormatter.exact(checkpoint.creditedRunTokens),
                        systemImage: "hexagon.fill"
                    )
                }

                if let relic = checkpoint.activeRelic {
                    HStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                        Image(systemName: relic.primaryStat.systemImage)
                            .font(GoalRushTheme.Typography.title2)
                            .foregroundStyle(relic.rarity.color)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            RelicRarityBadge(rarity: relic.rarity)
                            Text("\(relic.primaryStat.title) relic is locked to this run")
                                .font(GoalRushTheme.Typography.subheadline)
                                .foregroundStyle(.white.opacity(0.78))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(GoalRushTheme.Metrics.standardSpacing)
                    .background(
                        GoalRushTheme.surfaceRaised.opacity(0.90),
                        in: ComicPanelShape(cut: 8)
                    )
                    .accessibilityIdentifier("run-checkpoint-relic")
                }

                VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                    Button(action: continueRun) {
                        Label("Continue Run", systemImage: "play.fill")
                    }
                    .buttonStyle(GameLaunchButtonStyle())
                    .disabled(isStartingOver)
                    .accessibilityIdentifier("run-checkpoint-continue")
                    .accessibilityHint(
                        "Continues at the beginning of wave \(checkpoint.wave)."
                    )

                    Button("Start Over", role: .destructive, action: startOver)
                        .buttonStyle(SecondaryGameButton())
                        .disabled(isStartingOver)
                        .accessibilityIdentifier("run-checkpoint-start-over")
                        .accessibilityHint(
                            "Deletes this run checkpoint. Previously banked tokens remain."
                        )
                }
            }
            .padding(GoalRushTheme.Metrics.sectionSpacing)
            .gameSurface(.modal)
            .frame(maxWidth: 380)
            .padding(24)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("run-checkpoint-offer")
        }
    }

    private var world: WorldID {
        checkpoint.simulation.snapshot.world
    }

    private var runName: String {
        switch checkpoint.mode {
        case .campaign(let level):
            checkpoint.campaignCycle > 0
                ? "NG+\(checkpoint.campaignCycle) · Level \(level) · \(GameContent.world(world).name)"
                : "Level \(level) · \(GameContent.world(world).name)"
        case .endless:
            "Endless · \(GameContent.world(world).name)"
        }
    }

    private var background: some View {
        ZStack {
            GoalRushTheme.navy
            RadialGradient(
                colors: [
                    world.accentColor.opacity(0.22),
                    GoalRushTheme.navy.opacity(0),
                ],
                center: .top,
                startRadius: 30,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
    }

    private func metric(
        title: String,
        value: String,
        accessibilityValue: String,
        systemImage: String
    ) -> some View {
        VStack(spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(GoalRushTheme.Typography.captionEmphasized)
                .foregroundStyle(.white.opacity(0.62))
            Text(value)
                .font(GoalRushTheme.Typography.metric(size: 24))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(accessibilityValue)")
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(
            GoalRushTheme.surfaceRaised.opacity(0.90),
            in: ComicPanelShape(cut: 8)
        )
        .overlay {
            ComicPanelShape(cut: 8)
                .stroke(world.accentColor.opacity(0.42), lineWidth: 1.5)
        }
    }
}
