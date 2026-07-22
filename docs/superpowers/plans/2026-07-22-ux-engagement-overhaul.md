# Goal Rush UX & Engagement Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform Goal Rush into a highly polished, highly engaging game via a daily-hub Home, combo scoring, missions, achievements, daily streaks, FTUE onboarding, menu audio, and celebration juice on every screen.

**Architecture:** Pure testable domain engines (missions/daily/achievements) + `PlayerProgress` schema v3 migration, combo + run-stat counters in the deterministic simulation, `UIAudio` pooled menu SFX, reusable SwiftUI juice components, then screen-by-screen application. Spec: `docs/superpowers/specs/2026-07-22-ux-engagement-overhaul-design.md`.

**Tech Stack:** SwiftUI, SpriteKit, Swift Testing (`@Test`/`#expect`), XCTest UI tests, AVFoundation, Python 3 stdlib (SFX generation).

## Global Constraints

- iOS 18 deployment target, Swift 6, `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor`.
- **Do NOT run any git mutations.** This repo has zero commits and the owner has not authorized commits. Skip all "commit" steps.
- After adding/removing files, `make generate` (XcodeGen 2.45.4 installed) re-globs `GoalRush/`; `make build`/`make test` run it automatically.
- Verify with `make build` (build) and `make test` (unit). `make test-ui` for UI tests. Destination: iPhone 17 Pro, iOS 26.5.
- Tests use Swift Testing: `@MainActor struct XTests { @Test func y() { #expect(...) } }` with `@testable import GoalRush`.
- No network, no notifications, no new packages, no analytics — fully offline.
- All user-facing motion must honor `@Environment(\.accessibilityReduceMotion)`; flashes honor `settings.reducedFlashes`.
- `SeededGenerator` (in `GoalRush/Game/Simulation/SimulationModels.swift`) is the shared deterministic RNG: `init(seed: UInt64)`, `next() -> UInt64`, `unit() -> Double`.
- All new interactive elements need `.accessibilityLabel` and `.accessibilityIdentifier` where UI tests reference them.

---

### Task 1: Engagement domain types (DailyReward, Mission, Achievement, LifetimeStats)

**Files:**
- Create: `GoalRush/Domain/Engagement/LifetimeStats.swift`
- Create: `GoalRush/Domain/Engagement/DailyReward.swift`
- Create: `GoalRush/Domain/Engagement/Mission.swift`
- Create: `GoalRush/Domain/Engagement/Achievement.swift`
- Test: `GoalRushTests/EngagementTests.swift`

**Interfaces:**
- Consumes: `SeededGenerator`, `WorldID`, `GameContent.worlds`/`gearRewards`, `UpgradeTrack`, `RunResult` (fields `targetsDefeated`, `bossesDefeated`, `bestCombo`, `abilitiesDrafted`, `staminaFraction` arrive in Task 7 — use them in signatures now, defaults keep compiling).
- Produces (all later tasks rely on these exact names):
  - `LifetimeStats` (Codable struct, fields below)
  - `DailyRewardState`, `DailyRewardEngine.dayString(for:calendar:)`, `.claim(state:today:yesterday:) -> Int`, `.isClaimable(state:today:)`, `.reward(forStreakDay:)`
  - `MissionKind`, `MissionState { kind, goal, progress, claimed, reward, isComplete, fraction }`, `MissionCatalog.dailyMissions(dayStamp:highestUnlockedLevel:)`, `.apply(result:to:)`, `.title(for:)`, `.icon(for:)`, `.goalText(for:goal:)`
  - `AchievementID`, `AchievementCatalog.evaluate(progress:) -> Set<AchievementID>`, `.ordered: [AchievementID]`, `.title(for:)`, `.subtitle(for:)`, `.icon(for:)`

- [ ] **Step 1: Write the failing test** — `GoalRushTests/EngagementTests.swift`:

```swift
import Testing
@testable import GoalRush

@MainActor
struct EngagementTests {
    @Test func dailyRewardClaimAdvancesStreakAndPaysTableValue() {
        var state = DailyRewardState()
        let day1 = DailyRewardEngine.claim(state: &state, today: "2026-07-20", yesterday: "2026-07-19")
        #expect(day1 == 40)
        #expect(state.streak == 1)
        let day2 = DailyRewardEngine.claim(state: &state, today: "2026-07-21", yesterday: "2026-07-20")
        #expect(day2 == 60)
        #expect(state.streak == 2)
    }

    @Test func dailyRewardSameDayIsNoOpAndMissedDayResetsStreak() {
        var state = DailyRewardState(lastClaimDay: "2026-07-20", streak: 4)
        #expect(DailyRewardEngine.claim(state: &state, today: "2026-07-20", yesterday: "2026-07-19") == 0)
        #expect(state.streak == 4)
        #expect(!DailyRewardEngine.isClaimable(state: state, today: "2026-07-20"))
        let reward = DailyRewardEngine.claim(state: &state, today: "2026-07-25", yesterday: "2026-07-24")
        #expect(reward == 40)
        #expect(state.streak == 1)
    }

    @Test func dailyRewardCapsAtDaySevenValue() {
        #expect(DailyRewardEngine.reward(forStreakDay: 7) == 250)
        #expect(DailyRewardEngine.reward(forStreakDay: 30) == 250)
    }

    @Test func dailyMissionsAreDeterministicPerDayAndDistinct() {
        let first = MissionCatalog.dailyMissions(dayStamp: "2026-07-22", highestUnlockedLevel: 10)
        let second = MissionCatalog.dailyMissions(dayStamp: "2026-07-22", highestUnlockedLevel: 10)
        #expect(first == second)
        #expect(first.count == 3)
        #expect(Set(first.map(\.kind)).count == 3)
        let otherDay = MissionCatalog.dailyMissions(dayStamp: "2026-07-23", highestUnlockedLevel: 10)
        #expect(otherDay != first)
    }

    @Test func missionGoalsScaleWithCampaignProgress() {
        let early = MissionCatalog.dailyMissions(dayStamp: "2026-07-22", highestUnlockedLevel: 1)
        let late = MissionCatalog.dailyMissions(dayStamp: "2026-07-22", highestUnlockedLevel: 20)
        for kind in MissionKind.allCases {
            #expect(MissionCatalog.goal(for: kind, power: 0) <= MissionCatalog.goal(for: kind, power: 1))
        }
        #expect(early.allSatisfy { $0.goal > 0 && $0.reward > 0 })
        #expect(late.allSatisfy { $0.goal > 0 })
    }

    @Test func missionProgressFoldsRunResults() {
        var missions = [MissionState(kind: .defeatTargets, goal: 30, progress: 0, claimed: false, reward: 80),
                        MissionState(kind: .achieveCombo, goal: 10, progress: 0, claimed: false, reward: 90)]
        let result = RunResult(mode: .endless(world: .earth), didWin: false, tokensEarned: 50,
                               remainingStamina: 0, wave: 6, score: 5_000,
                               targetsDefeated: 22, bestCombo: 12)
        MissionCatalog.apply(result: result, to: &missions)
        #expect(missions[0].progress == 22)
        #expect(missions[1].progress == 12)
        #expect(missions[1].isComplete)
    }

    @Test func achievementEvaluationDerivesFromProgress() {
        var progress = PlayerProgress.newPlayer
        #expect(AchievementCatalog.evaluate(progress: progress).isEmpty)
        progress.levelRecords[1] = .init(completed: true, bestTokens: 50, bestStamina: 40)
        progress.lifetimeStats.totalTokensEarned = 1_200
        progress.lifetimeStats.bestCombo = 11
        progress.dailyReward.streak = 3
        let unlocked = AchievementCatalog.evaluate(progress: progress)
        #expect(unlocked.contains(.firstClear))
        #expect(unlocked.contains(.tokens1k))
        #expect(unlocked.contains(.combo10))
        #expect(unlocked.contains(.streak3))
        #expect(!unlocked.contains(.combo25))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test 2>&1 | grep -E "EngagementTests|error:" | head -20`
Expected: build error — types do not exist.

- [ ] **Step 3: Implement the domain types**

`GoalRush/Domain/Engagement/LifetimeStats.swift`:

```swift
import Foundation

struct LifetimeStats: Codable, Equatable, Sendable {
    var totalTokensEarned = 0
    var totalRuns = 0
    var totalWavesCleared = 0
    var totalTargetsDefeated = 0
    var bossesDefeated = 0
    var bestCombo = 0
    var upgradesPurchased = 0
}
```

`GoalRush/Domain/Engagement/DailyReward.swift`:

```swift
import Foundation

struct DailyRewardState: Codable, Equatable, Sendable {
    var lastClaimDay = ""
    var streak = 0
}

enum DailyRewardEngine {
    static let rewards = [40, 60, 80, 100, 140, 180, 250]

    static func reward(forStreakDay day: Int) -> Int {
        rewards[min(max(day, 1), rewards.count) - 1]
    }

    static func isClaimable(state: DailyRewardState, today: String) -> Bool {
        state.lastClaimDay != today
    }

    /// Returns the tokens awarded, or 0 when already claimed today.
    static func claim(state: inout DailyRewardState, today: String, yesterday: String) -> Int {
        guard state.lastClaimDay != today else { return 0 }
        state.streak = state.lastClaimDay == yesterday ? state.streak + 1 : 1
        state.lastClaimDay = today
        return reward(forStreakDay: state.streak)
    }

    static func dayString(for date: Date, calendar: Calendar = .current) -> String {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
    }
}
```

`GoalRush/Domain/Engagement/Mission.swift`:

