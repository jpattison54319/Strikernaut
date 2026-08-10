import Foundation
import Observation

@MainActor
@Observable
final class GameStore {
    enum Route: Equatable {
        case home
        case campaign(CampaignRoute)
        case endless
        case characters
        case relics
        case relicForge
        case upgrades
        case settings
        case onboarding
        case trophies
        case playing(RunMode)
        case relicDrop(RunResult)
        case result(RunResult)
    }

    var route: Route = .home {
        didSet {
            switch route {
            case .home, .relics, .relicForge, .upgrades:
                resetRewardedTokenBonusEligibility()
            default:
                break
            }
        }
    }
    var progress: PlayerProgress
    var settings: GameSettings
    var selectedLevel = 1
    var selectedWorld: WorldID = .earth
    var pendingResetConfirmation = false
    let uiAudio: UIAudio
    var celebrations: [Celebration] = []
    let runCheckpointStore: RunCheckpointStore

    private let persistence: ProgressStore
    private var pendingSaveTask: Task<Void, Never>?
    private var rewardedTokenBonusWasClaimed = false
    private var rewardedTokenBonusMode: RunMode?

    init(
        progress: PlayerProgress,
        settings: GameSettings,
        persistence: ProgressStore,
        runCheckpointStore: RunCheckpointStore = RunCheckpointStore()
    ) {
        var reconciledProgress = progress
        reconciledProgress.reconcileUnlockedContent()
        self.progress = reconciledProgress
        self.settings = settings
        self.persistence = persistence
        self.runCheckpointStore = runCheckpointStore
        self.uiAudio = UIAudio(
            soundEnabled: settings.soundEnabled,
            hapticsEnabled: settings.hapticsEnabled
        )
    }

