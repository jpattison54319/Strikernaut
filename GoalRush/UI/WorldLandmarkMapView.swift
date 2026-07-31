import SwiftUI

struct WorldLandmarkMapView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var lockedMessage = ""
    @State private var showingLockedAlert = false

    let world: WorldID
    let focusLevel: Int?

    private var definition: WorldMapDefinition {
        WorldMapCatalog.map(for: world)
    }

    var body: some View {
        VStack(spacing: 0) {
            CampaignNavigationBar(
                title: GameContent.world(world).name,
                subtitle: navigationSubtitle,
                backTitle: "Planets",
                onBack: showPlanets,
                onHome: goHome
            )

            if dynamicTypeSize.isAccessibilitySize {
                accessibleLevelList
            } else {
                illustratedMap
            }
        }
        .background(GoalRushTheme.navy.ignoresSafeArea())
        .alert("Challenge Locked", isPresented: $showingLockedAlert) {
        } message: {
            Text(lockedMessage)
        }
    }

    private var illustratedMap: some View {
        ScrollView(.vertical) {
            GeometryReader { geometry in
                let mapHeight = geometry.size.height
                ZStack {
                    Image(definition.backgroundAsset)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: mapHeight)
                        .clipped()
                        .accessibilityHidden(true)

                    GoalRushTheme.navy.opacity(0.16)

                    WorldLandmarkPath(placements: definition.placements)
                        .stroke(
                            .white.opacity(0.68),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [3, 12])
                        )
                        .shadow(color: world.accentColor.opacity(0.52), radius: 6)

                    ForEach(definition.placements) { placement in
                        let level = GameContent.level(placement.levelNumber)
                        CampaignLandmarkNode(
                            level: level,
                            symbol: definition.landmarkSymbol,
                            record: store.progress.levelRecords[level.number],
                            maximumStamina: PlayerStats(progress: store.progress).maxStamina,
                            isCompleted: store.progress.hasClearedCurrentCampaignLevel(
                                level.number
                            ),
                            isUnlocked: level.number <= store.progress.highestUnlockedLevel,
                            onSelect: { select(level) }
                        )
                        .position(
                            x: geometry.size.width * placement.x,
                            y: mapHeight * placement.y
                        )
                    }
                }
            }
            .frame(height: 1_480)
        }
        .defaultScrollAnchor(focusAnchor)
        .scrollIndicators(.hidden)
    }

    private var accessibleLevelList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                    ForEach(GameContent.levels(in: world)) { level in
                        CampaignLandmarkNode(
                            level: level,
                            symbol: definition.landmarkSymbol,
                            record: store.progress.levelRecords[level.number],
                            maximumStamina: PlayerStats(progress: store.progress).maxStamina,
                            isCompleted: store.progress.hasClearedCurrentCampaignLevel(
                                level.number
                            ),
                            isUnlocked: level.number <= store.progress.highestUnlockedLevel,
                            onSelect: { select(level) }
                        )
                        .id(level.number)
                    }
                }
                .padding(GoalRushTheme.Metrics.horizontalPadding)
            }
            .task(id: focusTarget) {
                await Task.yield()
                proxy.scrollTo(focusTarget, anchor: .center)
            }
        }
    }

    private var completedCount: Int {
        GameContent.levels(in: world).filter {
            store.progress.hasClearedCurrentCampaignLevel($0.number)
        }.count
    }

    private var navigationSubtitle: String {
        let progress = "\(completedCount)/\(definition.placements.count) CHALLENGES CLEARED"
        guard store.progress.campaignCycle > 0 else { return progress }
        return "NG+\(store.progress.campaignCycle) · \(progress)"
    }

    private var focusTarget: Int {
        if let focusLevel, GameContent.level(focusLevel).world == world {
            return focusLevel
        }
        return GameContent.levels(in: world).first {
            $0.number <= store.progress.highestUnlockedLevel
                && !store.progress.hasClearedCurrentCampaignLevel($0.number)
        }?.number ?? GameContent.world(world).finalLevel
    }

    private var focusAnchor: UnitPoint {
        guard let placement = definition.placements.first(where: {
            $0.levelNumber == focusTarget
        }) else {
            return .bottom
        }
        return UnitPoint(x: 0.5, y: placement.y)
    }

    private func select(_ level: LevelDefinition) {
        guard level.number <= store.progress.highestUnlockedLevel else {
            store.uiAudio.play(.locked)
            lockedMessage = level.worldLevel == 1
                ? "Clear the previous world to unlock this challenge."
                : "Clear \(GameContent.world(world).name) challenge \(level.worldLevel - 1) first."
            showingLockedAlert = true
            return
        }
        store.uiAudio.play(.tap)
        store.start(level: level.number)
    }

    private func showPlanets() {
        store.uiAudio.play(.whoosh)
        store.openPlanetJourney(focusing: world)
    }

    private func goHome() {
        store.uiAudio.play(.tap)
        store.route = .home
    }
}

private nonisolated struct WorldLandmarkPath: Shape {
    let placements: [LandmarkPlacement]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = placements.first else { return path }
        path.move(to: point(first, in: rect))
        for placement in placements.dropFirst() {
            let destination = point(placement, in: rect)
            let current = path.currentPoint ?? destination
            let midpointY = (current.y + destination.y) * 0.5
            path.addCurve(
                to: destination,
                control1: CGPoint(x: current.x, y: midpointY),
                control2: CGPoint(x: destination.x, y: midpointY)
            )
        }
        return path
    }

    private func point(_ placement: LandmarkPlacement, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.width * placement.x, y: rect.height * placement.y)
    }
}