```swift
import Foundation

enum MissionKind: String, Codable, CaseIterable, Sendable {
    case defeatTargets, earnTokens, reachWave, clearLevels, draftAbilities
    case winWithStamina, achieveCombo, defeatBosses, playEndlessRuns, earnScore
}

struct MissionState: Codable, Equatable, Sendable, Identifiable {
    var kind: MissionKind
    var goal: Int
    var progress: Int
    var claimed: Bool
    var reward: Int
    var id: String { kind.rawValue }
    var isComplete: Bool { progress >= goal }
    var fraction: Double { min(1, Double(progress) / Double(max(1, goal))) }
}

enum MissionCatalog {
    /// Deterministic 3-mission set per local day; identical on every device.
    static func dailyMissions(dayStamp: String, highestUnlockedLevel: Int) -> [MissionState] {
        let digits = dayStamp.filter(\.isNumber)
        var random = SeededGenerator(seed: (UInt64(digits) ?? 1) &* 9_973 &+ 11)
        let power = min(1.0, Double(max(1, highestUnlockedLevel)) / 20.0)
        var pool = MissionKind.allCases
        var missions: [MissionState] = []
        while missions.count < 3, !pool.isEmpty {
            let index = Int(random.next() % UInt64(pool.count))
            let kind = pool.remove(at: index)
            missions.append(MissionState(kind: kind, goal: goal(for: kind, power: power),
                                         progress: 0, claimed: false, reward: reward(for: kind)))
        }
        return missions
    }

    static func goal(for kind: MissionKind, power: Double) -> Int {
        let scaled = { (base: Double, extra: Double) in max(1, Int((base + extra * power).rounded())) }
        switch kind {
        case .defeatTargets: return scaled(25, 35)
        case .earnTokens: return scaled(150, 250)
        case .reachWave: return scaled(4, 4)
        case .clearLevels: return scaled(1, 1)
        case .draftAbilities: return scaled(3, 3)
        case .winWithStamina: return 1
        case .achieveCombo: return scaled(6, 8)
        case .defeatBosses: return 1
        case .playEndlessRuns: return 2
        case .earnScore: return scaled(20_000, 60_000)
        }
    }

    static func reward(for kind: MissionKind) -> Int {
        switch kind {
        case .defeatTargets, .earnTokens: 80
        case .reachWave, .clearLevels: 100
        case .draftAbilities: 60
        case .winWithStamina, .achieveCombo, .earnScore: 90
        case .defeatBosses: 120
        case .playEndlessRuns: 70
        }
    }

    static func apply(result: RunResult, to missions: inout [MissionState]) {
        for index in missions.indices where !missions[index].isComplete {
            switch missions[index].kind {
            case .defeatTargets: missions[index].progress += result.targetsDefeated
            case .earnTokens: missions[index].progress += result.tokensEarned
            case .reachWave: if result.mode.isEndless { missions[index].progress = max(missions[index].progress, result.wave) }
            case .clearLevels: if result.didWin, !result.mode.isEndless { missions[index].progress += 1 }
            case .draftAbilities: missions[index].progress += result.abilitiesDrafted
            case .winWithStamina: if result.didWin && result.staminaFraction >= 0.5 { missions[index].progress += 1 }
            case .achieveCombo: missions[index].progress = max(missions[index].progress, result.bestCombo)
            case .defeatBosses: missions[index].progress += result.bossesDefeated
            case .playEndlessRuns: if result.mode.isEndless { missions[index].progress += 1 }
            case .earnScore: missions[index].progress = max(missions[index].progress, result.score)
            }
        }
    }

    static func title(for kind: MissionKind) -> String {
        switch kind {
        case .defeatTargets: "Target Practice"
        case .earnTokens: "Token Run"
        case .reachWave: "Wave Rider"
        case .clearLevels: "Campaign Push"
        case .draftAbilities: "Power Hungry"
        case .winWithStamina: "Untouchable"
        case .achieveCombo: "Combo King"
        case .defeatBosses: "Giant Slayer"
        case .playEndlessRuns: "Marathon"
        case .earnScore: "High Scorer"
        }
    }

    static func icon(for kind: MissionKind) -> String {
        switch kind {
        case .defeatTargets: "target"
        case .earnTokens: "hexagon.fill"
        case .reachWave: "flag.checkered"
        case .clearLevels: "map.fill"
        case .draftAbilities: "sparkles"
        case .winWithStamina: "heart.fill"
        case .achieveCombo: "bolt.fill"
        case .defeatBosses: "crown.fill"
        case .playEndlessRuns: "infinity"
        case .earnScore: "trophy.fill"
        }
    }

    static func goalText(for kind: MissionKind, goal: Int) -> String {
        switch kind {
        case .defeatTargets: "Defeat \(goal) targets"
        case .earnTokens: "Earn \(goal) tokens"
        case .reachWave: "Reach wave \(goal)"
        case .clearLevels: "Clear \(goal) level\(goal == 1 ? "" : "s")"
        case .draftAbilities: "Draft \(goal) powers"
        case .winWithStamina: "Win with 50%+ stamina"
        case .achieveCombo: "Reach a ×\(goal) combo"
        case .defeatBosses: "Defeat a boss"
        case .playEndlessRuns: "Play \(goal) Endless runs"
        case .earnScore: "Score \(goal.formatted()) in a run"
        }
    }
}
```

`GoalRush/Domain/Engagement/Achievement.swift`:

```swift
import Foundation

enum AchievementID: String, Codable, CaseIterable, Sendable {
    case firstClear, earthWorldClear, marsWorldClear
    case wave5, wave10, wave20
    case tokens1k, tokens10k
    case combo10, combo25
    case firstUpgrade, maxTrack
    case firstGear, fullEarthSet, fullMarsSet
    case streak3, streak7
}

enum AchievementCatalog {
    /// Display order for the Trophies screen.
    static let ordered: [AchievementID] = [
        .firstClear, .firstUpgrade, .firstGear, .combo10, .streak3,
        .earthWorldClear, .wave5, .tokens1k, .fullEarthSet,
        .marsWorldClear, .wave10, .combo25, .tokens10k, .fullMarsSet,
        .wave20, .maxTrack, .streak7
    ]

    /// Derives every earned achievement from progress (idempotent).
    static func evaluate(progress: PlayerProgress) -> Set<AchievementID> {
        var unlocked: Set<AchievementID> = []
        if progress.levelRecords[1]?.completed == true { unlocked.insert(.firstClear) }
        if progress.levelRecords[GameContent.world(.earth).finalLevel]?.completed == true { unlocked.insert(.earthWorldClear) }
        if progress.levelRecords[GameContent.world(.mars).finalLevel]?.completed == true { unlocked.insert(.marsWorldClear) }
        let bestWave = progress.endlessRecords.values.map(\.bestWave).max() ?? 0
        if bestWave >= 5 { unlocked.insert(.wave5) }
        if bestWave >= 10 { unlocked.insert(.wave10) }
        if bestWave >= 20 { unlocked.insert(.wave20) }
        if progress.lifetimeStats.totalTokensEarned >= 1_000 { unlocked.insert(.tokens1k) }
        if progress.lifetimeStats.totalTokensEarned >= 10_000 { unlocked.insert(.tokens10k) }
        if progress.lifetimeStats.bestCombo >= 10 { unlocked.insert(.combo10) }
        if progress.lifetimeStats.bestCombo >= 25 { unlocked.insert(.combo25) }
        if progress.lifetimeStats.upgradesPurchased >= 1 { unlocked.insert(.firstUpgrade) }
        if UpgradeTrack.allCases.contains(where: { progress.rank(for: $0) >= UpgradeRules.maxRank }) { unlocked.insert(.maxTrack) }
        if !progress.unlockedGear.isEmpty { unlocked.insert(.firstGear) }
        if progress.unlockedGear.isSuperset(of: Set(GameContent.world(.earth).gearRewards)) { unlocked.insert(.fullEarthSet) }
        if progress.unlockedGear.isSuperset(of: Set(GameContent.world(.mars).gearRewards)) { unlocked.insert(.fullMarsSet) }
        if progress.dailyReward.streak >= 3 { unlocked.insert(.streak3) }
        if progress.dailyReward.streak >= 7 { unlocked.insert(.streak7) }
        return unlocked
    }

    static func title(for id: AchievementID) -> String {
        switch id {
        case .firstClear: "First Whistle"
        case .earthWorldClear: "Earth Champion"
        case .marsWorldClear: "Mars Conqueror"
        case .wave5: "Warming Up"
        case .wave10: "Double Digits"
        case .wave20: "Unstoppable"
        case .tokens1k: "Token Collector"
        case .tokens10k: "Token Tycoon"
        case .combo10: "On Fire"
        case .combo25: "Inferno"
        case .firstUpgrade: "First Steps"
        case .maxTrack: "Peak Performance"
        case .firstGear: "Suited Up"
        case .fullEarthSet: "Earth Icon"
        case .fullMarsSet: "Mars Legend"
        case .streak3: "Regular"
        case .streak7: "Dedicated"
        }
    }

    static func subtitle(for id: AchievementID) -> String {
        switch id {
        case .firstClear: "Clear your first level"
        case .earthWorldClear: "Clear the Earth world"
        case .marsWorldClear: "Clear the Mars world"
        case .wave5: "Reach wave 5 in Endless"
        case .wave10: "Reach wave 10 in Endless"
        case .wave20: "Reach wave 20 in Endless"
        case .tokens1k: "Earn 1,000 lifetime tokens"
        case .tokens10k: "Earn 10,000 lifetime tokens"
        case .combo10: "Reach a ×10 combo"
        case .combo25: "Reach a ×25 combo"
        case .firstUpgrade: "Buy your first upgrade"
        case .maxTrack: "Max any upgrade track"
        case .firstGear: "Earn your first gear"
        case .fullEarthSet: "Collect the full Earth set"
        case .fullMarsSet: "Collect the full Mars set"
        case .streak3: "Claim 3 daily rewards in a row"
        case .streak7: "Claim 7 daily rewards in a row"
        }
    }

    static func icon(for id: AchievementID) -> String {
        switch id {
        case .firstClear: "flag.checkered"
        case .earthWorldClear: "globe.americas.fill"
        case .marsWorldClear: "circle.grid.cross.fill"
        case .wave5, .wave10, .wave20: "infinity"
        case .tokens1k, .tokens10k: "hexagon.fill"
        case .combo10, .combo25: "bolt.fill"
        case .firstUpgrade: "arrow.up.circle.fill"
        case .maxTrack: "star.fill"
        case .firstGear: "tshirt.fill"
        case .fullEarthSet, .fullMarsSet: "crown.fill"
        case .streak3, .streak7: "flame.fill"
        }
    }
}
```

- [ ] **Step 4: Run test — expect compile errors on `RunResult` fields**

