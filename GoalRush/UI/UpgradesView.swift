import SwiftUI

struct UpgradesView: View {
    @Environment(GameStore.self) private var store
    @State private var showingInfo = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 28) {
                    ForEach(UpgradeCategory.allCases) { category in
                        VStack(alignment: .leading, spacing: 14) {
                            Label(category.rawValue, systemImage: category == .player ? "figure.run" : "soccerball")
                                .font(.title2.bold())
                            ForEach(UpgradeTrack.allCases.filter { $0.category == category }) { track in
                                UpgradeCardView(track: track)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(
                LinearGradient(colors: [GoalRushTheme.navy, Color(red: 0.03, green: 0.18, blue: 0.22)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .navigationTitle("Upgrades")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Home", systemImage: "chevron.left") { store.route = .home }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("About upgrades", systemImage: "info.circle") {
                        showingInfo = true
                    }
                    .labelStyle(.iconOnly)
                    HStack(spacing: 5) {
                        Image(systemName: "hexagon.fill")
                        Text("\(store.progress.trainingTokens)").monospacedDigit()
                    }
                        .font(.subheadline.bold())
                        .foregroundStyle(GoalRushTheme.gold)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(store.progress.trainingTokens) Training Tokens")
                }
            }
            .sheet(isPresented: $showingInfo) {
                UpgradeInfoView()
                    .presentationDetents([.medium])
            }
        }
    }
}

private struct UpgradeInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Label("Upgrades are permanent", systemImage: "checkmark.shield.fill")
                Label("Active in Campaign and Endless", systemImage: "gamecontroller.fill")
                Label("Cards show current → next", systemImage: "arrow.right")
            }
            .navigationTitle("Upgrades")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
