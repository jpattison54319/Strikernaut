import SwiftUI

struct TrophiesView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(AchievementCatalog.ordered, id: \.self) { id in
                        trophyRow(id)
                    }
                }
                .padding()
            }
            .background(
                LinearGradient(colors: [GoalRushTheme.navy, GoalRushTheme.gold.opacity(0.10), GoalRushTheme.navy],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .navigationTitle("Trophies")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Home", systemImage: "chevron.left") { store.route = .home }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(store.progress.unlockedAchievements.count)/\(AchievementID.allCases.count)")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(GoalRushTheme.gold)
                }
            }
        }
    }

    private func trophyRow(_ id: AchievementID) -> some View {
        let unlocked = store.progress.unlockedAchievements.contains(id)
        return HStack(spacing: 13) {
            Image(systemName: AchievementCatalog.icon(for: id))
                .font(.title3.bold())
                .foregroundStyle(unlocked ? GoalRushTheme.navy : .secondary)
                .frame(width: 44, height: 44)
                .background(unlocked ? GoalRushTheme.gold : .white.opacity(0.08), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(AchievementCatalog.title(for: id))
                    .font(.headline)
                    .foregroundStyle(unlocked ? .white : .secondary)
                Text(AchievementCatalog.subtitle(for: id))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if unlocked {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(GoalRushTheme.gold)
            } else {
                Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.white.opacity(unlocked ? 0.09 : 0.04), in: .rect(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(unlocked ? GoalRushTheme.gold.opacity(0.35) : .white.opacity(0.08)) }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("trophy-\(id.rawValue)")
    }
}
