import SwiftUI

struct PlanetJourneyView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedPage: Int?
    @State private var lockedMessage = ""
    @State private var showingLockedAlert = false
    @State private var newGamePlusProposal: NewGamePlusProposal?

    private let initialPage: Int

    init(initialPage: Int) {
        let clampedPage = min(max(initialPage, 0), max(0, WorldJourneyCatalog.pages.count - 1))
        self.initialPage = clampedPage
        _selectedPage = State(initialValue: clampedPage)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.015, green: 0.025, blue: 0.11),
                    Color(red: 0.055, green: 0.03, blue: 0.18),
                    GoalRushTheme.navy
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                CampaignNavigationBar(
                    title: "Planet Journey",
                    subtitle: store.progress.campaignCycle > 0
                        ? "NG+\(store.progress.campaignCycle) · KICK THROUGH WORLDS"
                        : "KICK THROUGH WORLDS",
                    backTitle: nil,
                    onBack: nil,
                    onHome: goHome
                )

                if dynamicTypeSize.isAccessibilitySize {
                    accessibleDestinationList
                } else {
                    pagedJourney
                }
            }
        }
        .alert("Destination Locked", isPresented: $showingLockedAlert) {
        } message: {
            Text(lockedMessage)
        }
        .sheet(item: $newGamePlusProposal) { proposal in
            NewGamePlusConfirmationView(cycle: proposal.cycle)
        }
    }

    private var pagedJourney: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ForEach(WorldJourneyCatalog.pageIndicesTopToBottom, id: \.self) { index in
                        PlanetJourneyPageView(
                            pageIndex: index,
                            destinations: WorldJourneyCatalog.pages[index],
                            progress: store.progress,
                            onSelect: select
                        )
                        .frame(height: geometry.size.height)
                        .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .defaultScrollAnchor(.bottom)
            .scrollPosition(id: $selectedPage)
            .overlay(alignment: .bottom) {
                paginationControls
                    .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
                    .padding(.bottom, GoalRushTheme.Metrics.standardSpacing)
            }
        }
    }

    private var accessibleDestinationList: some View {
        ScrollView {
            LazyVStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                ForEach(WorldJourneyCatalog.destinations) { destination in
                    PlanetDestinationRow(
                        destination: destination,
                        progress: store.progress,
                        onSelect: { select(destination) }
                    )
                }
            }
            .padding(GoalRushTheme.Metrics.horizontalPadding)
        }
    }

    private var paginationControls: some View {
        HStack {
            Button("Previous planets", systemImage: "chevron.left", action: showPreviousPage)
                .labelStyle(.iconOnly)
                .font(GoalRushTheme.Typography.title2)
                .frame(width: 52, height: 52)
                .background(.black.opacity(0.66), in: .circle)
                .overlay { Circle().stroke(.white.opacity(0.28), lineWidth: 2) }
                .disabled(currentPage == 0)
                .opacity(currentPage == 0 ? 0.42 : 1)
                .accessibilityIdentifier("planet-page-previous")

            Spacer()

            HStack(spacing: 8) {
                ForEach(WorldJourneyCatalog.pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? GoalRushTheme.gold : .white.opacity(0.34))
                        .frame(width: index == currentPage ? 22 : 8, height: 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Planet page \(currentPage + 1) of \(WorldJourneyCatalog.pages.count)")

            Spacer()

            Button("Next planets", systemImage: "chevron.right", action: showNextPage)
                .labelStyle(.iconOnly)
                .font(GoalRushTheme.Typography.title2)
                .frame(width: 52, height: 52)
                .background(.black.opacity(0.66), in: .circle)
                .overlay { Circle().stroke(.white.opacity(0.28), lineWidth: 2) }
                .disabled(currentPage >= WorldJourneyCatalog.pages.count - 1)
                .opacity(currentPage >= WorldJourneyCatalog.pages.count - 1 ? 0.42 : 1)
                .accessibilityIdentifier("planet-page-next")
        }
    }

    private var currentPage: Int {
        min(max(selectedPage ?? initialPage, 0), max(0, WorldJourneyCatalog.pages.count - 1))
    }

    private func showPreviousPage() {
        setPage(currentPage - 1)
    }

    private func showNextPage() {
        setPage(currentPage + 1)
    }

    private func setPage(_ page: Int) {
        guard WorldJourneyCatalog.pages.indices.contains(page) else { return }
        store.uiAudio.play(.whoosh)
        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .smooth(duration: 0.55)) {
            selectedPage = page
        }
    }

    private func select(_ destination: WorldJourneyDestination) {
        switch destination.action {
        case .world(let world):
            guard GameContent.isWorldUnlocked(world, progress: store.progress) else {
                showLocked(unlockRequirement(for: world))
                return
            }
            store.uiAudio.play(.tap)
            store.openWorldMap(world)
        case .newGamePlus:
            guard store.progress.canBeginNextCampaignCycle else {
                let requirement = store.progress.campaignCycle == 0
                    ? "Clear Neptune challenge 10 to unlock New Game+."
                    : "Clear Neptune challenge 10 in NG+\(store.progress.campaignCycle) to continue."
                showLocked(requirement)
                return
            }
            store.uiAudio.play(.tap)
            newGamePlusProposal = NewGamePlusProposal(
                cycle: store.progress.campaignCycle + 1
            )
        }
    }

    private func showLocked(_ message: String) {
        store.uiAudio.play(.locked)
        lockedMessage = message
        showingLockedAlert = true
    }

    private func unlockRequirement(for world: WorldID) -> String {
        switch world {
        case .earth:
            "Earth is available now."
        case .moon:
            "Clear Earth challenge 10 to unlock the Moon."
        case .mars:
            "Clear Moon challenge 10 to unlock Mars."
        case .jupiter:
            "Clear Mars challenge 30 to unlock Jupiter."
        case .saturn:
            "Clear Jupiter challenge 40 to unlock Saturn."
        case .uranus:
            "Clear Saturn challenge 50 to unlock Uranus."
        case .neptune:
            "Clear Uranus challenge 60 to unlock Neptune."
        }
    }

    private func goHome() {
        store.uiAudio.play(.tap)
        store.route = .home
    }
}

private struct NewGamePlusProposal: Identifiable {
    let cycle: Int
    var id: Int { cycle }
}
