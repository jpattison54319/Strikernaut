import SwiftUI

struct UpgradeCardView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var successFeedback = 0
    @State private var justPurchased = false
    @State private var flashTask: Task<Void, Never>?
    let track: UpgradeTrack

    var body: some View {
        let rank = store.progress.rank(for: track)
        let cost = UpgradeRules.cost(forNextRank: rank)
        let affordable = store.progress.trainingTokens >= cost
        let accent = UpgradePresentation.accent(for: track)
        let effect = UpgradePresentation.effect(for: track, rank: rank)
        let headerLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing))
            : AnyLayout(HStackLayout(alignment: .center, spacing: GoalRushTheme.Metrics.standardSpacing))
        let controlLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing))
            : AnyLayout(HStackLayout(alignment: .center, spacing: GoalRushTheme.Metrics.standardSpacing))
        let effectLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: GoalRushTheme.Metrics.compactSpacing))
            : AnyLayout(HStackLayout(alignment: .center, spacing: GoalRushTheme.Metrics.compactSpacing))

        VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
            headerLayout {
                Image(systemName: UpgradePresentation.icon(for: track))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(GoalRushTheme.navy)
                    .frame(width: 50, height: 50)
                    .background(
                        accent,
                        in: ComicPanelShape(cut: GoalRushTheme.Metrics.smallRadius)
                    )
                    .overlay {
                        ComicPanelShape(cut: GoalRushTheme.Metrics.smallRadius)
                            .stroke(GoalRushTheme.ink, lineWidth: 2)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(UpgradePresentation.systemLabel(for: track))
                        .font(GoalRushTheme.Typography.captionEmphasized)
                        .tracking(0.8)
                        .foregroundStyle(accent)
                    Text(UpgradeRules.title(for: track))
                        .font(GoalRushTheme.Typography.title3)
                        .foregroundStyle(.white)
                    Text(UpgradePresentation.benefit(for: track))
                        .font(GoalRushTheme.Typography.subheadline)
                        .foregroundStyle(.white.opacity(0.70))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider().overlay(.white.opacity(0.12))

            controlLayout {
                VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.compactSpacing) {
                    Text("RANK \(rank) • UNLIMITED")
                        .font(GoalRushTheme.Typography.metric(size: 12, relativeTo: .caption))
                        .foregroundStyle(.white.opacity(0.72))
                    UpgradeRankSockets(rank: rank, accent: accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: purchase) {
                    Label {
                        Text(affordable ? cost.formatted() : "Need \(cost.formatted())")
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: affordable ? "hexagon.fill" : "lock.fill")
                    }
                }
                .buttonStyle(UpgradePurchaseButtonStyle(accent: accent))
                .disabled(!affordable)
                .accessibilityLabel("Upgrade \(UpgradeRules.title(for: track)) for \(cost) Training Tokens")
                .accessibilityValue(affordable ? "Available" : "Not enough Training Tokens")
                .accessibilityIdentifier("upgrade-purchase-\(track.rawValue)")
            }

            effectLayout {
                Image(systemName: "arrow.up.right.circle.fill")
                    .foregroundStyle(accent)
                    .accessibilityHidden(true)
                Text("\(effect.current) → \(effect.next)")
                Text(effect.improvement)
                    .foregroundStyle(accent)
            }
            .font(GoalRushTheme.Typography.metric(size: 12, relativeTo: .caption))
            .foregroundStyle(.white.opacity(0.74))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .background {
            UpgradeModuleSurface(accent: accent)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("upgrade-\(track.rawValue)")
        .overlay {
            ComicPanelShape(cut: 11)
                .stroke(GoalRushTheme.gold, lineWidth: 2)
                .opacity(justPurchased ? 1 : 0)
        }
        .sensoryFeedback(trigger: successFeedback) { _, _ in
            store.settings.hapticsEnabled ? .success : nil
        }
        .animation(reduceMotion || store.settings.reducedFlashes ? nil : .snappy, value: rank)
        .animation(reduceMotion || store.settings.reducedFlashes ? nil : .easeOut(duration: 0.35), value: justPurchased)
        .onDisappear {
            flashTask?.cancel()
            justPurchased = false
        }
    }

    private func purchase() {
        if store.purchase(track) {
            store.uiAudio.play(.purchase)
            successFeedback += 1
            guard !reduceMotion, !store.settings.reducedFlashes else { return }
            flashTask?.cancel()
            justPurchased = true
            flashTask = Task {
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                justPurchased = false
            }
        } else {
            store.uiAudio.play(.locked, volume: 0.5)
        }
    }
}

