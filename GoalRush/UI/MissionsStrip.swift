import SwiftUI

struct MissionsStrip: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Daily Missions", systemImage: "target")
                .font(.headline)
            VStack(spacing: 10) {
                ForEach(store.progress.missions) { mission in
                    MissionRow(mission: mission)
                }
            }
        }
    }
}

private struct MissionRow: View {
    @Environment(GameStore.self) private var store
    let mission: MissionState

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: mission.fraction)
                    .stroke(mission.isComplete ? GoalRushTheme.positive : GoalRushTheme.cyan,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: MissionCatalog.icon(for: mission.kind))
                    .font(.caption.bold())
                    .foregroundStyle(mission.isComplete ? GoalRushTheme.positive : .white)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(MissionCatalog.title(for: mission.kind))
                    .font(.subheadline.bold())
                Text(MissionCatalog.goalText(for: mission.kind, goal: mission.goal))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)

            if mission.claimed {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(GoalRushTheme.positive)
            } else if mission.isComplete {
                Button("+\(mission.reward)") {
                    store.uiAudio.play(.purchase)
                    _ = store.claimMission(mission.kind)
                }
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(GoalRushTheme.navy)
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .background(GoalRushTheme.gold, in: .capsule)
                .pulseGlow(true)
                .accessibilityIdentifier("mission-claim-\(mission.kind.rawValue)")
            } else {
                Text("\(min(mission.progress, mission.goal))/\(mission.goal)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.10)) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mission-\(mission.kind.rawValue)")
    }
}