    static func bootstrap() -> GameStore {
        let persistence = FileProgressStore()
        let arguments = ProcessInfo.processInfo.arguments
        let runCheckpointStore = RunCheckpointStore(
            resetExistingStorage: arguments.contains("--reset-save")
        )
        if arguments.contains("--reset-save") {
            try? persistence.reset()
        }
        var progress = (try? persistence.load()) ?? .newPlayer
        let loadedProgress = progress
        progress.reconcileUnlockedContent()
        if progress != loadedProgress { try? persistence.save(progress) }
        if let currencyIndex = arguments.firstIndex(of: "--currency"),
           arguments.indices.contains(currencyIndex + 1),
           let value = Int(arguments[currencyIndex + 1]) {
            progress.trainingTokens = value
        }
        var settings = GameSettings.load()
#if DEBUG
        if arguments.contains("--reduced-effects") {
            settings.reducedFlashes = true
        }
#endif
        let store = GameStore(
            progress: progress,
            settings: settings,
            persistence: persistence,
            runCheckpointStore: runCheckpointStore
        )
        // Engagement bootstrap: migrate veteran saves past onboarding, arm daily systems.
        if !store.progress.hasSeenOnboarding &&
            (!store.progress.levelRecords.isEmpty || store.progress.lifetimeStats.totalRuns > 0) {
            store.progress.hasSeenOnboarding = true
        }
        let hasDebugLaunchIntent = arguments.contains("--reset-save") || arguments.contains("--screen")
            || arguments.contains("--level") || arguments.contains("--endless")
        if !store.progress.hasSeenOnboarding && !hasDebugLaunchIntent {
            store.route = .onboarding
        }
        store.refreshMissionsIfNeeded()
#if DEBUG
        if let screenIndex = arguments.firstIndex(of: "--screen"),
           arguments.indices.contains(screenIndex + 1) {
            switch arguments[screenIndex + 1] {
            case "levels", "planets": store.route = .campaign(.planets(page: 0))
            case "earth-map": store.route = .campaign(.worldMap(world: .earth, focusLevel: 1))
            case "moon-map": store.route = .campaign(.worldMap(world: .moon, focusLevel: 11))
            case "mars-map": store.route = .campaign(.worldMap(world: .mars, focusLevel: 21))
            case "endless": store.route = .endless
            case "gear", "characters": store.route = .characters
            case "relics": store.route = .relics
            case "forge": store.route = .relicForge
            case "upgrades": store.route = .upgrades
            case "settings": store.route = .settings
            case "onboarding": store.route = .onboarding
            case "trophies": store.route = .trophies
            case "result-endless", "relic-drop":
                let runID = UUID(
                    uuidString: "C09C1BA9-9307-49DC-B711-784EC75A9438"
                ) ?? UUID()
                let relic = EndlessRelicRules.runReward(
                    runID: runID,
                    waveReached: 12
                )
                store.progress.endlessRecord = .init(
                    bestWave: 12,
                    bestScore: 150_000,
                    relics: relic.map { [$0] } ?? [],
                    scrap: 65,
                    lastRewardedRunID: runID
                )
                store.progress.unlockedAchievements.formUnion(
                    AchievementCatalog.evaluate(progress: store.progress)
                )
                let result = RunResult(
                    runID: runID,
                    mode: .endless,
                    didWin: false,
                    tokensEarned: 286,
                    remainingStamina: 0,
                    wave: 12,
                    score: 184_500,
                    newBestWave: true,
                    newBestScore: true,
                    relicEarned: relic
                )
                store.route = arguments[screenIndex + 1] == "relic-drop"
                    ? .relicDrop(result)
                    : .result(result)
            case "result-world":
                store.progress.unlockedCharacters.insert(.volt)
                store.route = .result(.init(
                    mode: .campaign(level: 10),
                    didWin: true,
                    tokensEarned: 612,
                    remainingStamina: 38,
                    characterEarned: .volt
                ))
            case "result-loss":
                store.route = .result(.init(
                    mode: .campaign(level: 6),
                    didWin: false,
                    tokensEarned: 180,
                    remainingStamina: 0
                ))
            default: break
            }
        }
        if arguments.contains("--unlock-worlds") {
            store.progress.highestUnlockedLevel = GameContent.levels.count
        }
        if arguments.contains("--new-game-plus-ready") {
            store.progress.highestUnlockedLevel = GameContent.levels.count
            store.progress.currentCampaignClears = Set(
                GameContent.levels.map(\.number)
            )
            store.selectedWorld = .neptune
        }
        if arguments.contains("--endless-records") {
            store.progress.endlessRecord = .init(
                bestWave: 24,
                bestScore: 384_500,
                lastWave: 17,
                lastScore: 216_750
            )
        }
        if arguments.contains("--relic-fixtures") {
            store.seedRelicFixturesForTesting()
        }
        if arguments.contains("--progress-fixtures") {
            store.seedProgressFixturesForTesting()
        }
        if arguments.contains("--unlock-gear") || arguments.contains("--unlock-characters") {
            store.progress.unlockedCharacters = Set(CharacterID.allCases)
        }
        let previewUpgradeTrack: UpgradeTrack
        if let trackIndex = arguments.firstIndex(of: "--upgrade-track"),
           arguments.indices.contains(trackIndex + 1),
           let track = UpgradeTrack(rawValue: arguments[trackIndex + 1]) {
            previewUpgradeTrack = track
        } else {
            previewUpgradeTrack = .impact
        }
        if let upgradeLevelIndex = arguments.firstIndex(of: "--upgrade-level"),
           arguments.indices.contains(upgradeLevelIndex + 1),
           let level = Int(arguments[upgradeLevelIndex + 1]) {
            store.progress.setRank(max(0, level), for: previewUpgradeTrack)
        }
        if let prestigeIndex = arguments.firstIndex(of: "--upgrade-prestige-count"),
           arguments.indices.contains(prestigeIndex + 1),
           let count = Int(arguments[prestigeIndex + 1]) {
            store.progress.setPrestigeCount(
                min(max(0, count), UpgradePrestigeTier.allCases.count),
                for: previewUpgradeTrack
            )
        }
        if let characterIndex = arguments.firstIndex(of: "--character"),
           arguments.indices.contains(characterIndex + 1),
           let character = CharacterID(rawValue: arguments[characterIndex + 1]) {
            store.progress.unlockedCharacters.insert(character)
            store.progress.selectedCharacter = character
        }
        if arguments.contains("--reset-onboarding") {
            store.progress.hasSeenOnboarding = false
            store.route = .onboarding
        }
#endif
        if let levelIndex = arguments.firstIndex(of: "--level"),
           arguments.indices.contains(levelIndex + 1),
           let level = Int(arguments[levelIndex + 1]),
           (1...GameContent.levels.count).contains(level) {
            store.progress.highestUnlockedLevel = max(store.progress.highestUnlockedLevel, level)
            store.selectedLevel = level
            store.selectedWorld = GameContent.level(level).world
            store.route = .playing(.campaign(level: level))
        }
        if arguments.contains("--endless") {
            store.route = .playing(.endless)
        }
        store.evaluateAchievements()
        return store
    }

