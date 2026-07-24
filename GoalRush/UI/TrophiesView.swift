import SwiftUI

struct TrophiesView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedCategory: ProgressCategory?
    @State private var showingOverview = false

    var body: some View {
        AtmosphericGameScreen(backgroundImage: "MenuHero") {
            VStack(spacing: 0) {
                GameDestinationBar(
                    title: "Progress",
                    trailingText: "Overview",
                    onHome: goHome,
                    onInfo: showOverview
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.sectionSpacing) {
                        completionSummary
                        nextMilestone
                        categoryGrid
                    }
                    .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
                    .padding(.vertical, GoalRushTheme.Metrics.sectionSpacing)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .sheet(item: $selectedCategory) { category in
            ProgressCategorySheet(category: category)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingOverview) {
            GameSheetScaffold(title: "Progress", subtitle: "Your journey across every Strikernaut mode.") {
                Text("Open a category to review milestones, lifetime totals, or unlocked characters.")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(GoalRushTheme.Metrics.standardSpacing)
                    .gameSurface(.panel)
            }
            .presentationDetents([.medium])
        }
    }

    private var completionSummary: some View {
        let unlocked = store.progress.unlockedAchievements.count
        let total = AchievementID.allCases.count

        return VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.compactSpacing) {
            HStack {
                Label("MILESTONE COMPLETION", systemImage: "trophy.fill")
                    .font(.caption.bold())
                    .foregroundStyle(GoalRushTheme.gold)
                Spacer(minLength: 8)
                Text("\(unlocked)/\(total)")
                    .font(.headline.bold().monospacedDigit())
                    .foregroundStyle(.white)
            }
            ProgressView(value: Double(unlocked), total: Double(total))
                .tint(GoalRushTheme.gold)
                .scaleEffect(y: 1.35)
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .gameSurface(.hud)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(unlocked) of \(total) milestones complete")
    }

    @ViewBuilder
    private var nextMilestone: some View {
        if let next = AchievementCatalog.ordered.first(where: { !store.progress.unlockedAchievements.contains($0) }) {
            VStack(alignment: .leading, spacing: 4) {
                Text("NEXT MILESTONE")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.68))
                Text(AchievementCatalog.title(for: next))
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.white)
                Text(AchievementCatalog.subtitle(for: next))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.76))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(GoalRushTheme.Metrics.standardSpacing)
            .gameSurface(.panel)
            .accessibilityElement(children: .combine)
        } else {
            Label("Every milestone complete", systemImage: "checkmark.seal.fill")
                .font(.headline.bold())
                .foregroundStyle(GoalRushTheme.positive)
                .frame(maxWidth: .infinity, minHeight: 56)
                .gameSurface(.panel)
        }
    }

    private var categoryGrid: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
                    categoryButtons
                }
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: GoalRushTheme.Metrics.sectionSpacing
                ) {
                    categoryButtons
                }
            }
        }
    }

    @ViewBuilder
    private var categoryButtons: some View {
            ForEach(ProgressCategory.allCases) { category in
                FloatingGameActionButton(
                    title: category.title,
                    subtitle: category.subtitle,
                    systemImage: category.icon,
                    accent: category.accent
                ) {
                    store.uiAudio.play(.tap)
                    selectedCategory = category
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .accessibilityIdentifier("progress-\(category.rawValue)")
            }
    }

    private func goHome() {
        store.uiAudio.play(.tap)
        store.route = .home
    }

    private func showOverview() {
        store.uiAudio.play(.tap)
        showingOverview = true
    }
}
