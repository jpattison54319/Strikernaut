import SwiftUI

struct MissionRow: View {
    static let minimumClaimHeight = GoalRushTheme.Metrics.minimumTapTarget

    @Environment(GameStore.self) private var store
    let mission: MissionState

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: mission.fraction)
                    .stroke(
                        mission.isComplete ? GoalRushTheme.positive : GoalRushTheme.cyan,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Image(systemName: MissionCatalog.icon(for: mission.kind))
                    .font(GoalRushTheme.Typography.captionEmphasized)
                    .foregroundStyle(mission.isComplete ? GoalRushTheme.positive : .white)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(MissionCatalog.title(for: mission.kind))
                    .font(GoalRushTheme.Typography.subheadlineEmphasized)
                Text(MissionCatalog.goalText(for: mission.kind, goal: mission.goal))
                    .font(GoalRushTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(
                        MissionCatalog.goalText(
                            for: mission.kind,
                            goal: mission.goal,
                            compactNumbers: false
                        )
                    )
            }
            Spacer(minLength: 4)

            if mission.claimed {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(GoalRushTheme.positive)
            } else if mission.isComplete {
                Button("+\(GameNumberFormatter.compact(mission.reward))", action: claimMission)
                    .font(GoalRushTheme.Typography.metric(size: 15, relativeTo: .subheadline))
                    .foregroundStyle(GoalRushTheme.navy)
                    .padding(.horizontal, 12)
                    .frame(minHeight: Self.minimumClaimHeight)
                    .background(GoalRushTheme.gold, in: ComicPanelShape(cut: 5))
                    .pulseGlow(true)
                    .accessibilityLabel(
                        "Claim \(GameNumberFormatter.exact(mission.reward)) tokens, \(MissionCatalog.title(for: mission.kind))"
                    )
                    .accessibilityIdentifier("mission-claim-\(mission.kind.rawValue)")
            } else {
                Text(
                    "\(GameNumberFormatter.compact(min(mission.progress, mission.goal)))/\(GameNumberFormatter.compact(mission.goal))"
                )
                    .font(GoalRushTheme.Typography.metric(size: 12, relativeTo: .caption))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(
                        "\(GameNumberFormatter.exact(min(mission.progress, mission.goal))) of \(GameNumberFormatter.exact(mission.goal))"
                    )
            }
        }
        .padding(12)
        .background(.white.opacity(0.06), in: ComicPanelShape(cut: 8))
        .overlay { ComicPanelShape(cut: 8).stroke(.white.opacity(0.16), lineWidth: 2) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mission-\(mission.kind.rawValue)")
    }

    private func claimMission() {
        store.uiAudio.play(.purchase)
        _ = store.claimMission(mission.kind)
    }
}