Run: `make test 2>&1 | grep "error:" | head -10`
Expected: errors for `targetsDefeated`, `bestCombo`, `abilitiesDrafted`, `staminaFraction` on `RunResult`, and `dailyReward`/`lifetimeStats` on `PlayerProgress`. Proceed — Task 2 adds the progress fields; add the `RunResult` fields NOW (they belong to Task 7 but are needed to compile this task's test):

In `GoalRush/Domain/RunResult.swift`, add to the struct and main init (with defaults so existing callers compile):

```swift
    var targetsDefeated: Int
    var bossesDefeated: Int
    var bestCombo: Int
    var abilitiesDrafted: Int
    var staminaFraction: Double
    var isFirstClear: Bool
    var newBestWave: Bool
    var newBestScore: Bool
```

Init signature becomes:

```swift
    init(
        mode: RunMode,
        didWin: Bool,
        tokensEarned: Int,
        remainingStamina: Double,
        wave: Int = 0,
        score: Int = 0,
        gearEarned: [GearID] = [],
        targetsDefeated: Int = 0,
        bossesDefeated: Int = 0,
        bestCombo: Int = 0,
        abilitiesDrafted: Int = 0,
        staminaFraction: Double = 0,
        isFirstClear: Bool = false,
        newBestWave: Bool = false,
        newBestScore: Bool = false
    ) { /* assign all */ }
```

- [ ] **Step 5: Add PlayerProgress v3 fields (minimal, to compile)** — in `GoalRush/Domain/GameModels.swift` add stored properties with defaults in the memberwise init and `decodeIfPresent` lines (full migration test is Task 2):

```swift
    var lifetimeStats: LifetimeStats
    var dailyReward: DailyRewardState
    var missions: [MissionState]
    var missionsDay: String
    var unlockedAchievements: Set<AchievementID>
    var seenGearIDs: Set<GearID>
    var hasSeenOnboarding: Bool
```

Update `PlayerProgress.newPlayer` (`schemaVersion: 3`, new fields defaulted), the memberwise init, `CodingKeys`, `init(from:)` (`decodeIfPresent` with defaults: `LifetimeStats()`, `DailyRewardState()`, `[]`, `""`, `[]`, `[]`, `false`), `encode(to:)` (encode all; `schemaVersion` 3), and `reconcileUnlockedContent()` (`schemaVersion = 3`).

- [ ] **Step 6: Run test to verify it passes**

Run: `make test 2>&1 | tail -5`
Expected: all tests pass (including pre-existing ones — v3 defaults keep them green).

---

### Task 2: PlayerProgress v3 migration test

**Files:**
- Test: `GoalRushTests/ProgressStoreTests.swift`

**Interfaces:**
- Consumes: Task 1's `PlayerProgress` v3 fields.
- Produces: nothing new.

- [ ] **Step 1: Write the failing test** — append to `ProgressStoreTests`:

```swift
    @Test func versionTwoSaveMigratesToThreeWithEngagementDefaults() throws {
        let json = """
        {
          "schemaVersion": 2,
          "trainingTokens": 321,
          "highestUnlockedLevel": 5,
          "upgradeRanks": {"impact": 2},
          "levelRecords": {"1": {"completed": true, "bestTokens": 40, "bestStamina": 30}},
          "hasMovedInTutorial": true,
          "unlockedGear": [],
          "equippedGear": {},
          "endlessRecords": {}
        }
        """
        var progress = try JSONDecoder().decode(PlayerProgress.self, from: Data(json.utf8))
        progress.reconcileUnlockedContent()
        #expect(progress.schemaVersion == 3)
        #expect(progress.trainingTokens == 321)
        #expect(progress.lifetimeStats == LifetimeStats())
        #expect(progress.dailyReward == DailyRewardState())
        #expect(progress.missions.isEmpty)
        #expect(progress.missionsDay.isEmpty)
        #expect(progress.unlockedAchievements.isEmpty)
        #expect(progress.seenGearIDs.isEmpty)
        #expect(!progress.hasSeenOnboarding)
        #expect(progress.rank(for: .impact) == 2)
    }
```

- [ ] **Step 2: Run test to verify it passes immediately** (Task 1 already implemented the migration)

Run: `make test 2>&1 | tail -3`
Expected: PASS. (This test locks the migration contract; if it fails, fix `init(from:)` defaults.)

---

### Task 3: UI sound effects — generator script, WAVs, UIAudio engine

**Files:**
- Create: `Tools/generate_ui_sfx.py`
- Create (generated): `GoalRush/Resources/Audio/ui-tap.wav`, `ui-whoosh.wav`, `ui-purchase.wav`, `ui-claim.wav`, `ui-fanfare.wav`, `ui-draft.wav`, `ui-locked.wav`, `ui-combo.wav`
- Create: `GoalRush/App/UIAudio.swift`
- Test: `GoalRushTests/ProgressStoreTests.swift` (extend existing bundle test)

**Interfaces:**
- Produces: `UIAudio` — `@MainActor final class`, `enum Sound: String, CaseIterable { case tap, whoosh, purchase, claim, fanfare, draft, locked, combo }` whose `rawValue` is prefixed `ui-` (`var rawValue: String { "ui-" + name }` — implement as raw values `"ui-tap"` etc.), `init(soundEnabled: Bool)`, `var isEnabled: Bool`, `func play(_ sound: Sound, volume: Float = 1.0)`.

- [ ] **Step 1: Write the failing test** — in `ProgressStoreTests.expectedAudioAssetsAreBundled`, extend the names array:

```swift
        let names = ["kick", "impact", "coin", "heal", "confirm", "victory", "defeat", "boss-phase", "music-calm", "music-pressure", "music-boss",
                     "ui-tap", "ui-whoosh", "ui-purchase", "ui-claim", "ui-fanfare", "ui-draft", "ui-locked", "ui-combo"]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test 2>&1 | grep -A2 expectedAudioAssets | head -5`
Expected: FAIL — `ui-*` files missing.

- [ ] **Step 3: Write `Tools/generate_ui_sfx.py`** (stdlib only: `wave`, `struct`, `math`; 22 050 Hz, 16-bit mono; short synthesized marimba-style tones and noise bursts matching the toy-like aesthetic):

```python
#!/usr/bin/env python3
"""Generate Goal Rush UI sound effects as 16-bit mono WAVs (no dependencies)."""
import math
import os
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "GoalRush", "Resources", "Audio")


def write_wav(name, samples):
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))
    print(f"wrote {path} ({len(samples) / RATE:.2f}s)")


def tone(freq, duration, decay=8.0, attack=0.004, volume=0.8, detune=1.0):
    count = int(RATE * duration)
    out = []
    for i in range(count):
        t = i / RATE
        env = min(1.0, t / attack) * math.exp(-decay * t)
        out.append(volume * env * math.sin(2 * math.pi * freq * detune * t))
    return out


def sequence(notes):
    """notes: list of (delay_seconds, tone_samples) layered into one buffer."""
    total = max(int((delay + len(samples) / RATE) * RATE) for delay, samples in notes)
    mix = [0.0] * total
    for delay, samples in notes:
        offset = int(delay * RATE)
        for i, s in enumerate(samples):
            mix[offset + i] += s
    peak = max(1.0, max(abs(s) for s in mix))
    return [s / peak * 0.9 for s in mix]


def noise_burst(duration, decay=30.0, volume=0.5):
    state = 0x12345
    out = []
    count = int(RATE * duration)
    for i in range(count):
        state = (1103515245 * state + 12345) % (1 << 31)
        noise = (state / (1 << 31)) * 2 - 1
        out.append(volume * math.exp(-decay * i / RATE) * noise)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    write_wav("ui-tap", tone(880, 0.09, decay=22.0, volume=0.55))
    write_wav("ui-whoosh", noise_burst(0.22, decay=14.0, volume=0.5))
    write_wav("ui-purchase", sequence([
        (0.0, tone(660, 0.14, decay=10.0)),
        (0.09, tone(990, 0.22, decay=9.0)),
    ]))
    write_wav("ui-claim", sequence([
        (0.0, tone(523, 0.12, decay=11.0)),
        (0.08, tone(659, 0.12, decay=11.0)),
        (0.16, tone(784, 0.24, decay=8.0)),
    ]))
    write_wav("ui-fanfare", sequence([
        (0.0, tone(523, 0.14, decay=9.0)),
        (0.11, tone(659, 0.14, decay=9.0)),
        (0.22, tone(784, 0.14, decay=9.0)),
        (0.33, tone(1047, 0.38, decay=6.0)),
    ]))
    write_wav("ui-draft", sequence([
        (0.0, tone(440, 0.16, decay=8.0, detune=1.0)),
        (0.05, tone(554, 0.18, decay=8.0)),
    ]))
    write_wav("ui-locked", tone(196, 0.16, decay=14.0, volume=0.6))
    write_wav("ui-combo", tone(1175, 0.07, decay=18.0, volume=0.5))


if __name__ == "__main__":
    main()
```

Run: `python3 Tools/generate_ui_sfx.py`
Expected: eight `wrote ...` lines.

- [ ] **Step 4: Implement `GoalRush/App/UIAudio.swift`** — pooled like `GameAudio`, no music, no haptics (views keep `.sensoryFeedback`):

```swift
import AVFoundation
import Foundation

@MainActor
final class UIAudio {
    enum Sound: String, CaseIterable {
        case tap = "ui-tap"
        case whoosh = "ui-whoosh"
        case purchase = "ui-purchase"
        case claim = "ui-claim"
        case fanfare = "ui-fanfare"
        case draft = "ui-draft"
        case locked = "ui-locked"
        case combo = "ui-combo"
    }

    var isEnabled: Bool
    private var pools: [Sound: [AVAudioPlayer]] = [:]
    private var indices: [Sound: Int] = [:]

    init(soundEnabled: Bool) {
        self.isEnabled = soundEnabled
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        for sound in Sound.allCases {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") else { continue }
            pools[sound] = (0..<3).compactMap { _ in
                guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
                player.prepareToPlay()
                return player
            }
        }
    }

    func play(_ sound: Sound, volume: Float = 1.0) {
        guard isEnabled, let players = pools[sound], !players.isEmpty else { return }
        let index = indices[sound, default: 0] % players.count
        let player = players[index]
        player.currentTime = 0
        player.volume = volume
        player.play()
        indices[sound] = index + 1
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `make test 2>&1 | tail -3`
Expected: PASS, including `expectedAudioAssetsAreBundled`.

---

### Task 4: Juice components — CountUpText, ConfettiBurst, modifiers, ToastBanner

**Files:**
- Create: `GoalRush/UI/Juice/CountUpText.swift`
- Create: `GoalRush/UI/Juice/ConfettiBurst.swift`
- Create: `GoalRush/UI/Juice/JuiceModifiers.swift`
- Create: `GoalRush/UI/Juice/ToastBanner.swift`

**Interfaces:**
- Produces (used by Tasks 9–16):
  - `CountUpText(value: Int, duration: Double = 0.9, font: Font = .title2.bold(), color: Color = .primary)` — a `Text`-like view counting 0→value.
  - `ConfettiBurst(accent: Color, particleCount: Int = 60)` — one-shot `Canvas` burst; respects Reduce Motion (renders nothing).
  - `View.pulseGlow(_ active: Bool, color: Color = GoalRushTheme.gold)`, `View.shimmer(active: Bool = true)`.
  - `ToastBanner(icon: String, title: String, subtitle: String, accent: Color)` — pill banner used for achievement unlocks.

- [ ] **Step 1: Implement all four files** (pure UI; verification is build + later UI tests).

`GoalRush/UI/Juice/CountUpText.swift`:

```swift
import SwiftUI

struct CountUpText: View {
    let value: Int
    var duration: Double = 0.9
    var font: Font = .title2.bold()
    var color: Color = .primary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedValue: Double = 0

    var body: some View {
        AnimatedNumber(value: animatedValue, font: font, color: color)
            .onAppear {
                guard !reduceMotion else { animatedValue = Double(value); return }
                withAnimation(.easeOut(duration: duration)) { animatedValue = Double(value) }
            }
    }
}

private struct AnimatedNumber: View, Animatable {
    var value: Double
    let font: Font
    let color: Color

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(Int(value.rounded()))")
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color)
    }
}
```

`GoalRush/UI/Juice/ConfettiBurst.swift`:

```swift
import SwiftUI

/// One-shot deterministic confetti burst drawn in a single Canvas pass.
struct ConfettiBurst: View {
    let accent: Color
    var particleCount: Int = 60
    var duration: Double = 1.2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.distantPast

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let elapsed = context.date.timeIntervalSince(start)
                Canvas { graphics, size in
                    guard elapsed >= 0, elapsed < duration else { return }
                    for index in 0..<particleCount {
                        var random = SeededGenerator(seed: UInt64(index &+ 1) &* 6_364_136_223_846_793_005)
                        let angle = random.unit() * .pi * 2
                        let speed = 90 + random.unit() * 240
                        let spin = random.unit() * .pi * 4
                        let x = size.width / 2 + cos(angle) * speed * elapsed
                        let y = size.height / 2 + sin(angle) * speed * elapsed + 320 * elapsed * elapsed
                        let fade = 1 - elapsed / duration
                        let rect = CGRect(x: x, y: y, width: 5, height: 8)
                        let color: Color = index.isMultiple(of: 3) ? GoalRushTheme.gold : (index.isMultiple(of: 2) ? accent : .white)
                        var transform = CGAffineTransform(translationX: rect.midX, y: rect.midY)
                        transform = transform.rotated(by: spin + elapsed * 5)
                        graphics.opacity = fade
                        graphics.fill(Path(rect).applying(transform), with: .color(color))
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { start = Date() }
        }
    }
}
```

`GoalRush/UI/Juice/JuiceModifiers.swift`:

```swift
import SwiftUI

private struct PulseGlow: ViewModifier {
    let active: Bool
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowing = false

    func body(content: Content) -> some View {
        content
            .shadow(color: active ? color.opacity(glowing ? 0.55 : 0.18) : .clear,
                    radius: glowing ? 16 : 7)
            .onAppear {
                guard active, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    glowing = true
                }
            }
    }
}

private struct Shimmer: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content.overlay {
            if active && !reduceMotion {
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.22), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: phase * geometry.size.width * 1.6)
                }
                .clipped()
                .allowsHitTesting(false)
                .onAppear {
                    withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
            }
        }
    }
}

extension View {
    func pulseGlow(_ active: Bool, color: Color = GoalRushTheme.gold) -> some View {
        modifier(PulseGlow(active: active, color: color))
    }