    func start(level: Int) {
        prepareRewardedTokenBonus(for: .campaign(level: level))
        selectedLevel = level
        selectedWorld = GameContent.level(level).world
        route = .playing(.campaign(level: level))
    }

    @discardableResult
    func beginNextCampaignCycle() -> Bool {
        guard progress.canBeginNextCampaignCycle else { return false }
        pendingSaveTask?.cancel()
        progress.campaignCycle += 1
        progress.currentCampaignClears.removeAll()
        progress.highestUnlockedLevel = 1
        selectedLevel = 1
        selectedWorld = .earth
        evaluateAchievements()
        saveProgress()
        route = .campaign(.worldMap(world: .earth, focusLevel: 1))
        return true
    }

    func openPlanetJourney(focusing world: WorldID? = nil) {
        let focusedDestinationIndex = world.flatMap { focusedWorld in
            WorldJourneyCatalog.destinations.firstIndex {
                $0.world == focusedWorld
            }
        }
        let destinationIndex = focusedDestinationIndex ?? WorldJourneyCatalog.destinations.firstIndex {
            $0.world == selectedWorld
        } ?? 0
        route = .campaign(.planets(page: destinationIndex / WorldJourneyCatalog.pageSize))
    }

    func openNewGamePlusGateway() {
        let destinationIndex = WorldJourneyCatalog.destinations.firstIndex {
            $0.action == .newGamePlus
        } ?? max(0, WorldJourneyCatalog.destinations.count - 1)
        route = .campaign(
            .planets(page: destinationIndex / WorldJourneyCatalog.pageSize)
        )
    }

    func openWorldMap(_ world: WorldID, focusLevel: Int? = nil) {
        guard GameContent.isWorldUnlocked(world, progress: progress) else { return }
        selectedWorld = world
        route = .campaign(.worldMap(world: world, focusLevel: focusLevel))
    }

    @discardableResult
    func selectWorld(_ world: WorldID) -> Bool {
        guard GameContent.isWorldUnlocked(world, progress: progress) else { return false }
        selectedWorld = world
        return true
    }

    func startEndless() {
        prepareRewardedTokenBonus(for: .endless)
        route = .playing(.endless)
    }

    func finish(_ result: RunResult, tokensAlreadyCredited: Int = 0) {
        Task {
            try? await runCheckpointStore.delete(for: result.mode)
        }
        prepareRewardedTokenBonus(for: result.mode)
        progress.trainingTokens += max(0, result.tokensEarned - tokensAlreadyCredited)
        var finalResult = result
        switch result.mode {
        case .campaign(let levelNumber):
            let previous = progress.levelRecords[levelNumber] ?? .empty
            if result.didWin && !previous.completed && levelNumber == 1 && progress.lifetimeStats.totalRuns == 0 {
                finalResult.isFirstClear = true
            }
            progress.levelRecords[levelNumber] = LevelRecord(
                completed: previous.completed || result.didWin,
                bestTokens: max(previous.bestTokens, result.tokensEarned),
                bestStamina: max(previous.bestStamina, result.remainingStamina)
            )
            if result.didWin {
                progress.currentCampaignClears.insert(levelNumber)
                progress.highestUnlockedLevel = min(GameContent.levels.count, max(progress.highestUnlockedLevel, levelNumber + 1))
                if levelNumber == GameContent.levels.count,
                   progress.campaignCycle > 0 {
                    progress.highestCompletedCampaignCycle = max(
                        progress.highestCompletedCampaignCycle,
                        progress.campaignCycle
                    )
                }
                let world = GameContent.level(levelNumber).world
                if levelNumber == GameContent.world(world).finalLevel,
                   let character = CharacterCatalog.reward(for: world),
                   !progress.unlockedCharacters.contains(character.id) {
                    progress.unlockedCharacters.insert(character.id)
                    finalResult.characterEarned = character.id
                }
            }
        case .endless:
            var record = progress.endlessRecord
            finalResult.newBestWave = result.wave > record.bestWave
            finalResult.newBestScore = result.score > record.bestScore
            record.bestWave = max(record.bestWave, result.wave)
            record.bestScore = max(record.bestScore, result.score)
            record.lastWave = result.wave
            record.lastScore = result.score
            if record.lastRewardedRunID != result.runID,
               !record.relics.contains(where: { $0.id == result.runID }),
               let relic = EndlessRelicRules.runReward(
                   runID: result.runID,
                   waveReached: result.wave,
                   newGamePlusCycle: progress.campaignCycle
               ) {
                record.relics.append(relic)
                record.lastRewardedRunID = result.runID
                finalResult.relicEarned = relic
            }
            progress.endlessRecord = record
        }
        recordRunStats(finalResult)
        evaluateAchievements()
        saveProgress()
        route = finalResult.relicEarned == nil
            ? .result(finalResult)
            : .relicDrop(finalResult)
    }

