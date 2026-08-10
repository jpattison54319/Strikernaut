import SwiftUI

struct RelicForgeView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var mode = RelicForgeMode.random
    @State private var focusedStat = EndlessRelicStat.attackDamage
    @State private var revealedRelic: EndlessRelic?

    var body: some View {
        AtmosphericGameScreen(backgroundImage: "EndlessHub") {
            VStack(spacing: 0) {
                GameDestinationBar(
                    title: "Forge",
                    trailingActionTitle: "Relics",
                    trailingActionSystemImage: "diamond.fill",
                    onHome: goHome,
                    onTrailingAction: openRelics
                )

                ScrollView {
                    VStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
                        forgeHero
                        forgeControls
                    }
                    .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
                    .padding(.vertical, GoalRushTheme.Metrics.sectionSpacing)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .fullScreenCover(item: $revealedRelic) { relic in
            RelicRevealSheet(relic: relic, title: "Forge Complete")
        }
    }

    private var record: EndlessRecord {
        store.progress.endlessRecord
    }

    private var milestone: Int? {
        EndlessRelicRules.forgeMilestone(forBestWaveReached: record.bestWave)
    }

    private var isAffordable: Bool {
        milestone != nil && record.scrap >= mode.cost
    }

    private var forgeHero: some View {
        VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            RelicMedallionView(
                systemImage: mode == .random ? "dice.fill" : focusedStat.systemImage,
                rarity: mode == .random ? .rare : .epic
            )
            .frame(width: 156, height: 156)

            Text("RELIC FORGE")
                .font(GoalRushTheme.Typography.captionEmphasized)
                .tracking(1.4)
                .foregroundStyle(GoalRushTheme.gold)

            Text("Turn Scrap into a permanent Endless relic.")
                .font(GoalRushTheme.Typography.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)

            Label(
                "\(GameNumberFormatter.compact(record.scrap)) Scrap",
                systemImage: "arrow.3.trianglepath"
            )
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .accessibilityLabel(
                    "\(GameNumberFormatter.exact(record.scrap)) Scrap"
                )
                .accessibilityIdentifier("relic-scrap-balance")
            .font(GoalRushTheme.Typography.subheadlineEmphasized)
            .foregroundStyle(.white)
            .padding(.horizontal, GoalRushTheme.Metrics.standardSpacing)
            .frame(minHeight: 44)
            .background(GoalRushTheme.surface, in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(GoalRushTheme.Metrics.sectionSpacing)
        .gameSurface(.panel)
    }

    private var forgeControls: some View {
        VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
            Text("Forge Setup")
                .font(GoalRushTheme.Typography.title2)

            Menu {
                ForEach(RelicForgeMode.allCases) { option in
                    Button {
                        store.uiAudio.play(.tap)
                        mode = option
                    } label: {
                        Label(option.title, systemImage: option.systemImage)
                    }
                }
            } label: {
                menuLabel(
                    title: "Roll Type",
                    value: mode.title,
                    systemImage: mode.systemImage
                )
            }
            .accessibilityLabel("Roll Type")
            .accessibilityValue(mode.title)
            .accessibilityIdentifier("relic-forge-mode")

            if mode == .focused {
                Menu {
                    ForEach(EndlessRelicStat.allCases) { stat in
                        Button {
                            store.uiAudio.play(.tap)
                            focusedStat = stat
                        } label: {
                            Label(stat.title, systemImage: stat.systemImage)
                        }
                    }
                } label: {
                    menuLabel(
                        title: "Primary Stat",
                        value: focusedStat.title,
                        systemImage: focusedStat.systemImage
                    )
                }
                .accessibilityLabel("Focused Primary Stat")
                .accessibilityValue(focusedStat.title)
                .accessibilityIdentifier("relic-focused-stat")
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if milestone == nil {
                Label(
                    "Clear Wave 5 in Endless to power the Forge.",
                    systemImage: "lock.fill"
                )
                .font(GoalRushTheme.Typography.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
            } else if !isAffordable {
                Label(
                    "Salvage relics to recover \(GameNumberFormatter.compact(mode.cost - record.scrap)) more Scrap.",
                    systemImage: "arrow.3.trianglepath"
                )
                .font(GoalRushTheme.Typography.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: forge) {
                Label(
                    "Forge \(mode.title) · \(mode.cost)",
                    systemImage: "hammer.fill"
                )
            }
            .buttonStyle(PrimaryGameButton())
            .disabled(!isAffordable)
            .accessibilityIdentifier("forge-relic")
            .accessibilityHint(forgeHint)

            if milestone == nil {
                Button("Start Endless", systemImage: "infinity", action: startEndless)
                    .buttonStyle(SecondaryGameButton())
                    .accessibilityIdentifier("forge-start-endless")
            }
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .gameSurface(.panel)
        .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: mode)
    }

    private func menuLabel(
        title: String,
        value: String,
        systemImage: String
    ) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: GoalRushTheme.Metrics.standardSpacing))

        return layout {
            Label(title, systemImage: systemImage)
                .font(GoalRushTheme.Typography.subheadlineEmphasized)
                .foregroundStyle(.white.opacity(0.68))

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                Text(value)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.bold())
                    .accessibilityHidden(true)
            }
            .font(GoalRushTheme.Typography.headline)
            .foregroundStyle(.white)
        }
        .padding(.horizontal, GoalRushTheme.Metrics.standardSpacing)
        .frame(
            maxWidth: .infinity,
            minHeight: dynamicTypeSize.isAccessibilitySize ? 70 : 54,
            alignment: .leading
        )
        .background(GoalRushTheme.surfaceRaised, in: ComicPanelShape(cut: 8))
        .overlay {
            ComicPanelShape(cut: 8)
                .stroke(GoalRushTheme.blue.opacity(0.72), lineWidth: 2)
        }
        .contentShape(.rect)
    }

    private var forgeHint: String {
        switch mode {
        case .random:
            "Spends \(mode.cost) Scrap and rolls a relic with a random primary stat."
        case .focused:
            "Spends \(mode.cost) Scrap and guarantees \(focusedStat.title) as the primary stat."
        }
    }

    private func forge() {
        let stat = mode == .focused ? focusedStat : nil
        guard let relic = store.forgeRelic(focusing: stat) else {
            store.uiAudio.play(.locked)
            return
        }
        store.uiAudio.play(.purchase)
        revealedRelic = relic
    }

    private func openRelics() {
        store.uiAudio.play(.tap)
        store.route = .relics
    }

    private func startEndless() {
        store.uiAudio.play(.tap)
        store.startEndless()
    }

    private func goHome() {
        store.uiAudio.play(.tap)
        store.route = .home
    }
}