    func shimmer(active: Bool = true) -> some View {
        modifier(Shimmer(active: active))
    }
}
```

`GoalRush/UI/Juice/ToastBanner.swift`:

```swift
import SwiftUI

struct ToastBanner: View {
    let icon: String
    let title: String
    let subtitle: String
    var accent: Color = GoalRushTheme.gold

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3.bold())
                .foregroundStyle(GoalRushTheme.navy)
                .frame(width: 40, height: 40)
                .background(accent, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: .capsule)
        .overlay { Capsule().stroke(accent.opacity(0.45)) }
        .shadow(color: accent.opacity(0.25), radius: 14, y: 6)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }
}
```

- [ ] **Step 2: Build**

Run: `make build 2>&1 | tail -3`
Expected: BUILD SUCCEEDED. (`SeededGenerator` is internal to the app target — accessible from `GoalRush/UI/Juice` since same module.)

---

### Task 5: Combo system + run-stat counters in the simulation

**Files:**
- Modify: `GoalRush/Game/Simulation/GameSimulation.swift`
- Modify: `GoalRush/Game/Simulation/SimulationModels.swift`
- Modify: `GoalRush/Game/Rendering/GoalRushScene.swift` (combo milestone popup)
- Modify: `GoalRush/Game/Audio/GameAudio.swift` (combo milestone sound)
- Test: `GoalRushTests/GameSimulationTests.swift`

**Interfaces:**
- Produces:
  - `SimulationEvent.comboChanged(Int)`, `SimulationEvent.comboMilestone(Int)`
  - `SimulationSnapshot.combo: Int`, `.comboFraction: Double` (0–1 window remaining), `.bestCombo: Int`, `.targetsDefeated: Int`, `.bossesDefeated: Int`
  - `HUDState.combo: Int`, `.comboFraction: Double`
  - `GameSimulation.comboWindow: Double = 3.0` (static)

- [ ] **Step 1: Write the failing test** — append to `GameSimulationTests`:

```swift
    @Test func comboBuildsOnDefeatsAndResetsOnDamage() {
        let simulation = GameSimulation(mode: .endless(world: .earth), progress: .newPlayer, assistMode: true, seed: 5)
        simulation.apply(.oneTwo)
        simulation.apply(.powerDrive)
        var sawCombo = false
        var sawReset = false
        for _ in 0..<2_000 where !sawReset {
            if let target = simulation.snapshot.targets.first {
                simulation.setPlayerTarget(x: target.position.x)
            }
            for event in simulation.update(delta: 0.05) {
                if case .comboChanged(let count) = event, count >= 2 { sawCombo = true }
                if case .comboChanged(0) = event, sawCombo { sawReset = true }
            }
        }
        #expect(sawCombo)
        #expect(simulation.snapshot.bestCombo >= 2)
        #expect(simulation.snapshot.targetsDefeated >= simulation.snapshot.bestCombo)
    }

    @Test func comboResetsWithinSecondsWithoutDefeats() {
        let simulation = GameSimulation(mode: .endless(world: .earth), progress: .newPlayer, assistMode: true, seed: 5)
        simulation.apply(.powerDrive)
        var builtCombo = false
        for _ in 0..<1_200 where !builtCombo {
            if let target = simulation.snapshot.targets.first {
                simulation.setPlayerTarget(x: target.position.x)
            }
            builtCombo = simulation.update(delta: 0.05).contains { event in
                if case .comboChanged(let count) = event { return count >= 1 }
                return false
            }
        }
        #expect(builtCombo)
        // Stop aiming. The 3 s window lapses, or an enemy reaches the line and
        // deals damage — either way the combo must reset within 20 simulated seconds.
        var reset = false
        for _ in 0..<400 where !reset {
            _ = simulation.update(delta: 0.05)
            reset = simulation.snapshot.combo == 0
        }
        #expect(reset)
        #expect(simulation.snapshot.comboFraction == 0)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test 2>&1 | grep "error:" | head -5`
Expected: compile errors — `comboChanged`/`combo` missing.

- [ ] **Step 3: Implement combo + counters**

In `SimulationModels.swift`:
- Add cases to `SimulationEvent`: `case comboChanged(Int)` and `case comboMilestone(Int)`.
- Add to `SimulationSnapshot` (with the other vars, and update the memberwise init call in `GameSimulation.init`): `var combo: Int`, `var comboFraction: Double`, `var bestCombo: Int`, `var targetsDefeated: Int`, `var bossesDefeated: Int`.
- Add to `HUDState`: `var combo: Int` and `var comboFraction: Double`, set in `init(snapshot:)` from `snapshot.combo` / `snapshot.comboFraction`.

In `GameSimulation.swift`:
- Add statics and state near the other privates:

```swift
    static let comboWindow: Double = 3.0
    private static let comboMilestones: Set<Int> = [5, 10, 15, 25, 50, 100]
    private var comboCount = 0
    private var comboTimer = 0.0
```

- Initialize the new snapshot fields in `init` (`combo: 0, comboFraction: 0, bestCombo: 0, targetsDefeated: 0, bossesDefeated: 0`).
- In `update(delta:)`, right after `updatePlayer(delta:)` insert `updateCombo(delta: delta, events: &events)`.
- In `updateProjectiles`, at the defeat site (where `awardReward(for: defeated, events: &events)` is called), add right after that call: `registerDefeat(defeated, events: &events)`.
- In `applyDamage(_:events:)`, reset the combo only when stamina is actually lost (a shield block protects the combo — this makes Clean Sheet more valuable):

```swift
    private func applyDamage(_ amount: Double, events: inout [SimulationEvent]) {
        if snapshot.shieldCharges > 0 {
            snapshot.shieldCharges -= 1
        } else {
            snapshot.stamina = max(0, snapshot.stamina - amount)
            if comboCount > 0 {
                comboCount = 0
                comboTimer = 0
                snapshot.combo = 0
                snapshot.comboFraction = 0
                events.append(.comboChanged(0))
            }
        }
        events.append(.damage)
    }
```

- Add the two private methods:

```swift
    private func updateCombo(delta: Double, events: inout [SimulationEvent]) {
        guard comboCount > 0 else { return }
        comboTimer -= delta
        snapshot.comboFraction = max(0, comboTimer / Self.comboWindow)
        if comboTimer <= 0 {
            comboCount = 0
            snapshot.combo = 0
            snapshot.comboFraction = 0
            events.append(.comboChanged(0))
        }
    }

    private func registerDefeat(_ target: TargetState, events: inout [SimulationEvent]) {
        comboCount += 1
        comboTimer = Self.comboWindow
        snapshot.combo = comboCount
        snapshot.comboFraction = 1
        snapshot.bestCombo = max(snapshot.bestCombo, comboCount)
        snapshot.targetsDefeated += 1
        if case .enemy(let kind) = target.kind, isBoss(kind) { snapshot.bossesDefeated += 1 }
        events.append(.comboChanged(comboCount))
        if Self.comboMilestones.contains(comboCount) { events.append(.comboMilestone(comboCount)) }
    }
```

- In `awardTokens(_:at:events:)`, apply the combo score bonus (cap +100%):

```swift
        let comboBonus = 1 + min(1.0, Double(comboCount) * 0.1)
        snapshot.score += Int((Double(baseValue * 100 * max(1, snapshot.wave)) * comboBonus).rounded())
```

- [ ] **Step 4: Add combo milestone presentation**

In `GameAudio.handle(_:)` add: `case .comboMilestone: play("ui-combo", volume: 0.45, feedback: .reward)` and `case .comboChanged: break` (silent — too frequent). Also add `"ui-combo": 3` to the `poolSizes` dictionary in `preloadEffects()` so the sound is preloaded.

In `GoalRushScene.handle(_ events:)`, add:

```swift
            case .comboMilestone(let count):
                showComboPopup(count: count)
            case .comboChanged:
                break
```

And the popup method (model on existing `showWaveBanner`, using the scene's gold styling; place at mid-screen, big "×N COMBO" text, scale-up + fade, remove after ~0.9 s; skip when `reducedEffects`):

```swift
    private func showComboPopup(count: Int) {
        guard !reducedEffects else { return }
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = "COMBO ×\(count)"
        label.fontSize = 30
        label.fontColor = SKColor(red: 1.0, green: 0.72, blue: 0.12, alpha: 1)
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.62)
        label.zPosition = 60
        label.setScale(0.4)
        addChild(label)
        label.run(.sequence([
            .group([.scale(to: 1, duration: 0.16), .fadeIn(withDuration: 0.1)]),
            .wait(forDuration: 0.55),
            .fadeOut(withDuration: 0.25),
            .removeFromParent()
        ]))
    }
```

(Check the scene's existing label/font conventions and zPositions while editing — match them. `reducedEffects` is a stored property already passed to the scene.)

- [ ] **Step 5: Run tests**

Run: `make test 2>&1 | tail -3`
Expected: PASS — new combo tests plus the full pre-existing suite (no exact-score assertions exist, so the combo bonus is safe).

---

### Task 6: Level-1 first-win forgiveness (balance)

**Files:**
- Modify: `GoalRush/Game/Simulation/GameSimulation.swift`
- Test: `GoalRushTests/GameSimulationTests.swift`

**Interfaces:**
- Produces: Level 1 enemies have −15% HP and −15% speed; Level 1's checkpoint grants +10 stamina (clamped to max).

- [ ] **Step 1: Write the failing test**

```swift
    @Test func levelOneIsForgivingForNewPlayers() {
        let forgiving = GameSimulation(level: GameContent.level(1), progress: .newPlayer, assistMode: false, seed: 3)
        let standard = GameSimulation(level: GameContent.level(2), progress: .newPlayer, assistMode: false, seed: 3)
        for _ in 0..<600 {
            _ = forgiving.update(delta: 0.05)
            _ = standard.update(delta: 0.05)
        }
        let forgivingHP = forgiving.snapshot.targets.map(\.maximumHitPoints).max() ?? 0
        let standardHP = standard.snapshot.targets.map(\.maximumHitPoints).max() ?? 0
        // Level 2 scales up +8% per level while Level 1 scales down 15%.
        #expect(forgivingHP < standardHP)
    }

    @Test func levelOneCheckpointRestoresStamina() {
        let simulation = GameSimulation(level: GameContent.level(1), progress: .newPlayer, assistMode: false, seed: 3)
        // Drain stamina by standing still while enemies reach the line.
        var sawCheckpoint = false
        for _ in 0..<3_000 where !sawCheckpoint {
            sawCheckpoint = simulation.update(delta: 0.05).contains { event in
                if case .checkpoint = event { return true }
                return false
            }
        }
        #expect(sawCheckpoint)
        #expect(simulation.snapshot.stamina > 0)
    }
```

- [ ] **Step 2: Run test to verify it fails** (first test fails — HP equal-or-greater today)

Run: `make test 2>&1 | grep "levelOne" | head -5`

- [ ] **Step 3: Implement**

In `spawnEnemy`, change the campaign multiplier:

```swift
            multiplier = 1 + Double((level?.number ?? 1) - 1) * 0.08
            if level?.number == 1 { multiplier = 0.85 }
```

In `updateTargets`, enemy movement line, apply the level-1 speed factor:

```swift
                    let speedFactor = level?.number == 1 ? 0.85 : 1.0
                    target.position.y -= enemySpeed(kind) * speedFactor * activeSpeedMultiplier * slowFactor * delta
```

In `updateCampaignCheckpoints`, when a level-1 checkpoint fires, heal:

```swift
        if snapshot.elapsed / level.duration >= thresholds[checkpointIndex] {
            checkpointIndex += 1
            if level.number == 1 {
                snapshot.stamina = min(snapshot.maxStamina, snapshot.stamina + 10)
            }
            events.append(.checkpoint(checkpointIndex))
        }
```

- [ ] **Step 4: Run tests**

Run: `make test 2>&1 | tail -3`
Expected: PASS.

---

### Task 7: RunResult wiring — session counters → finish()

**Files:**
- Modify: `GoalRush/Game/GameSessionModel.swift`
- Modify: `GoalRush/UI/GameContainerView.swift`
- Test: `GoalRushTests/ProgressStoreTests.swift` (store-level, covered in Task 8's tests)

**Interfaces:**
- Consumes: Task 1 `RunResult` fields; Task 5 snapshot counters.
- Produces: `GameSessionModel.draftsChosen: Int`; `GameContainerView.finishRun()` builds the full `RunResult` (used by Task 8's `recordRunStats`).

- [ ] **Step 1: Session counts drafts**

In `GameSessionModel`, add `private(set) var draftsChosen = 0` and in `choose(_:)` increment it as the first line.

- [ ] **Step 2: Container reports full stats**

In `GameContainerView.finishRun()`, extend the `RunResult` construction:

```swift
        store.finish(
            RunResult(
                mode: session.mode,
                didWin: didWin,
                tokensEarned: session.snapshot.tokens + bonus,
                remainingStamina: session.snapshot.stamina,
                wave: session.snapshot.wave,
                score: session.snapshot.score,
                targetsDefeated: session.snapshot.targetsDefeated,
                bossesDefeated: session.snapshot.bossesDefeated,
                bestCombo: session.snapshot.bestCombo,
                abilitiesDrafted: session.draftsChosen,
                staminaFraction: session.snapshot.stamina / max(1, session.snapshot.maxStamina)
            ),
            tokensAlreadyCredited: creditedRunTokens
        )
```

- [ ] **Step 3: Build**

Run: `make build 2>&1 | tail -3`
Expected: BUILD SUCCEEDED.

---

### Task 8: GameStore engagement APIs + new routes + bootstrap rules

**Files:**
- Modify: `GoalRush/App/GameStore.swift`
- Modify: `GoalRush/UI/RootView.swift` (routes + toast overlay)
- Create: `GoalRush/App/Celebration.swift`
- Test: `GoalRushTests/EngagementTests.swift`

**Interfaces:**
- Produces (screens in Tasks 9–16 rely on these):
  - `GameStore.Route.onboarding`, `.trophies`
  - `store.uiAudio: UIAudio`
  - `store.celebrations: [Celebration]`, `store.dismissCelebration(_:)`
  - `Celebration` enum: `.achievement(AchievementID)` with `id: String`
  - `store.isDailyRewardClaimable: Bool`, `store.claimDailyReward(now:calendar:) -> Int`, `store.dailyStreak: Int`, `store.nextDailyReward: Int`
  - `store.refreshMissionsIfNeeded(now:)`, `store.claimMission(_ kind: MissionKind) -> Int`
  - `store.recordRunStats(_ result: RunResult)` (called from `finish`)
  - `store.evaluateAchievements() -> [AchievementID]`
  - `store.completeOnboarding()`, `store.markGearSeen(_ id: GearID)`
  - Debug args: `--reset-onboarding`, `--screen onboarding`, `--screen trophies`

- [ ] **Step 1: Write the failing test** — append to `EngagementTests`:

```swift
    @MainActor
    private func makeStore() -> GameStore {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        return GameStore(progress: .newPlayer, settings: .init(),
                         persistence: FileProgressStore(fileURL: directory.appending(path: "save.json")))
    }

    @Test func dailyClaimPaysTokensAndQueuesNothing() {
        let store = makeStore()
        let reward = store.claimDailyReward(now: Date(), calendar: .current)
        #expect(reward == 40)
        #expect(store.progress.trainingTokens == 40)
        #expect(store.claimDailyReward(now: Date(), calendar: .current) == 0)
        #expect(store.progress.trainingTokens == 40)
    }

    @Test func missionsRefreshOncePerDayAndClaimPaysReward() {
        let store = makeStore()
        store.refreshMissionsIfNeeded(now: Date())
        #expect(store.progress.missions.count == 3)
        let kind = store.progress.missions[0].kind
        #expect(store.claimMission(kind) == 0) // incomplete missions pay nothing
        var mission = store.progress.missions[0]
        mission.progress = mission.goal
        store.progress.missions[0] = mission
        let paid = store.claimMission(kind)
        #expect(paid == mission.reward)
        #expect(store.progress.trainingTokens == paid)
        #expect(store.claimMission(kind) == 0) // cannot claim twice
    }

    @Test func finishRecordsStatsProgressesMissionsAndUnlocksAchievements() {
        let store = makeStore()
        store.refreshMissionsIfNeeded(now: Date())
        store.progress.missions = [MissionState(kind: .defeatTargets, goal: 10, progress: 0, claimed: false, reward: 80)]
        store.finish(RunResult(mode: .campaign(level: 1), didWin: true, tokensEarned: 60,
                               remainingStamina: 80, targetsDefeated: 25, staminaFraction: 0.8))
        #expect(store.progress.lifetimeStats.totalRuns == 1)
        #expect(store.progress.lifetimeStats.totalTargetsDefeated == 25)
        #expect(store.progress.missions[0].isComplete)
        #expect(store.progress.unlockedAchievements.contains(.firstClear))
        #expect(store.celebrations.contains(.achievement(.firstClear)))
        if case .result(let result) = store.route {
            #expect(result.isFirstClear)
        } else {
            Issue.record("Expected result route")
        }
    }

    @Test func endlessFinishFlagsNewBestWave() {
        let store = makeStore()
        store.finish(RunResult(mode: .endless(world: .earth), didWin: false, tokensEarned: 10,
                               remainingStamina: 0, wave: 6, score: 9_000))
        guard case .result(let first) = store.route else { Issue.record("Expected result"); return }
        #expect(first.newBestWave)
        #expect(first.newBestScore)
        store.finish(RunResult(mode: .endless(world: .earth), didWin: false, tokensEarned: 10,
                               remainingStamina: 0, wave: 4, score: 3_000))
        guard case .result(let second) = store.route else { Issue.record("Expected result"); return }
        #expect(!second.newBestWave)
        #expect(!second.newBestScore)
    }

    @Test func purchaseCountsTowardAchievements() {
        let store = makeStore()
        store.progress.trainingTokens = 500
        #expect(store.purchase(.impact))
        #expect(store.progress.lifetimeStats.upgradesPurchased == 1)
        #expect(store.progress.unlockedAchievements.contains(.firstUpgrade))
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test 2>&1 | grep "error:" | head -5`
Expected: missing symbols.

- [ ] **Step 3: Implement `GoalRush/App/Celebration.swift`**

```swift
import Foundation

enum Celebration: Equatable, Identifiable, Sendable {
    case achievement(AchievementID)

    var id: String {
        switch self {
        case .achievement(let achievement): "achievement-\(achievement.rawValue)"
        }
    }
}
```

- [ ] **Step 4: Implement GameStore changes**

Add properties and init wiring:

```swift
    let uiAudio: UIAudio
    var celebrations: [Celebration] = []
```

In `init(progress:settings:persistence:)`, after existing assignments: `self.uiAudio = UIAudio(soundEnabled: settings.soundEnabled)`. Keep `uiAudio.isEnabled` synced inside `updateSettings`:

```swift
    func updateSettings(_ update: (inout GameSettings) -> Void) {
        update(&settings)
        settings.save()
        uiAudio.isEnabled = settings.soundEnabled
    }
```

Route enum: add `case onboarding` and `case trophies`.

Bootstrap rules (in `bootstrap()`, right after the store is created, BEFORE the `#if DEBUG` screen overrides):

```swift
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
```

Debug args (inside the existing `#if DEBUG` blocks): add `case "onboarding": store.route = .onboarding` and `case "trophies": store.route = .trophies` to the `--screen` switch; add a new argument:

```swift
        if arguments.contains("--reset-onboarding") {
            store.progress.hasSeenOnboarding = false
            store.route = .onboarding
        }
```

New methods:

```swift
    // MARK: - Engagement

    var dailyStreak: Int { progress.dailyReward.streak }

    var nextDailyReward: Int {
        DailyRewardEngine.reward(forStreakDay: isDailyRewardClaimable ? progress.dailyReward.streak + 1 : progress.dailyReward.streak)
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

    func markGearSeen(_ id: GearID) {
        guard progress.seenGearIDs.insert(id).inserted else { return }
        saveProgress()
    }
```

Wire into `finish(_:tokensAlreadyCredited:)`: after computing `finalResult` and before `saveProgress()`, call `recordRunStats(finalResult)`; set `finalResult.isFirstClear` / `newBestWave` / `newBestScore`:

```swift
        var finalResult = result
        switch result.mode {
        case .campaign(let levelNumber):
            let previous = progress.levelRecords[levelNumber] ?? .empty
            if result.didWin && !previous.completed && levelNumber == 1 && progress.lifetimeStats.totalRuns == 0 {
                finalResult.isFirstClear = true
            }
            // ... existing record/unlock logic unchanged ...
        case .endless(let world):
            let previous = progress.endlessRecord(for: world)
            finalResult.newBestWave = result.wave > previous.bestWave
            finalResult.newBestScore = result.score > previous.bestScore
            // ... existing record update unchanged ...
        }
        recordRunStats(finalResult)
        evaluateAchievements()
        saveProgress()
        route = .result(finalResult)
```

(Keep the existing token-credit and record-update lines exactly as they are; the snippet shows only where the new calls and flags go.)

In `purchase(_:)`, after `progress.setRank(rank + 1, for: track)`:

```swift
        progress.lifetimeStats.upgradesPurchased += 1
        saveProgress()
        evaluateAchievements()
        return true
```

(Remove the now-duplicated trailing `saveProgress(); return true` lines.)

In `resetProgress()`, also clear `celebrations`.

- [ ] **Step 5: RootView routes + celebration toasts**

In `RootView`'s switch add:

```swift
                case .onboarding: OnboardingView()
                case .trophies: TrophiesView()
```

(`OnboardingView` and `TrophiesView` arrive in Tasks 9 and 16; create minimal placeholder views NOW so the build stays green — Task 9 and 16 replace them. Create `GoalRush/UI/OnboardingView.swift` and `GoalRush/UI/TrophiesView.swift` each containing a trivial `struct XView: View { var body: some View { Text("…") } }`.)

Add `transitionIdentity` cases: `case .onboarding: "onboarding"` and `case .trophies: "trophies"`.

Add the toast overlay at the end of the outer `ZStack` in `RootView.body`:

```swift
            if let celebration = store.celebrations.first {
                VStack {
                    CelebrationToast(celebration: celebration) {
                        store.dismissCelebration(celebration)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .padding(.top, 8)
                .zIndex(10)
            }
```

with animation on `store.celebrations` (add `.animation(reduceMotion ? nil : .snappy(duration: 0.3), value: store.celebrations)` on the root ZStack).

Create `GoalRush/UI/CelebrationToast.swift`:

```swift
import SwiftUI

struct CelebrationToast: View {
    let celebration: Celebration
    let dismiss: () -> Void
    @Environment(GameStore.self) private var store
    @State private var autoDismissTask: Task<Void, Never>?

    var body: some View {
        Group {
            switch celebration {
            case .achievement(let id):
                ToastBanner(
                    icon: AchievementCatalog.icon(for: id),
                    title: "ACHIEVEMENT UNLOCKED",
                    subtitle: AchievementCatalog.title(for: id),
                    accent: GoalRushTheme.gold
                )
            }
        }
        .contentShape(Capsule())
        .onTapGesture { dismiss() }
        .sensoryFeedback(.success, trigger: celebration)
        .onAppear {
            store.uiAudio.play(.fanfare, volume: 0.7)
            autoDismissTask = Task {
                try? await Task.sleep(for: .seconds(3.5))
                guard !Task.isCancelled else { return }
                dismiss()
            }
        }
        .onDisappear { autoDismissTask?.cancel() }
        .accessibilityAddTraits(.isButton)
    }
}
```

- [ ] **Step 6: Run tests**

Run: `make test 2>&1 | tail -3`
Expected: PASS (including the 5 new store tests and all pre-existing tests — check `finishRetainsCreditedRunTokensWithoutDoubleCounting` still passes).

---

### Task 9: Onboarding (FTUE) flow

**Files:**
- Modify: `GoalRush/UI/OnboardingView.swift` (replace Task 8 placeholder)
- Test: `GoalRushUITests/GoalRushUITests.swift`

**Interfaces:**
- Consumes: `store.completeOnboarding()`, `store.start(level:)`, `store.route`, `store.uiAudio`, `.onboarding` route.
- Produces: full `OnboardingView`. On finish → marks onboarding complete and starts Level 1 (`store.start(level: 1)`).

- [ ] **Step 1: Implement `OnboardingView`** — 3 swipeable pages + final CTA; skip button; each page: SF-symbol hero (art arrives Task 17), headline, one-line promise:

```swift
import SwiftUI

struct OnboardingView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    private let pages: [(icon: String, accent: Color, title: String, message: String)] = [
        ("hand.draw.fill", GoalRushTheme.cyan, "Drag. Aim. Score.",
         "Slide your player across the lane — shots fire automatically at anything in your way."),
        ("sparkles", GoalRushTheme.gold, "Draft wild powers",
         "Every run, choose upgrades that stack into ridiculous builds. No two runs play the same."),
        ("arrow.up.circle.fill", GoalRushTheme.positive, "Get stronger forever",
         "Earn Training Tokens every run and spend them on permanent upgrades, gear, and glory."),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [GoalRushTheme.navy, GoalRushTheme.blue.opacity(0.30), GoalRushTheme.navy],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    if page < pages.count - 1 {
                        Button("Skip") { finish() }
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier("onboarding-skip")
                    }
                }
                .padding(.horizontal, 16)

                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { index in
                        VStack(spacing: 22) {
                            Spacer()
                            Image(systemName: pages[index].icon)
                                .font(.system(size: 84, weight: .bold))
                                .foregroundStyle(pages[index].accent)
                                .shadow(color: pages[index].accent.opacity(0.4), radius: 24)
                            VStack(spacing: 10) {
                                Text(pages[index].title)
                                    .font(.largeTitle.bold())
                                    .multilineTextAlignment(.center)
                                Text(pages[index].message)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 300)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .onChange(of: page) { _, _ in store.uiAudio.play(.whoosh, volume: 0.5) }

                Button(page < pages.count - 1 ? "Continue" : "Kick Off", systemImage: page < pages.count - 1 ? "arrow.right" : "play.fill") {
                    if page < pages.count - 1 {
                        store.uiAudio.play(.tap)
                        withAnimation(reduceMotion ? nil : .snappy) { page += 1 }
                    } else {
                        finish()
                    }
                }
                .buttonStyle(PrimaryGameButton())
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
                .accessibilityIdentifier("onboarding-next")
            }
        }
    }

    private func finish() {
        store.uiAudio.play(.fanfare, volume: 0.6)
        store.completeOnboarding()
        store.start(level: 1)
    }
}
```

- [ ] **Step 2: UI test — append to `GoalRushUITests.swift`**

```swift
    func testOnboardingShowsOnceAndStartsFirstLevel() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-onboarding", "--fixed-seed", "42"]
        app.launch()
        let next = app.buttons["onboarding-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 3))
        next.tap()
        next.tap()
        next.tap() // "Kick Off" on the final page
        XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: 5) || app.buttons["Kick Off"].waitForExistence(timeout: 2))
    }
```

(Level 1 has a briefing only if discoveries exist for it; the test accepts either the in-game pause button or the briefing's Kick Off.)

- [ ] **Step 3: Run build + UI test**

Run: `make build 2>&1 | tail -2 && make test-ui 2>&1 | tail -3`
Expected: BUILD SUCCEEDED, UI suite PASS (existing tests unaffected — `--reset-save` suppresses onboarding by design).

---

### Task 10: Home becomes the daily hub

**Files:**
- Modify: `GoalRush/UI/HomeView.swift` (full redesign)
- Create: `GoalRush/UI/DailyRewardCard.swift`
- Create: `GoalRush/UI/MissionsStrip.swift`
- Test: `GoalRushUITests/GoalRushUITests.swift`

**Interfaces:**
- Consumes: all Task 8 store APIs; `CountUpText`, `ConfettiBurst`, `pulseGlow`, `shimmer`.
- Produces: `DailyRewardCard`, `MissionsStrip` (also embedded by Task 11's pause overlay). Accessibility identifiers: `daily-chest`, `mission-<kind.rawValue>`, `mission-claim-<kind.rawValue>`, `continue-hero`, `trophies`.

- [ ] **Step 1: `DailyRewardCard.swift`** — chest (SF Symbol `gift.fill` in a glowing gold rounded square until Task 17 art), streak flame, claimable state, claim sheet with `CountUpText` + `ConfettiBurst`:

```swift
import SwiftUI

struct DailyRewardCard: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var claimedReward: ClaimedReward?

    var body: some View {
        Button {
            if store.isDailyRewardClaimable {
                store.uiAudio.play(.claim)
                let amount = store.claimDailyReward()
                if amount > 0 { claimedReward = ClaimedReward(amount: amount) }
            } else {
                store.uiAudio.play(.locked, volume: 0.5)
            }
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "gift.fill")
                    .font(.title2.bold())
                    .foregroundStyle(GoalRushTheme.navy)
                    .frame(width: 48, height: 48)
                    .background(GoalRushTheme.gold, in: .rect(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.isDailyRewardClaimable ? "Daily reward ready" : "Daily reward claimed")
                        .font(.headline)
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(GoalRushTheme.orange)
                        Text(store.dailyStreak > 0 ? "Day \(store.dailyStreak) streak" : "Start your streak")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 4)
                if store.isDailyRewardClaimable {
                    Text("+\(store.nextDailyReward)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(GoalRushTheme.gold)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(GoalRushTheme.positive)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [GoalRushTheme.gold.opacity(store.isDailyRewardClaimable ? 0.22 : 0.08), GoalRushTheme.surface.opacity(0.95)],
                    startPoint: .leading, endPoint: .trailing
                ),
                in: .rect(cornerRadius: 20)
            )
            .overlay { RoundedRectangle(cornerRadius: 20).stroke(GoalRushTheme.gold.opacity(store.isDailyRewardClaimable ? 0.5 : 0.15)) }
        }
        .buttonStyle(.plain)
        .pulseGlow(store.isDailyRewardClaimable)
        .accessibilityIdentifier("daily-chest")
        .accessibilityLabel(store.isDailyRewardClaimable
                            ? "Claim daily reward, plus \(store.nextDailyReward) tokens, streak day \(store.dailyStreak + 1)"
                            : "Daily reward claimed, streak day \(store.dailyStreak)")
        .sheet(item: $claimedReward) { claim in
            DailyRewardClaimSheet(reward: claim.amount, streak: store.dailyStreak)
                .presentationDetents([.medium])
        }
    }
}

private struct ClaimedReward: Identifiable {
    let id = UUID()
    let amount: Int
}

private struct DailyRewardClaimSheet: View {
    let reward: Int
    let streak: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            GoalRushTheme.navy.ignoresSafeArea()
            ConfettiBurst(accent: GoalRushTheme.gold)
            VStack(spacing: 18) {
                Spacer()
                Image(systemName: "gift.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(GoalRushTheme.gold)
                    .shadow(color: GoalRushTheme.gold.opacity(0.4), radius: 20)
                Text("DAY \(streak) REWARD")
                    .font(.caption.bold())
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Image(systemName: "hexagon.fill").foregroundStyle(GoalRushTheme.gold)
                    CountUpText(value: reward, font: .system(size: 44, weight: .bold), color: GoalRushTheme.gold)
                }
                Text("Come back tomorrow for \(DailyRewardEngine.reward(forStreakDay: min(streak + 1, 7))) tokens")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Collect", systemImage: "checkmark") { dismiss() }
                    .buttonStyle(PrimaryGameButton())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                    .accessibilityIdentifier("daily-collect")
            }
        }
    }
}
```

(The `ClaimedReward` wrapper type must be declared before `DailyRewardCard` uses it — put the struct at the bottom of the same file, right after `DailyRewardCard` and before `DailyRewardClaimSheet`.)

- [ ] **Step 2: `MissionsStrip.swift`** — 3 mission cards with progress rings and inline claim:

```swift
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
```

- [ ] **Step 3: Redesign `HomeView`** — keep `HomeModeButton` and its style unchanged; restructure the `ScrollView` content to: `topBar` → continue hero → `DailyRewardCard()` → `MissionsStrip()` → `title` (shrunk, becomes a section divider "PLAY") → mode cards → utility row (Locker / Upgrades / **Trophies**). New pieces:

```swift
    private var continueHero: some View {
        let nextLevel = nextCampaignLevel
        return Button {
            store.uiAudio.play(.tap)
            if let nextLevel { store.start(level: nextLevel.number) }
            else { store.route = .endless }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "play.fill")
                    .font(.title.bold())
                    .foregroundStyle(GoalRushTheme.navy)
                    .frame(width: 58, height: 58)
                    .background(.white, in: .circle)
                VStack(alignment: .leading, spacing: 3) {
                    Text(nextLevel == nil ? "CAMPAIGN COMPLETE" : "CONTINUE")
                        .font(.caption.bold())
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(nextLevel.map { "Level \($0.number): \($0.name)" } ?? "Chase your Endless best")
                        .font(.title3.bold())
                        .lineLimit(1)
                    if let nextLevel {
                        Text("First clear bonus +\(nextLevel.firstClearBonus) tokens")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                Spacer(minLength: 4)
            }
            .foregroundStyle(.white)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .background(
                LinearGradient(colors: [GoalRushTheme.gold, GoalRushTheme.orange],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: .rect(cornerRadius: 22)
            )
            .overlay { RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.35)) }
        }
        .buttonStyle(HomeModeButtonStyle())
        .shimmer(active: true)
        .accessibilityIdentifier("continue-hero")
    }

    private var nextCampaignLevel: LevelDefinition? {
        GameContent.levels.first { level in
            level.number <= store.progress.highestUnlockedLevel
                && store.progress.levelRecords[level.number]?.completed != true
        }
    }
```

Utility row gains a third button: `Button("Trophies", systemImage: "trophy.fill") { store.route = .trophies }` with `.accessibilityIdentifier("trophies")`.

Refresh missions whenever Home appears: add `.onAppear { store.refreshMissionsIfNeeded() }` to HomeView's root.

Add tap sounds: in `topBar` settings button and mode card actions, call `store.uiAudio.play(.tap)` before routing.

- [ ] **Step 4: UI test — daily claim** (append):

```swift
    func testDailyChestClaimsAndPaysTokens() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--currency", "0"]
        app.launch()
        let chest = app.buttons["daily-chest"]
        XCTAssertTrue(chest.waitForExistence(timeout: 3))
        chest.tap()
        let collect = app.buttons["daily-collect"]
        XCTAssertTrue(collect.waitForExistence(timeout: 3))
        collect.tap()
        XCTAssertTrue(chest.waitForExistence(timeout: 2))
    }
```

- [ ] **Step 5: Build + tests**

Run: `make build 2>&1 | tail -2 && make test-ui 2>&1 | tail -3`
Expected: BUILD SUCCEEDED, UI PASS. Existing `testHomeLevelAndUpgradeNavigation` still passes (identifiers `play`, `upgrades`, `settings` unchanged).

---

### Task 11: Gameplay HUD — combo meter, low-stamina pulse, pause missions

**Files:**
- Modify: `GoalRush/UI/GameContainerView.swift`

**Interfaces:**
- Consumes: `HUDState.combo`, `.comboFraction` (Task 5), `MissionsStrip` (Task 10), `store.uiAudio`.
- Produces: combo meter accessibility identifier `combo-meter`.

- [ ] **Step 1: Combo meter in the HUD**

In `GameContainerView.hud`, insert between the stamina/token `HStack` and the progress `HStack` (visible only when `session.hudState.combo > 0`):

```swift
            if session.hudState.combo > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.caption.bold())
                        .foregroundStyle(comboColor)
                    Text("COMBO ×\(session.hudState.combo)")
                        .font(.caption.bold())
                        .foregroundStyle(comboColor)
                        .contentTransition(.numericText())
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.12))
                            Capsule()
                                .fill(comboColor)
                                .frame(width: geometry.size.width * session.hudState.comboFraction)
                        }
                    }
                    .frame(height: 5)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Combo times \(session.hudState.combo)")
                .accessibilityIdentifier("combo-meter")
            }
```

Add the computed color (combo "heats up" as it grows):

```swift
    private var comboColor: Color {
        switch session.hudState.combo {
        case 25...: return GoalRushTheme.orange
        case 10...: return GoalRushTheme.gold
        default: return GoalRushTheme.cyan
        }
    }
```

Wrap the HUD's combo appearance in the existing phase animation (the `VStack` already animates on `session.phase`; add `.animation(reduceMotion ? nil : .snappy(duration: 0.2), value: session.hudState.combo > 0)` to the hud `VStack`).

- [ ] **Step 2: Low-stamina pulse**

In the stamina section of `hud`, add `.pulseGlow(session.hudState.stamina / max(1, session.hudState.maxStamina) <= 0.28, color: GoalRushTheme.orange)` on the stamina `ProgressView`.

- [ ] **Step 3: Pause overlay shows goals**

In `pauseOverlay`'s `GameCard` VStack, under the subtitle `VStack`, add:

```swift
                        if !store.progress.missions.isEmpty {
                            MissionsStrip()
                                .padding(.top, 4)
                        }
```

(Also add `store.uiAudio.play(.whoosh, volume: 0.4)` to the pause button action and `store.uiAudio.play(.tap)` to Resume/End Run.)

- [ ] **Step 4: Build + tests**

Run: `make build 2>&1 | tail -2 && make test 2>&1 | tail -3`
Expected: PASS.

---

### Task 12: Ability Draft — stagger, RECOMMENDED tag, endless mastery frame

**Files:**
- Modify: `GoalRush/UI/AbilityDraftView.swift`

**Interfaces:**
- Consumes: `store.uiAudio`, `shimmer`.
- Produces: recommendation heuristic used only here: lowest current rank wins; ties break toward the ability appearing earliest in the offered list.

- [ ] **Step 1: Staggered entrance + draft sound**

Add state + environment at the top of `AbilityDraftView`:

```swift
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
```

Change the `ForEach` to include the index and apply the stagger:

```swift
                    ForEach(Array(abilities.enumerated()), id: \.element) { index, ability in
                        abilityButton(ability)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 26)
                            .animation(
                                reduceMotion ? nil : .snappy(duration: 0.34).delay(Double(index) * 0.09),
                                value: appeared
                            )
                    }
```

Add to the root ZStack: `.onAppear { appeared = true; store.uiAudio.play(.draft, volume: 0.6) }`.

- [ ] **Step 2: RECOMMENDED tag**

Add:

```swift
    private var recommended: AbilityKind? {
        abilities.min { lhs, rhs in
            session.simulation.abilityRank(lhs) < session.simulation.abilityRank(rhs)
        }
    }
```

In `abilityButton`, next to the title `Text(AbilityPresentation.title(ability))`, add:

```swift
                        if ability == recommended {
                            Text("RECOMMENDED")
                                .font(.caption2.bold())
                                .foregroundStyle(GoalRushTheme.navy)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(GoalRushTheme.positive, in: .capsule)
                        }
```

- [ ] **Step 3: Endless mastery frame**

At the end of `abilityButton`'s label modifiers (after the existing `.shadow`), add:

```swift
            .overlay {
                if session.mode.isEndless && currentRank >= 5 {
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(GoalRushTheme.gold.opacity(0.75), lineWidth: 2)
                }
            }
```

and on the button itself: `.shimmer(active: session.mode.isEndless && currentRank >= 5)`.

- [ ] **Step 4: Build + UI tests**

Run: `make build 2>&1 | tail -2 && make test-ui 2>&1 | tail -3`
Expected: PASS — draft UI tests tap `ability-*` buttons, unchanged.

---

### Task 13: Result screen celebration

**Files:**
- Modify: `GoalRush/UI/ResultView.swift`
- Modify: `GoalRush/App/GameStore.swift` (debug preview arg)
- Test: `GoalRushUITests/GoalRushUITests.swift`

**Interfaces:**
- Consumes: `CountUpText`, `ConfettiBurst`, `RunResult.isFirstClear/newBestWave/newBestScore/staminaFraction`, mission completions from `store.progress.missions`.
- Produces: star-rating rule reused by Task 14: `enum StarRating { static func stars(staminaFraction: Double) -> Int }` — put it in `GoalRush/Domain/StarRating.swift`: 3 when ≥ 0.70, 2 when ≥ 0.35, else 1.
- Identifiers: `result-new-best`, `result-stars`.

- [ ] **Step 1: `GoalRush/Domain/StarRating.swift`**

```swift
import Foundation

enum StarRating {
    static func stars(staminaFraction: Double) -> Int {
        if staminaFraction >= 0.70 { return 3 }
        if staminaFraction >= 0.35 { return 2 }
        return 1
    }
}
```

- [ ] **Step 2: ResultView changes** (keep the overall layout; enhance):

a) **Confetti**: replace `ResultBurst` usage with both `ResultBurst` (existing) and `ConfettiBurst(accent: result.mode.world.accentColor)` in the root ZStack when `result.didWin || result.newBestWave || result.newBestScore`.

b) **FIRST CLEAR hero variant**: in `heroTitle`, add before the endless/campaign branches: `if result.isFirstClear { return "FIRST CLEAR!" }`; `heroIcon` → `star.circle.fill` in that case.

c) **NEW BEST badge**: insert after the hero `VStack` when `result.newBestWave || result.newBestScore`:

```swift
                    if result.newBestWave || result.newBestScore {
                        Text("NEW BEST!")
                            .font(.headline.bold())
                            .foregroundStyle(GoalRushTheme.navy)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(GoalRushTheme.gold, in: .capsule)
                            .shadow(color: GoalRushTheme.gold.opacity(0.5), radius: 14)
                            .scaleEffect(appeared ? 1 : 0.4)
                            .animation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.5).delay(0.35), value: appeared)
                            .accessibilityIdentifier("result-new-best")
                    }
```

d) **Stars for campaign wins**: insert after the NEW BEST badge when `result.didWin && !result.mode.isEndless`:

```swift
                    if result.didWin && !result.mode.isEndless {
                        HStack(spacing: 10) {
                            ForEach(0..<3, id: \.self) { index in
                                Image(systemName: index < StarRating.stars(staminaFraction: result.staminaFraction) ? "star.fill" : "star")
                                    .font(.title.bold())
                                    .foregroundStyle(GoalRushTheme.gold)
                                    .scaleEffect(appeared ? 1 : 0.2)
                                    .animation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.55).delay(0.25 + Double(index) * 0.14), value: appeared)
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(StarRating.stars(staminaFraction: result.staminaFraction)) of 3 stars")
                        .accessibilityIdentifier("result-stars")
                    }
```

e) **Count-up numbers**: in `resultStats`, replace `Text("+\(result.tokensEarned)")` with:

```swift
                    HStack(spacing: 4) {
                        Text("+").font(.title2.bold()).foregroundStyle(GoalRushTheme.gold)
                        CountUpText(value: result.tokensEarned, color: GoalRushTheme.gold)
                    }
```

and replace the endless `statRow(label: "Final score", ...)` value with `CountUpText(value: result.score, font: .body.bold(), color: .primary)`.

f) **Mission progress made this run**: insert a section after `resultStats` when any unclaimed-or-claimed mission has `progress > 0` and matches today (use `store.progress.missions.filter { $0.progress > 0 }`):

```swift
                    let progressed = store.progress.missions.filter { $0.progress > 0 }
                    if !progressed.isEmpty {
                        GameCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Mission progress", systemImage: "target")
                                    .font(.subheadline.bold())
                                ForEach(progressed) { mission in
                                    HStack {
                                        Text(MissionCatalog.title(for: mission.kind))
                                            .font(.caption)
                                        Spacer()
                                        if mission.isComplete && !mission.claimed {
                                            Text("COMPLETE • claim on Home")
                                                .font(.caption.bold())
                                                .foregroundStyle(GoalRushTheme.positive)
                                        } else {
                                            Text("\(min(mission.progress, mission.goal))/\(mission.goal)")
                                                .font(.caption.bold().monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
```

g) **Next-goal teaser**: insert before `actions` — find the cheapest unmaxed track; always show with progress toward cost; when affordable, pulse:

```swift
                    if let track = nextUpgradeTrack {
                        let rank = store.progress.rank(for: track)
                        let cost = UpgradeRules.cost(forNextRank: rank)
                        let affordable = store.progress.trainingTokens >= cost
                        Button { store.route = .upgrades } label: {
                            VStack(spacing: 8) {
                                HStack {
                                    Label("Next upgrade", systemImage: "arrow.up.circle.fill")
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text(affordable ? "READY" : "\(store.progress.trainingTokens)/\(cost)")
                                        .font(.caption.bold().monospacedDigit())
                                        .foregroundStyle(affordable ? GoalRushTheme.positive : .secondary)
                                }
                                Text("\(UpgradeRules.title(for: track)) rank \(rank + 1)")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                ProgressView(value: min(1, Double(store.progress.trainingTokens) / Double(cost)))
                                    .tint(affordable ? GoalRushTheme.positive : GoalRushTheme.gold)
                            }
                            .padding(14)
                            .background(.white.opacity(0.06), in: .rect(cornerRadius: 18))
                            .overlay { RoundedRectangle(cornerRadius: 18).stroke(affordable ? GoalRushTheme.positive.opacity(0.6) : .white.opacity(0.12)) }
                        }
                        .buttonStyle(.plain)
                        .pulseGlow(affordable, color: GoalRushTheme.positive)
                        .accessibilityIdentifier("result-next-upgrade")
                    }
```