    func continueAfterRelicDrop(_ result: RunResult) {
        guard case .relicDrop(let displayedResult) = route,
              displayedResult == result else {
            return
        }
        route = .result(result)
    }

    func continueAfterResult(_ result: RunResult) {
        switch result.mode {
        case .endless:
            startEndless()
        case .campaign(let level):
            if result.didWin {
                resetRewardedTokenBonusEligibility()
            }
            if result.didWin, level == GameContent.levels.count {
                openNewGamePlusGateway()
            } else {
                start(level: result.didWin ? level + 1 : level)
            }
        }
    }

    func rewardedTokenBonus(for result: RunResult) -> Int {
        max(0, result.tokensEarned) / 2
    }

    func canOfferRewardedTokenBonus(for result: RunResult) -> Bool {
        guard case .result(let displayedResult) = route,
              displayedResult == result else {
            return false
        }
        return !rewardedTokenBonusWasClaimed && rewardedTokenBonus(for: result) > 0
    }

    @discardableResult
    func claimRewardedTokenBonus(for result: RunResult) -> Int {
        guard canOfferRewardedTokenBonus(for: result) else { return 0 }
        let bonus = rewardedTokenBonus(for: result)
        rewardedTokenBonusWasClaimed = true
        rewardedTokenBonusMode = result.mode
        progress.trainingTokens += bonus
        saveProgress()
        return bonus
    }

    func resetRewardedTokenBonusEligibility() {
        rewardedTokenBonusWasClaimed = false
        rewardedTokenBonusMode = nil
    }

    func creditRunTokens(_ amount: Int) {
        guard amount > 0 else { return }
        progress.trainingTokens += amount
        scheduleProgressSave(after: .seconds(1))
    }

    func purchase(_ track: UpgradeTrack) -> Bool {
        let rank = progress.rank(for: track)
        let prestigeCount = progress.prestigeCount(for: track)
        let cost = UpgradePrestigeRules.purchaseCost(
            level: rank,
            prestigeCount: prestigeCount
        )
        guard progress.trainingTokens >= cost else { return false }
        progress.trainingTokens -= cost
        if UpgradePrestigeRules.requiresPrestige(level: rank, prestigeCount: prestigeCount) {
            progress.setPrestigeCount(prestigeCount + 1, for: track)
        } else {
            progress.setRank(rank + 1, for: track)
        }
        progress.lifetimeStats.upgradesPurchased += 1
        saveProgress()
        evaluateAchievements()
        return true
    }

    @discardableResult
    func equipRelic(_ id: UUID?) -> Bool {
        if let id, !progress.endlessRecord.relics.contains(where: { $0.id == id }) {
            return false
        }
        progress.endlessRecord.equippedRelicID = id
        saveProgress()
        return true
    }

    @discardableResult
    func scrapRelics(_ ids: Set<UUID>) -> Int {
        guard !ids.isEmpty else { return 0 }
        let removed = progress.endlessRecord.relics.filter { ids.contains($0.id) }
        guard !removed.isEmpty else { return 0 }
        let recoveredScrap = removed.reduce(0) { $0 + $1.scrapValue }
        progress.endlessRecord.relics.removeAll { ids.contains($0.id) }
        if let equippedID = progress.endlessRecord.equippedRelicID,
           ids.contains(equippedID) {
            progress.endlessRecord.equippedRelicID = nil
        }
        progress.endlessRecord.scrap += recoveredScrap
        saveProgress()
        return recoveredScrap
    }

    @discardableResult
    func forgeRelic(focusing stat: EndlessRelicStat? = nil) -> EndlessRelic? {
        guard let milestone = EndlessRelicRules.forgeMilestone(
            forBestWaveReached: progress.endlessRecord.bestWave
        ) else {
            return nil
        }
        let cost = stat == nil
            ? EndlessRelicRules.randomForgeCost
            : EndlessRelicRules.focusedForgeCost
        guard progress.endlessRecord.scrap >= cost else { return nil }
        let relic = EndlessRelicRules.forgeRoll(
            sourceWaveMilestone: milestone,
            focusedStat: stat
        )
        progress.endlessRecord.scrap -= cost
        progress.endlessRecord.relics.append(relic)
        saveProgress()
        return relic
    }

