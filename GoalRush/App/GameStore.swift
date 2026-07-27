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
        case upgrades
        case settings
        case onboarding
        case trophies
        case playing(RunMode)
        case result(RunResult)
    }

    var route: Route = .home
    var progress: PlayerProgress
    var settings: GameSettings
    var selectedLevel = 1
    var selectedWorld: WorldID = .earth
    var pendingResetConfirmation = false
    let uiAudio: UIAudio
    var celebrations: [Celebration] = []

    private let persistence: ProgressStore
    private var pendingSaveTask: Task<Void, Never>?

    init(progress: PlayerProgress, settings: GameSettings, persistence: ProgressStore) {
        var reconciledProgress = progress
        reconciledProgress.reconcileUnlockedContent()
        self.progress = reconciledProgress
        self.settings = settings
        self.persistence = persistence
        self.uiAudio = UIAudio(
            soundEnabled: settings.soundEnabled,
            hapticsEnabled: settings.hapticsEnabled
        )
    }

    static func bootstrap() -> GameStore {
        let persistence = FileProgressStore()
        let arguments = ProcessInfo.processInfo.arguments
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
            persistence: persistence
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
            case "upgrades": store.route = .upgrades
            case "settings": store.route = .settings
            case "onboarding": store.route = .onboarding
            case "trophies": store.route = .trophies
            case "result-endless":
                store.progress.endlessRecord = .init(bestWave: 11, bestScore: 150_000)
                store.route = .result(.init(
                    mode: .endless,
                    didWin: false,
                    tokensEarned: 286,
                    remainingStamina: 0,
                    wave: 12,
                    score: 184_500,
                    newBestWave: true,
                    newBestScore: true
                ))
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
        if arguments.contains("--endless-records") {
            store.progress.endlessRecord = .init(
                bestWave: 24,
                bestScore: 384_500,
                lastWave: 17,
                lastScore: 216_750
            )
        }
        if arguments.contains("--unlock-gear") || arguments.contains("--unlock-characters") {
            store.progress.unlockedCharacters = Set(CharacterID.allCases)
        }
        if let upgradeLevelIndex = arguments.firstIndex(of: "--upgrade-level"),
           arguments.indices.contains(upgradeLevelIndex + 1),
           let level = Int(arguments[upgradeLevelIndex + 1]) {
            store.progress.setRank(max(0, level), for: .impact)
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
        return store
    }

    func start(level: Int) {
        selectedLevel = level
        selectedWorld = GameContent.level(level).world
        route = .playing(.campaign(level: level))
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
        route = .playing(.endless)
    }

    func finish(_ result: RunResult, tokensAlreadyCredited: Int = 0) {
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
                progress.highestUnlockedLevel = min(GameContent.levels.count, max(progress.highestUnlockedLevel, levelNumber + 1))
                let world = GameContent.level(levelNumber).world
                if levelNumber == GameContent.world(world).finalLevel,
                   let character = CharacterCatalog.reward(for: world),
                   !progress.unlockedCharacters.contains(character.id) {
                    progress.unlockedCharacters.insert(character.id)
                    finalResult.characterEarned = character.id
                }
            }
        case .endless:
            let previous = progress.endlessRecord
            finalResult.newBestWave = result.wave > previous.bestWave
            finalResult.newBestScore = result.score > previous.bestScore
            progress.endlessRecord = EndlessRecord(
                bestWave: max(previous.bestWave, result.wave),
                bestScore: max(previous.bestScore, result.score),
                lastWave: result.wave,
                lastScore: result.score
            )
        }
        recordRunStats(finalResult)
        evaluateAchievements()
        saveProgress()
        route = .result(finalResult)
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