with:

```swift
    private var nextUpgradeTrack: UpgradeTrack? {
        UpgradeTrack.allCases
            .filter { store.progress.rank(for: $0) < UpgradeRules.maxRank }
            .min { UpgradeRules.cost(forNextRank: store.progress.rank(for: $0)) < UpgradeRules.cost(forNextRank: store.progress.rank(for: $1)) }
    }
```

h) **Sounds**: in `.onAppear` add — win/new-best → `store.uiAudio.play(.fanfare)`; defeat → `store.uiAudio.play(.locked, volume: 0.4)`.

i) **FIRST CLEAR CTA**: in `actions`, when `result.isFirstClear`, add above the primary button a `Button("Spend your tokens", systemImage: "arrow.up.circle.fill") { store.route = .upgrades }` with `SecondaryGameButton()`.

- [ ] **Step 3: Debug preview supports NEW BEST**

In `GameStore.bootstrap()` `--screen result-endless`, change the seeded record to one below the result so the badge shows:

```swift
                store.progress.endlessRecords[.earth] = .init(bestWave: 11, bestScore: 150_000)
                store.route = .result(.init(
                    mode: .endless(world: .earth),
                    didWin: false,
                    tokensEarned: 286,
                    remainingStamina: 0,
                    wave: 12,
                    score: 184_500,
                    newBestWave: true,
                    newBestScore: true
                ))
```