    @discardableResult
    func selectCharacter(_ id: CharacterID) -> Bool {
        guard progress.unlockedCharacters.contains(id) else { return false }
        progress.selectedCharacter = id
        scheduleProgressSave(after: .milliseconds(150))
        return true
    }

    func updateSettings(_ update: (inout GameSettings) -> Void) {
        update(&settings)
        settings.save()
        uiAudio.isEnabled = settings.soundEnabled
        uiAudio.isHapticsEnabled = settings.hapticsEnabled
    }

    func resetProgress() {
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
        try? persistence.reset()
        Task {
            try? await runCheckpointStore.reset()
        }
        resetRewardedTokenBonusEligibility()
        progress = .newPlayer
        selectedLevel = 1
        selectedWorld = .earth
        pendingResetConfirmation = false
        celebrations = []
        route = .onboarding
    }

    func saveProgress() {
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
        try? persistence.save(progress)
    }

    private func prepareRewardedTokenBonus(for mode: RunMode) {
        if rewardedTokenBonusMode != mode {
            rewardedTokenBonusWasClaimed = false
        }
        rewardedTokenBonusMode = mode
    }

#if DEBUG
    func unlockAllContentForTesting() {
        progress.highestUnlockedLevel = GameContent.levels.map(\.number).max() ?? 1
        progress.unlockedCharacters = Set(CharacterID.allCases)
        saveProgress()
    }

    private func seedRelicFixturesForTesting() {
        let identifiers = [
            "001DF608-17D6-489B-966E-4271FE03F658",
            "5AA39D36-751D-4618-B5F2-FFB6A2668443",
            "665E09A6-EAC0-42EF-AE93-48F0723BA259",
            "59937E83-42E2-480A-BADB-1C046DF474A9",
            "5A435761-25BA-48B8-A17F-F96D3E03A236",
            "96DEDC61-F547-47A6-81D9-1EDE81396517",
            "891701C2-2A76-4971-93B9-555C96C22E85",
            "D7D4706E-56D0-4915-B64C-DCC22C09D64A",
        ].compactMap(UUID.init(uuidString:))
        let milestones = [5, 10, 20, 30, 50, 70, 100, 140]
        let stats = EndlessRelicStat.allCases
        let rarities = EndlessRelicRarity.allCases
        let relics = zip(identifiers, milestones).enumerated().map { index, pair in
            let targetRarity = rarities[index % rarities.count]
            var seed = UInt64(index + 1)
            var relic: EndlessRelic
            repeat {
                relic = EndlessRelicRules.roll(
                    id: pair.0,
                    acquiredAt: Date(
                        timeIntervalSince1970: 1_700_000_000 + Double(index)
                    ),
                    sourceWaveMilestone: pair.1,
                    guaranteedPrimary: stats[index % stats.count],
                    seed: seed
                )
                seed += 1
            } while relic.rarity != targetRarity
            return relic
        }
        progress.endlessRecord.bestWave = max(progress.endlessRecord.bestWave, 141)
        progress.endlessRecord.bestScore = max(progress.endlessRecord.bestScore, 2_850_000)
        progress.endlessRecord.lastWave = 54
        progress.endlessRecord.lastScore = 796_400
        progress.endlessRecord.relics = relics
        progress.endlessRecord.equippedRelicID = relics.last?.id
        progress.endlessRecord.scrap = 165
        progress.unlockedAchievements.formUnion(
            AchievementCatalog.evaluate(progress: progress)
        )
    }

    private func seedProgressFixturesForTesting() {
        progress.lifetimeStats = LifetimeStats(
            totalTokensEarned: 900,
            totalRuns: 42,
            totalWavesCleared: 168,
            totalTargetsDefeated: 1_284,
            bossesDefeated: 18,
            bestCombo: 9,
            upgradesPurchased: 31,
            characterAbilityDefeats: [
                .ace: 24,
                .volt: 17,
                .nova: 12,
                .aegis: 8,
            ]
        )
        progress.endlessRecord.bestWave = 18
        progress.dailyReward.streak = 2
        progress.setRank(4, for: .impact)
        progress.unlockedAchievements.formUnion(
            AchievementCatalog.evaluate(progress: progress)
        )
    }
#endif

