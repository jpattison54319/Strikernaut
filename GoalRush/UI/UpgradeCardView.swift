import SwiftUI

struct UpgradeCardView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var justPurchased = false
    @State private var flashTask: Task<Void, Never>?
    @State private var badgeTask: Task<Void, Never>?
    @State private var badgeSlamTier: UpgradePrestigeTier?
    @State private var badgeSlamSettled = false
    let track: UpgradeTrack

    var body: some View {
        let rank = store.progress.rank(for: track)
        let prestigeCount = store.progress.prestigeCount(for: track)
        let isPrestigePurchase = UpgradePrestigeRules.requiresPrestige(
            level: rank,
            prestigeCount: prestigeCount
        )
        let progressSegment = UpgradePrestigeRules.segment(level: rank, prestigeCount: prestigeCount)
        let earnedTier = UpgradePrestigeRules.currentTier(prestigeCount: prestigeCount)
        let localLevel = UpgradePrestigeRules.localLevel(level: rank, prestigeCount: prestigeCount)
        let displayedLevel = earnedTier.map {
            "\($0.title.uppercased()) \(localLevel)"
        } ?? "LEVEL \(localLevel)"
        let accessibleLevel = earnedTier.map {
            "\($0.title) level \(localLevel)"
        } ?? "Level \(localLevel)"
        let cost = UpgradePrestigeRules.purchaseCost(
            level: rank,
            prestigeCount: prestigeCount
        )
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
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 8) {
                        if let earnedTier {
                            UpgradePrestigeBadge(tier: earnedTier, compact: true)
                        }

                        Text(displayedLevel)
                            .font(GoalRushTheme.Typography.metric(size: 25, relativeTo: .title3))
                            .foregroundStyle(accent)
                            .monospacedDigit()
                            .accessibilityLabel(accessibleLevel)
                            .accessibilityIdentifier("upgrade-rank-\(track.rawValue)")

                        if let nextTier = UpgradePrestigeRules.nextTier(prestigeCount: prestigeCount) {
                            Text(isPrestigePurchase ? "\(nextTier.title.uppercased()) READY" : "TO \(nextTier.title.uppercased())")
                                .font(GoalRushTheme.Typography.metric(size: 10, relativeTo: .caption2))
                                .foregroundStyle(isPrestigePurchase ? nextTier.badgeColor : .white.opacity(0.55))
                        }
                    }

                    if progressSegment.total > 0 {
                        UpgradeLevelPips(
                            filledCount: progressSegment.filled,
                            totalCount: progressSegment.total,
                            accent: accent,
                            rangeStart: progressSegment.start,
                            rangeEnd: progressSegment.end
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: purchase) {
                    Label {
                        Text(buttonTitle(
                            affordable: affordable,
                            cost: cost,
                            isPrestige: isPrestigePurchase
                        ))
                            .monospacedDigit()
                    } icon: {
                        if !affordable {
                            Image(systemName: "lock.fill")
                        } else if isPrestigePurchase {
                            Image(systemName: "medal.fill")
                        } else {
                            TrainingTokenIcon(size: 20)
                        }
                    }
                }
                .buttonStyle(UpgradePurchaseButtonStyle(accent: accent))
                .disabled(!affordable)
                .accessibilityLabel(
                    "\(isPrestigePurchase ? "Prestige" : "Upgrade") \(UpgradeRules.title(for: track)) for \(cost) Training Tokens"
                )
                .accessibilityValue(affordable ? "Available" : "Not enough Training Tokens")
                .accessibilityIdentifier("upgrade-purchase-\(track.rawValue)")
            }

            if !isPrestigePurchase {
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
        .overlay {
            if let badgeSlamTier {
                UpgradePrestigeBadge(tier: badgeSlamTier, compact: false)
                    .scaleEffect(badgeSlamSettled ? 0.92 : 2)
                    .rotationEffect(.degrees(badgeSlamSettled ? 0 : -10))
                    .opacity(badgeSlamSettled ? 1 : 0)
                    .shadow(color: badgeSlamTier.badgeColor.opacity(0.8), radius: 16)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .animation(reduceMotion || store.settings.reducedFlashes ? nil : .snappy, value: rank)
        .animation(reduceMotion || store.settings.reducedFlashes ? nil : .easeOut(duration: 0.35), value: justPurchased)
        .onDisappear {
            flashTask?.cancel()
            badgeTask?.cancel()
            justPurchased = false
            badgeSlamTier = nil
        }
    }

    private func purchase() {
        let previousPrestigeCount = store.progress.prestigeCount(for: track)
        if store.purchase(track) {
            store.uiAudio.play(.purchase)
            let newPrestigeCount = store.progress.prestigeCount(for: track)
            if newPrestigeCount > previousPrestigeCount,
               let tier = UpgradePrestigeTier(rawValue: newPrestigeCount),
               !reduceMotion,
               !store.settings.reducedFlashes {
                badgeTask?.cancel()
                badgeSlamTier = tier
                badgeSlamSettled = false
                badgeTask = Task { @MainActor in
                    await Task.yield()
                    withAnimation(.spring(duration: 0.42, bounce: 0.48)) {
                        badgeSlamSettled = true
                    }
                    try? await Task.sleep(for: .milliseconds(900))
                    badgeSlamTier = nil
                }
            }
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

    private func buttonTitle(affordable: Bool, cost: Int, isPrestige: Bool) -> String {
        if isPrestige { return "Prestige" }
        guard affordable else { return "Need \(GameNumberFormatter.compact(cost))" }
        return GameNumberFormatter.compact(cost)
    }
}

private struct UpgradeLevelPips: View {
    let filledCount: Int
    let totalCount: Int
    let accent: Color
    let rangeStart: Int
    let rangeEnd: Int?

    var body: some View {
        Canvas { context, size in
            let rows = totalCount > 10 ? 2 : 1
            let columns = Int(ceil(Double(totalCount) / Double(rows)))
            let spec = markerSpec(for: totalCount)
            let nominalWidth =
                (CGFloat(columns) * spec.diameter)
                + (CGFloat(max(0, columns - 1)) * spec.spacing)
            let scale = min(1, size.width / max(1, nominalWidth))
            let diameter = spec.diameter * scale
            let spacing = spec.spacing * scale
            let contentHeight =
                (CGFloat(rows) * diameter)
                + (CGFloat(max(0, rows - 1)) * spacing)
            let originY = max(0, (size.height - contentHeight) / 2)

            for index in 0..<totalCount {
                let row = index / columns
                let column = index % columns
                let rect = CGRect(
                    x: CGFloat(column) * (diameter + spacing),
                    y: originY + CGFloat(row) * (diameter + spacing),
                    width: diameter,
                    height: diameter
                )
                let path = Path(ellipseIn: rect)
                let isFilled = index < filledCount
                context.fill(
                    path,
                    with: .color(isFilled ? accent : .white.opacity(0.10))
                )
                context.stroke(
                    path,
                    with: .color(isFilled ? .white.opacity(0.58) : .white.opacity(0.24)),
                    lineWidth: max(0.45, diameter * 0.10)
                )
            }
        }
        .frame(height: totalCount > 10 ? 22 : 13)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            rangeEnd.map {
                "\(filledCount) of \(totalCount) levels complete from global level \(rangeStart) toward the badge at level \($0)"
            } ?? "\(filledCount) of \(totalCount) badge levels complete"
        )
    }

    private func markerSpec(for count: Int) -> (diameter: CGFloat, spacing: CGFloat) {
        switch count {
        case ...10: (11, 5)
        case ...20: (9, 4)
        case ...30: (7, 3)
        case ...50: (4.5, 2.5)
        default: (2.75, 1.5)
        }
    }
}

private struct UpgradePrestigeBadge: View {
    let tier: UpgradePrestigeTier
    let compact: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.92), tier.badgeColor, tier.badgeColor.opacity(0.58)],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: compact ? 18 : 40
                    )
                )
            Circle()
                .stroke(GoalRushTheme.ink, lineWidth: compact ? 1.5 : 4)
            Image(systemName: "star.fill")
                .font(.system(size: compact ? 9 : 24, weight: .black))
                .foregroundStyle(GoalRushTheme.navy)
        }
        .frame(width: compact ? 24 : 78, height: compact ? 24 : 78)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tier.title) prestige badge")
        .accessibilityIdentifier("upgrade-prestige-\(tier.title.lowercased())")
        .overlay(alignment: .bottom) {
            if !compact {
                Text(tier.title.uppercased())
                    .font(GoalRushTheme.Typography.metric(size: 12, relativeTo: .caption))
                    .foregroundStyle(GoalRushTheme.navy)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(tier.badgeColor, in: Capsule())
                    .overlay { Capsule().stroke(GoalRushTheme.ink, lineWidth: 2) }
                    .offset(y: 11)
            }
        }
    }
}

private extension UpgradePrestigeTier {
    var badgeColor: Color {
        switch self {
        case .bronze: Color(red: 0.72, green: 0.38, blue: 0.16)
        case .silver: Color(red: 0.78, green: 0.84, blue: 0.90)
        case .gold: GoalRushTheme.gold
        case .platinum: Color(red: 0.55, green: 0.88, blue: 0.94)
        case .diamond: Color(red: 0.50, green: 0.82, blue: 1)
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