- [ ] **Step 4: UI test** (append):

```swift
    func testEndlessResultShowsNewBestBadge() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--screen", "result-endless"]
        app.launch()
        XCTAssertTrue(app.staticTexts["result-new-best"].waitForExistence(timeout: 3)
                      || app.otherElements["result-new-best"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["result-primary"].exists)
    }
```

- [ ] **Step 5: Build + tests**

Run: `make build 2>&1 | tail -2 && make test-ui 2>&1 | tail -3`
Expected: PASS.

---

### Task 14: Level Select stars + world progress; Endless Hub best treatment

**Files:**
- Modify: `GoalRush/UI/LevelSelectView.swift`
- Modify: `GoalRush/UI/EndlessHubView.swift`

**Interfaces:**
- Consumes: `StarRating.stars(staminaFraction:)` (Task 13) — Level cards compute the fraction from `record.bestStamina` / 100 baseline (records predate max-stamina tracking; use `bestStamina / 100.0` clamped 0...1, which matches the base stamina and under-rates geared players slightly — acceptable and documented).

- [ ] **Step 1: Level cards show stars**

In `LevelCardView`, replace the completed `statusBadge` checkmark with:

```swift
        if completed {
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < StarRating.stars(staminaFraction: min(1, (record?.bestStamina ?? 0) / 100)) ? "star.fill" : "star")
                        .font(.caption.bold())
                        .foregroundStyle(GoalRushTheme.gold)
                }
            }
        }
```