    func markCampaignBriefingSeen(level: Int) {
        guard GameContent.levels.indices.contains(level - 1),
              !CampaignBriefingCatalog.discoveries(for: GameContent.level(level)).isEmpty,
              progress.seenCampaignBriefingLevels.insert(level).inserted else {
            return
        }
        saveProgress()
    }

    // MARK: - Engagement

    var nextDailyRewardDay: Int {
        guard isDailyRewardClaimable else {
            return DailyRewardEngine.collectionDay(forClaimCount: progress.dailyReward.streak)
        }
        let calendar = Calendar.current
        let yesterday = DailyRewardEngine.dayString(for: calendar.date(byAdding: .day, value: -1, to: .now) ?? .now, calendar: calendar)
        let nextClaimCount = progress.dailyReward.lastClaimDay == yesterday ? progress.dailyReward.streak + 1 : 1
        return DailyRewardEngine.collectionDay(forClaimCount: nextClaimCount)
    }

    var nextDailyReward: Int {
        DailyRewardEngine.rewards[nextDailyRewardDay - 1]
    }

    var isDailyRewardClaimable: Bool {
        DailyRewardEngine.isClaimable(state: progress.dailyReward, today: Self.todayStamp())
    }

    static func todayStamp(for date: Date = .now, calendar: Calendar = .current) -> String {
        DailyRewardEngine.dayString(for: date, calendar: calendar)
    }

    @discardableResult
    func claimDailyReward(now: Date = .now, calendar: Calendar = .current) -> Int {
        let today = DailyRewardEngine.dayString(for: now, calendar: calendar)
        let yesterdayDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let yesterday = DailyRewardEngine.dayString(for: yesterdayDate, calendar: calendar)
        let reward = DailyRewardEngine.claim(state: &progress.dailyReward, today: today, yesterday: yesterday)
        guard reward > 0 else { return 0 }
        progress.trainingTokens += reward
        saveProgress()
        evaluateAchievements()
        return reward
    }

    func refreshMissionsIfNeeded(now: Date = .now) {
        let today = Self.todayStamp(for: now)
        guard progress.missionsDay != today else { return }
        progress.missions = MissionCatalog.dailyMissions(dayStamp: today, highestUnlockedLevel: progress.highestUnlockedLevel)
        progress.missionsDay = today
        saveProgress()
    }

    @discardableResult
    func claimMission(_ kind: MissionKind) -> Int {
        guard let index = progress.missions.firstIndex(where: { $0.kind == kind }),
              progress.missions[index].isComplete, !progress.missions[index].claimed else { return 0 }
        progress.missions[index].claimed = true
        let reward = progress.missions[index].reward
        progress.trainingTokens += reward
        saveProgress()
        return reward
    }

    func recordRunStats(_ result: RunResult) {
        var stats = progress.lifetimeStats
        stats.totalRuns += 1
        stats.totalTokensEarned += result.tokensEarned
        stats.totalTargetsDefeated += result.targetsDefeated
        stats.bossesDefeated += result.bossesDefeated
        stats.bestCombo = max(stats.bestCombo, result.bestCombo)
        if let character = result.character, result.characterAbilityDefeats > 0 {
            stats.characterAbilityDefeats[character, default: 0] += result.characterAbilityDefeats
        }
        if result.mode.isEndless { stats.totalWavesCleared += max(0, result.wave - 1) }
        progress.lifetimeStats = stats
        MissionCatalog.apply(result: result, to: &progress.missions)
    }

    @discardableResult
    func evaluateAchievements() -> [AchievementID] {
        let newly = AchievementCatalog.evaluate(progress: progress).subtracting(progress.unlockedAchievements)
        guard !newly.isEmpty else { return [] }
        progress.unlockedAchievements.formUnion(newly)
        let ordered = AchievementCatalog.ordered.filter(newly.contains)
        celebrations.append(contentsOf: ordered.map { .achievement($0) })
        saveProgress()
        return ordered
    }

    func dismissCelebration(_ celebration: Celebration) {
        celebrations.removeAll { $0 == celebration }
    }

    func completeOnboarding() {
        progress.hasSeenOnboarding = true
        saveProgress()
    }

    private func scheduleProgressSave(after delay: Duration) {
        pendingSaveTask?.cancel()
        pendingSaveTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.saveProgress()
        }
    }
}
