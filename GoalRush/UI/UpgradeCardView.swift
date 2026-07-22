import SwiftUI

struct UpgradeCardView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var successFeedback = 0
    @State private var justPurchased = false
    @State private var flashTask: Task<Void, Never>?
    let track: UpgradeTrack

    var body: some View {
        let rank = store.progress.rank(for: track)
        let maximum = rank == UpgradeRules.maxRank
        let cost = UpgradeRules.cost(forNextRank: rank)
        let affordable = store.progress.trainingTokens >= cost
        let effect = UpgradePresentation.effect(for: track, rank: rank)

        GameCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 13) {
                    Image(systemName: UpgradePresentation.icon(for: track))
                        .font(.title2.bold())
                        .foregroundStyle(GoalRushTheme.navy)
                        .frame(width: 48, height: 48)
                        .background(
                            LinearGradient(colors: [GoalRushTheme.gold, GoalRushTheme.orange], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: .rect(cornerRadius: 14)
                        )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(UpgradeRules.title(for: track)).font(.headline)
                        Text(UpgradePresentation.benefit(for: track))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                RankPips(rank: rank)

                VStack(alignment: .leading, spacing: 7) {
                    Text(effect.metric.uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Text(effect.current).font(.title3.bold()).monospacedDigit()
                        Image(systemName: maximum ? "checkmark.circle.fill" : "arrow.right")
                            .foregroundStyle(maximum ? GoalRushTheme.positive : GoalRushTheme.gold)
                        Text(maximum ? "MAX" : effect.next)
                            .font(.title3.bold())
                            .foregroundStyle(maximum ? GoalRushTheme.positive : .white)
                            .monospacedDigit()
                        Spacer()
                        if !maximum {
                            Text(effect.improvement)
                                .font(.caption.bold())
                                .foregroundStyle(GoalRushTheme.positive)
                        }
                    }
                }
                .padding(12)
                .background(.black.opacity(0.22), in: .rect(cornerRadius: 14))

                if maximum {
                    Label("MAX", systemImage: "seal.fill")
                        .font(.headline)
                        .foregroundStyle(GoalRushTheme.gold)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(GoalRushTheme.gold.opacity(0.14), in: .rect(cornerRadius: 18))
                        .overlay { RoundedRectangle(cornerRadius: 18).stroke(GoalRushTheme.gold.opacity(0.45)) }
                } else {
                    if affordable {
                        Text("READY")
                            .font(.caption.bold())
                            .tracking(1.1)
                            .foregroundStyle(GoalRushTheme.navy)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(GoalRushTheme.gold, in: .capsule)
                    }
                    Button("Upgrade for \(cost) Tokens", systemImage: "arrow.up.circle.fill", action: purchase)
                        .buttonStyle(PrimaryGameButton())
                        .disabled(!affordable)
                        .accessibilityIdentifier("upgrade-\(track.rawValue)")

                    if !affordable {
                        ProgressView(value: min(1, Double(store.progress.trainingTokens) / Double(cost))) {
                            Label("\(store.progress.trainingTokens)/\(cost)", systemImage: "lock.fill")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .tint(GoalRushTheme.gold)
                    }
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(GoalRushTheme.gold, lineWidth: 2)
                .opacity(justPurchased ? 1 : 0)
        }
        .pulseGlow(affordable && !maximum, color: GoalRushTheme.gold)
        .sensoryFeedback(trigger: successFeedback) { _, _ in
            store.settings.hapticsEnabled ? .success : nil
        }
        .animation(reduceMotion ? nil : .snappy, value: rank)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: justPurchased)
    }

    private func purchase() {
        if store.purchase(track) {
            store.uiAudio.play(.purchase)
            successFeedback += 1
            guard !reduceMotion else { return }
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

private struct RankPips: View {
    let rank: Int

    var body: some View {
        HStack(spacing: 6) {
            Text("RANK \(rank) OF \(UpgradeRules.maxRank)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            ForEach(0..<UpgradeRules.maxRank, id: \.self) { index in
                Capsule()
                    .fill(index < rank ? GoalRushTheme.gold : .white.opacity(0.13))
                    .frame(maxWidth: .infinity, minHeight: 6, maxHeight: 6)
            }
        }
    }
}