private struct UpgradeModuleSurface: View {
    let accent: Color

    var body: some View {
        ZStack {
            GoalRushTheme.surfaceRaised.opacity(0.985)
            ComicInkTexture(opacity: 0.10)

            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 154))
                .foregroundStyle(.white.opacity(0.026))
                .offset(x: 118, y: 54)

            VStack {
                LinearGradient(
                    colors: [accent.opacity(0.88), accent.opacity(0.08), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 4)
                Spacer(minLength: 0)
            }

            HStack {
                WorkshopBolt()
                Spacer(minLength: 0)
                WorkshopBolt()
            }
            .padding(GoalRushTheme.Metrics.compactSpacing)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .clipShape(ComicPanelShape(cut: 11))
        .background {
            ComicPanelShape(cut: 11)
                .fill(GoalRushTheme.ink)
                .offset(x: 5, y: 6)
        }
        .overlay {
            ComicPanelShape(cut: 11)
                .stroke(accent.opacity(0.58), lineWidth: GoalRushTheme.Metrics.strokeWidth)
        }
    }
}

private struct WorkshopBolt: View {
    var body: some View {
        Circle()
            .fill(.white.opacity(0.18))
            .frame(width: 6, height: 6)
            .overlay {
                Rectangle()
                    .fill(GoalRushTheme.navy.opacity(0.72))
                    .frame(width: 4, height: 1)
            }
            .accessibilityHidden(true)
    }
}

private struct UpgradeRankSockets: View {
    let rank: Int
    let accent: Color

    var body: some View {
        HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
            ForEach(0..<UpgradeRules.masteryRank, id: \.self) { index in
                ZStack {
                    Circle()
                        .fill(socketFill(index: index))
                    Circle()
                        .stroke(socketStroke(index: index), lineWidth: index == rank ? 2 : 1)
                    Image(systemName: rank > UpgradeRules.masteryRank && index == UpgradeRules.masteryRank - 1
                        ? "infinity"
                        : socketIcon(index: index))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(socketIconColor(index: index))
                }
                .frame(width: 26, height: 26)
                .shadow(color: index < rank ? accent.opacity(0.26) : .clear, radius: 5)
            }
        }
        .frame(minHeight: GoalRushTheme.Metrics.minimumTapTarget, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Purchased upgrades")
        .accessibilityValue("Rank \(rank), unlimited")
    }

    private func socketFill(index: Int) -> Color {
        if index < rank { return accent }
        if index == rank { return accent.opacity(0.12) }
        return .black.opacity(0.24)
    }

    private func socketStroke(index: Int) -> Color {
        if index <= rank { return accent.opacity(0.84) }
        return .white.opacity(0.22)
    }

    private func socketIcon(index: Int) -> String {
        if index < rank { return "checkmark" }
        if index == rank { return "plus" }
        return "circle.fill"
    }

    private func socketIconColor(index: Int) -> Color {
        if index < rank { return GoalRushTheme.navy }
        if index == rank { return accent }
        return .white.opacity(0.16)
    }
}

private struct UpgradePurchaseButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(GoalRushTheme.Typography.subheadlineEmphasized)
            .foregroundStyle(isEnabled ? GoalRushTheme.navy : .white.opacity(0.78))
            .padding(.horizontal, 13)
            .frame(minHeight: GoalRushTheme.Metrics.minimumTapTarget)
            .background(buttonFill, in: ComicPanelShape(cut: 7))
            .overlay {
                ComicPanelShape(cut: 7)
                    .stroke(isEnabled ? .white.opacity(0.34) : accent.opacity(0.46))
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: configuration.isPressed)
    }

    private var buttonFill: AnyShapeStyle {
        if isEnabled {
            return AnyShapeStyle(accent)
        }
        return AnyShapeStyle(GoalRushTheme.navy.opacity(0.88))
    }
}