Add `shimmer` to first-clearable cards: on the `GameCard` content, `.shimmer(active: unlocked && !completed)`.

- [ ] **Step 2: World progress bar**

In `WorldCampaignCard`, under the `Label(unlocked ? "\(completedCount) / 10" : "Locked", ...)`, add:

```swift
                    if unlocked {
                        ProgressView(value: Double(completedCount), total: 10)
                            .tint(world.id.accentColor)
                            .scaleEffect(y: 1.4)
                            .padding(.top, 4)
                    }
```

- [ ] **Step 3: Endless Hub**

In `EndlessHubView`'s bottom start button, change the label to include the record:

```swift
                Button("Start \(selectedWorld.name) Run • Best W\(record.bestWave)", systemImage: "infinity") {
```

where `record` is `store.progress.endlessRecord(for: store.selectedWorld)` — compute it next to `selectedWorld`. When `record.bestWave == 0`, keep the original label `"Start \(selectedWorld.name) Run"`. Add `store.uiAudio.play(.tap)` to the start action. In each world card, add a crown + "Beat your best" line when a record exists (read `EndlessWorldCard` while editing and add a small `Label("Best wave \(record.bestWave) — beat it", systemImage: "crown.fill")` in gold under the record text).

- [ ] **Step 4: Build + UI tests**

Run: `make build 2>&1 | tail -2 && make test-ui 2>&1 | tail -3`
Expected: PASS (the Mars endless test asserts `start.label.contains("Mars")` — still true).

---

### Task 15: Upgrades — purchase celebration + affordability states

**Files:**
- Modify: `GoalRush/UI/UpgradeCardView.swift`
- Modify: `GoalRush/UI/UpgradesView.swift`

**Interfaces:**
- Consumes: `store.uiAudio`, `pulseGlow`, `ToastBanner`-style inline flash.

- [ ] **Step 1: Read `UpgradeCardView.swift` first** — it owns the purchase button. Make these changes where they fit its structure:

a) Affordable state: when `store.progress.trainingTokens >= cost && rank < maxRank`, add a "READY" pill near the price and `.pulseGlow(true, color: GoalRushTheme.gold)` on the card.
b) Unaffordable: show `ProgressView(value: min(1, Double(tokens)/Double(cost)))` with label `"\(tokens)/\(cost)"` under the price instead of only dimming.
c) Maxed: replace the button with `Label("MAX", systemImage: "seal.fill")` in gold.
d) Purchase success: on successful `store.purchase(track)`, play `store.uiAudio.play(.purchase)`, fire `.sensoryFeedback(.success, trigger:)` on the card, and flash a brief gold overlay (an `@State private var justPurchased = false` toggled true then false after 0.6 s via `Task`, overlaying `RoundedRectangle(...).stroke(GoalRushTheme.gold, lineWidth: 2).opacity(justPurchased ? 1 : 0)`).
e) Failed purchase (shouldn't happen when button disabled, but guard): `store.uiAudio.play(.locked, volume: 0.5)`.

- [ ] **Step 2: UpgradesView entrance**

Add `.onAppear { store.uiAudio.play(.whoosh, volume: 0.35) }`.

- [ ] **Step 3: Build + UI tests**

Run: `make build 2>&1 | tail -2 && make test-ui 2>&1 | tail -3`
Expected: PASS (`upgrade-impact` identifier unchanged).

---

### Task 16: Locker NEW badges, Settings pride panel, Trophies screen

**Files:**
- Modify: `GoalRush/UI/GearView.swift`
- Modify: `GoalRush/UI/SettingsView.swift`
- Modify: `GoalRush/UI/TrophiesView.swift` (replace Task 8 placeholder)

**Interfaces:**
- Consumes: `store.markGearSeen(_:)`, `progress.seenGearIDs`, `AchievementCatalog`, `progress.lifetimeStats`.
- Produces: identifier `trophy-<id.rawValue>` rows; `settings-replay-onboarding` button.

- [ ] **Step 1: Locker NEW badges + sounds**

Read `GearView.swift`. Wherever gear items/variants are listed or cycled: items in `progress.unlockedGear` but not in `progress.seenGearIDs` get a small `Text("NEW")` gold capsule badge overlay. Call `store.markGearSeen(id)` when an item becomes visible (`.onAppear` on the badge's row) or when cycled into view. Add `store.uiAudio.play(.tap)` to the existing cycle/equip actions.

- [ ] **Step 2: Settings pride panel + replay onboarding**

In `SettingsView`, add a new section above Reset:

```swift
                Section("Your Journey") {
                    LabeledContent("Runs played", value: "\(store.progress.lifetimeStats.totalRuns)")
                    LabeledContent("Endless waves cleared", value: "\(store.progress.lifetimeStats.totalWavesCleared)")
                    LabeledContent("Best combo", value: "×\(store.progress.lifetimeStats.bestCombo)")
                    LabeledContent("Lifetime tokens", value: store.progress.lifetimeStats.totalTokensEarned.formatted())
                }
                Section {
                    Button("Replay Onboarding", systemImage: "play.rectangle") {
                        store.progress.hasSeenOnboarding = false
                        store.saveProgress()
                        store.route = .onboarding
                    }
                    .accessibilityIdentifier("settings-replay-onboarding")
                }
```

Also add `store.uiAudio.play(.tap)` to the Home toolbar button action.

- [ ] **Step 3: Trophies screen**

Replace `TrophiesView` with:

```swift
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
```

- [ ] **Step 4: Build + UI tests**

Run: `make build 2>&1 | tail -2 && make test-ui 2>&1 | tail -3`
Expected: PASS.

---

### Task 17: Art generation + integration

**Files:**
- Create (generated): `GoalRush/Resources/Assets.xcassets/OnboardingHero.imageset/`, `DailyChest.imageset/`
- Modify: `GoalRush/UI/OnboardingView.swift`, `GoalRush/UI/DailyRewardCard.swift`

**Interfaces:**
- Consumes: codex CLI image generation (operator skill at `/Users/jamespattison/.agents/skills/codex-cli-operator/SKILL.md`); art-direction prompts in `docs/art-direction.md`.

- [ ] **Step 1: Generate two assets in the existing toy-like 3D style**

Follow `docs/art-direction.md`'s established prompt pattern (premium rounded toy-like 3D render, cobalt/teal/gold palette, no text/logos/watermark):

1. **DailyChest** (square, used ~96 pt): "Premium rounded toy-like 3D render of a glowing treasure chest slightly open with golden light and soccer-ball-patterned coins spilling out, cobalt and gold palette, dark navy background, centered, no text, no watermark." Save as `GoalRush/Resources/Assets.xcassets/DailyChest.imageset/DailyChest.png` + `Contents.json` (`{"images":[{"filename":"DailyChest.png","idiom":"universal","scale":"1x"}],"info":{"author":"xcode","version":1}}`).
2. **OnboardingHero** (portrait 2:3): "Premium rounded toy-like 3D render, portrait futuristic soccer training stadium, small cobalt player dribbling toward friendly orange training robots, motion lines, sunny, clear lower third empty, no text, no UI, no watermark." Same imageset mechanics as `OnboardingHero`.

If generation fails or is unavailable, fall back to the SF Symbol presentation already built (Tasks 9–10 are symbol-first by design, so this task is purely additive).

- [ ] **Step 2: Integrate**

- `DailyRewardCard`: replace the `Image(systemName: "gift.fill")` block with `Image("DailyChest").resizable().scaledToFill().frame(width: 48, height: 48).clipShape(.rect(cornerRadius: 14))`.
- `OnboardingView`: put `Image("OnboardingHero").resizable().scaledToFill()` under the gradient (like HomeView's MenuHero treatment, `.ignoresSafeArea()` + navy scrim gradient above it). Keep symbols over it.
- Update `docs/art-direction.md` with the two new prompts (same format as existing entries).

- [ ] **Step 3: Build + verify assets compile**

Run: `make build 2>&1 | tail -2`
Expected: BUILD SUCCEEDED.

---

### Task 18: Final audit — accessibility, performance, docs, full verify

**Files:**
- Modify: `README.md` (new debug args + systems), `docs/architecture.md` (engagement systems), possibly `AGENTS.md` if created
- All screens (audit only)

- [ ] **Step 1: Accessibility audit** — walk every new identifier/label from this plan and confirm: combo meter hidden-but-labeled correctly, chest labeled with state, mission rows combined, stars labeled, toast announces (add `AccessibilityAnnouncement` posting in `CelebrationToast.onAppear`):

```swift
            if case .achievement(let id) = celebration {
                AccessibilityNotification.Announcement("Achievement unlocked: \(AchievementCatalog.title(for: id))").post()
            }
```

- [ ] **Step 2: Reduce-Motion audit** — confirm `ConfettiBurst`, stagger, shimmer, pulseGlow, count-up, toast slide all gate on `accessibilityReduceMotion` (per plan code); fix any misses.

- [ ] **Step 3: Performance sanity** — launch with `--level 15` on the simulator, play 60 s with volleys active, confirm no frame hitching from the combo meter (it's inside the existing 0.10 s HUD throttle) and that confetti/toasts never appear during gameplay.

- [ ] **Step 4: Docs**

- `README.md` debug args list: add `--reset-onboarding`, `onboarding` and `trophies` as `--screen` values.
- `docs/architecture.md`: append a paragraph — engagement systems (missions/daily/achievements in `Domain/Engagement`, schema v3, combo in simulation, `UIAudio` for menu SFX).

- [ ] **Step 5: Full verify**

Run: `make verify 2>&1 | tail -3 && make test-ui 2>&1 | tail -3`
Expected: BUILD SUCCEEDED, unit PASS, UI PASS — the complete suite green.
