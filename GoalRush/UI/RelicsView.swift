import SwiftUI

struct RelicsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var statFilter: EndlessRelicStat?
    @State private var rarityFilter: EndlessRelicRarity?
    @State private var sort = RelicInventorySort.newest
    @State private var isSalvaging = false
    @State private var selectedIDs = Set<UUID>()
    @State private var salvagingIDs = Set<UUID>()
    @State private var confirmsSalvage = false
    @State private var salvageFeedback: Int?
    @State private var salvageTask: Task<Void, Never>?
    @State private var feedbackTask: Task<Void, Never>?
    @State private var hasRecoveredEndlessRun = false

    var body: some View {
        AtmosphericGameScreen(backgroundImage: "EndlessHub") {
            VStack(spacing: 0) {
                GameDestinationBar(
                    title: "Relics",
                    trailingActionTitle: "Forge",
                    trailingActionSystemImage: "hammer.fill",
                    onHome: goHome,
                    onTrailingAction: openForge
                )

                ScrollView {
                    LazyVStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
                        if hasRecoveredEndlessRun {
                            recoveredRunNotice
                        }

                        inventory
                    }
                    .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
                    .padding(.vertical, GoalRushTheme.Metrics.sectionSpacing)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isSalvaging {
                salvageActionBar
            }
        }
        .overlay {
            if let salvageFeedback {
                RelicSalvageBurst(scrap: salvageFeedback)
                    .transition(.scale(scale: 0.72).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .task {
            hasRecoveredEndlessRun =
                await store.runCheckpointStore.load(for: .endless) != nil
        }
        .onChange(of: inventoryIDs) { _, validIDs in
            selectedIDs.formIntersection(validIDs)
        }
        .onDisappear {
            salvageTask?.cancel()
            feedbackTask?.cancel()
        }
    }

    private var record: EndlessRecord {
        store.progress.endlessRecord
    }

    private var inventoryIDs: Set<UUID> {
        Set(record.relics.map(\.id))
    }

    private var displayedRelics: [EndlessRelic] {
        record.relics
            .filter { relic in
                (statFilter == nil || relic.primaryStat == statFilter)
                    && (rarityFilter == nil || relic.rarity == rarityFilter)
            }
            .sorted(by: sortRelics)
    }

    private var selectedScrapValue: Int {
        record.relics
            .filter { selectedIDs.contains($0.id) }
            .reduce(0) { $0 + $1.scrapValue }
    }

    private var selectedIncludesEquipped: Bool {
        guard let equippedID = record.equippedRelicID else { return false }
        return selectedIDs.contains(equippedID)
    }

    private var recoveredRunNotice: some View {
        Label(
            "A recovered run keeps its original relic. Changes here apply to your next run.",
            systemImage: "arrow.clockwise.circle.fill"
        )
        .font(GoalRushTheme.Typography.subheadline)
        .foregroundStyle(.white.opacity(0.82))
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GoalRushTheme.blue.opacity(0.20), in: ComicPanelShape(cut: 8))
        .overlay {
            ComicPanelShape(cut: 8)
                .stroke(GoalRushTheme.cyan.opacity(0.42), lineWidth: 1.5)
        }
        .accessibilityIdentifier("relic-recovered-run-notice")
    }

    private var inventory: some View {
        VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.standardSpacing) {
            inventoryHeader

            if !record.relics.isEmpty, !isSalvaging {
                inventoryControls
            }

            inventoryContent
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .gameSurface(.panel)
    }

    private var inventoryHeader: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(
                VStackLayout(
                    alignment: .leading,
                    spacing: GoalRushTheme.Metrics.standardSpacing
                )
            )
            : AnyLayout(
                HStackLayout(
                    alignment: .center,
                    spacing: GoalRushTheme.Metrics.standardSpacing
                )
            )

        return layout {
            VStack(alignment: .leading, spacing: 2) {
                Text(isSalvaging ? "Choose Relics" : "Inventory")
                    .font(GoalRushTheme.Typography.title2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(
                    isSalvaging
                        ? "\(selectedIDs.count) selected"
                        : "\(record.relics.count) relic\(record.relics.count == 1 ? "" : "s")"
                )
                .font(GoalRushTheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.58))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !record.relics.isEmpty, !isSalvaging {
                Button("Salvage", systemImage: "arrow.3.trianglepath", action: beginSelection)
                    .buttonStyle(CompactGameButton())
                    .frame(
                        maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
                        alignment: .leading
                    )
                    .accessibilityIdentifier("relic-inventory-salvage")
            }
        }
    }

    @ViewBuilder
    private var inventoryContent: some View {
        if record.relics.isEmpty {
            VStack {
                ContentUnavailableView {
                    Label("No Relics Yet", systemImage: "diamond")
                } description: {
                    Text("Clear Wave 5 in Endless to earn your first relic.")
                } actions: {
                    Button(action: startEndless) {
                        Label("Start Endless", systemImage: "infinity")
                            .padding(
                                .horizontal,
                                GoalRushTheme.Metrics.standardSpacing
                            )
                    }
                    .buttonStyle(PrimaryGameButton())
                    .accessibilityIdentifier("relics-empty-start-endless")
                }
                .foregroundStyle(.white)
            }
            .padding(.vertical, GoalRushTheme.Metrics.sectionSpacing)
            .accessibilityElement(children: .contain)
        } else if displayedRelics.isEmpty {
            ContentUnavailableView {
                Label("No Matches", systemImage: "line.3.horizontal.decrease.circle")
            } description: {
                Text("Change or clear your inventory filters.")
            } actions: {
                Button("Clear Filters", action: clearFilters)
                    .buttonStyle(SecondaryGameButton())
            }
            .foregroundStyle(.white)
            .padding(.vertical, GoalRushTheme.Metrics.sectionSpacing)
        } else {
            RelicInventoryGrid(
                relics: displayedRelics,
                equippedID: record.equippedRelicID,
                isSalvageMode: isSalvaging,
                selectedIDs: selectedIDs,
                salvagingIDs: salvagingIDs,
                onTap: handleRelicTap
            )
        }
    }

    private var inventoryControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                filterMenu
                sortMenu
            }
            VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                filterMenu
                sortMenu
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Menu("Primary Stat") {
                Button("All Primary Stats") { statFilter = nil }
                Divider()
                ForEach(EndlessRelicStat.allCases) { stat in
                    Button(stat.title) { statFilter = stat }
                }
            }

            Menu("Rarity") {
                Button("All Rarities") { rarityFilter = nil }
                Divider()
                ForEach(EndlessRelicRarity.allCases, id: \.self) { rarity in
                    Button(rarity.title) { rarityFilter = rarity }
                }
            }

            if statFilter != nil || rarityFilter != nil {
                Divider()
                Button("Clear Filters", action: clearFilters)
            }
        } label: {
            Label(filterTitle, systemImage: "line.3.horizontal.decrease")
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(CompactGameButton())
        .accessibilityIdentifier("relic-filter")
    }

    private var sortMenu: some View {
        Menu {
            ForEach(RelicInventorySort.allCases) { option in
                Button(option.title) { sort = option }
            }
        } label: {
            Label(sort.title, systemImage: "arrow.up.arrow.down")
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(CompactGameButton())
        .accessibilityIdentifier("relic-sort")
    }

    private var filterTitle: String {
        let count = [statFilter != nil, rarityFilter != nil].filter { $0 }.count
        return count == 0 ? "Filter" : "Filter · \(count)"
    }

    private var salvageActionBar: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: GoalRushTheme.Metrics.standardSpacing))
            : AnyLayout(HStackLayout(spacing: GoalRushTheme.Metrics.standardSpacing))

        return layout {
            Button("Cancel", action: cancelSelection)
                .buttonStyle(SecondaryGameButton())
                .accessibilityIdentifier("relic-salvage-cancel")

            Button(
                "Salvage \(selectedIDs.count) · +\(GameNumberFormatter.compact(selectedScrapValue))",
                role: .destructive
            ) {
                confirmsSalvage = true
            }
            .buttonStyle(PrimaryGameButton())
            .disabled(selectedIDs.isEmpty || !salvagingIDs.isEmpty)
            .accessibilityIdentifier("relic-salvage-confirm")
            .confirmationDialog(
                "Salvage \(selectedIDs.count) relic\(selectedIDs.count == 1 ? "" : "s")?",
                isPresented: $confirmsSalvage,
                titleVisibility: .visible
            ) {
                Button(
                    "Salvage \(selectedIDs.count) for \(GameNumberFormatter.compact(selectedScrapValue)) Scrap",
                    role: .destructive,
                    action: animateSalvage
                )
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    selectedIncludesEquipped
                        ? "This permanently removes the selected relics and unequips your active relic."
                        : "This permanently removes the selected relics."
                )
            }
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(GoalRushTheme.gold.opacity(0.75))
                .frame(height: 2)
        }
    }

    private func sortRelics(_ lhs: EndlessRelic, _ rhs: EndlessRelic) -> Bool {
        switch sort {
        case .newest:
            if lhs.acquiredAt != rhs.acquiredAt {
                return lhs.acquiredAt > rhs.acquiredAt
            }
        case .rarity:
            if lhs.rarity != rhs.rarity {
                return lhs.rarity > rhs.rarity
            }
        case .sourceWave:
            if lhs.sourceWaveMilestone != rhs.sourceWaveMilestone {
                return lhs.sourceWaveMilestone > rhs.sourceWaveMilestone
            }
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func handleRelicTap(_ relic: EndlessRelic) {
        if isSalvaging {
            store.uiAudio.play(.tap)
            if !selectedIDs.insert(relic.id).inserted {
                selectedIDs.remove(relic.id)
            }
        } else {
            let wasEquipped = record.equippedRelicID == relic.id
            guard store.equipRelic(wasEquipped ? nil : relic.id) else { return }
            store.uiAudio.play(wasEquipped ? .tap : .purchase)
        }
    }

    private func beginSelection() {
        store.uiAudio.play(.tap)
        selectedIDs.removeAll()
        withAnimation(reduceMotion ? nil : GoalRushTheme.Motion.transition) {
            isSalvaging = true
        }
    }

    private func cancelSelection() {
        store.uiAudio.play(.tap)
        salvageTask?.cancel()
        salvagingIDs.removeAll()
        selectedIDs.removeAll()
        withAnimation(reduceMotion ? nil : GoalRushTheme.Motion.transition) {
            isSalvaging = false
        }
    }

    private func animateSalvage() {
        let ids = selectedIDs
        guard !ids.isEmpty else { return }
        store.uiAudio.play(.purchase)
        salvageTask?.cancel()

        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .snappy(duration: 0.28)) {
            salvagingIDs = ids
        }

        salvageTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 320))
            } catch {
                return
            }
            let recovered = store.scrapRelics(ids)
            selectedIDs.removeAll()
            salvagingIDs.removeAll()
            isSalvaging = false
            showSalvageFeedback(recovered)
        }
    }

    private func showSalvageFeedback(_ amount: Int) {
        guard amount > 0 else { return }
        feedbackTask?.cancel()
        withAnimation(.easeOut(duration: 0.18)) {
            salvageFeedback = amount
        }
        feedbackTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(reduceMotion ? 700 : 1_050))
            } catch {
                return
            }
            withAnimation(.easeOut(duration: 0.2)) {
                salvageFeedback = nil
            }
        }
    }

    private func clearFilters() {
        statFilter = nil
        rarityFilter = nil
    }

    private func openForge() {
        store.uiAudio.play(.tap)
        store.route = .relicForge
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
