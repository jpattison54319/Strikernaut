# Strikernaut Progressive Stadium UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the approved stadium-command-deck design language across Strikernaut while preserving all engagement behavior and stable navigation identifiers.

**Architecture:** Add a small SwiftUI design-system layer, then migrate screens by family: Home disclosure, selection, management/progress, and focused overlays. `GameStore` and existing domain types remain authoritative; sheets and selections are ephemeral view state.

**Tech Stack:** Swift 6, SwiftUI, Observation, SpriteKit, Swift Testing, XCTest UI automation, XcodeGen, iOS 18 deployment target.

## Global Constraints

- iOS deployment target remains 18.0; build and test on iPhone 17 Pro, iOS 26.5.
- Swift 6 strict concurrency and default `MainActor` isolation remain enabled.
- No third-party dependencies, network calls, persistence schema changes, or economy changes.
- Keep the existing `GameStore.Route` cases and existing UI-test identifiers stable.
- Every visible control has a persistent label and a minimum 44-point target.
- Spatial layouts must provide a collision-free accessibility Dynamic Type fallback.
- Motion must honor `accessibilityReduceMotion`; flash behavior remains governed by `reducedFlashes`.
- Follow red-green-refactor: observe every new focused test fail before production implementation.

---

### Task 1: Shared stadium design system and Home presentation policy

**Files:**
- Create: `GoalRush/UI/DesignSystem/AtmosphericGameScreen.swift`
- Create: `GoalRush/UI/DesignSystem/GameDestinationBar.swift`
- Create: `GoalRush/UI/DesignSystem/FloatingGameActionButton.swift`
- Create: `GoalRush/UI/DesignSystem/GameStatusBadge.swift`
- Create: `GoalRush/UI/DesignSystem/GameLaunchButtonStyle.swift`
- Create: `GoalRush/UI/DesignSystem/GameSheetScaffold.swift`
- Create: `GoalRush/UI/DesignSystem/GameSurface.swift`
- Create: `GoalRush/UI/HomePresentation.swift`
- Modify: `GoalRush/UI/GoalRushTheme.swift`
- Test: `GoalRushTests/HomePresentationTests.swift`

**Interfaces:**
- Produces `AtmosphericGameScreen(backgroundImage:content:)`.
- Produces `GameDestinationBar(title:trailingText:onHome:onInfo:)`.
- Produces `FloatingGameActionButton(title:subtitle:systemImage:badge:accent:action:)`.
- Produces `GameStatusBadge(text:tone:)`.
- Produces `GameSheetScaffold(title:subtitle:content:)`.
- Produces `HomePresentation.primaryAction(progress:) -> HomePrimaryAction` where `HomePrimaryAction` is `.campaign(level: Int)` or `.endless`.
- Produces `HomePresentation.completedMissionCount(_:) -> Int`.

- [ ] **Step 1: Write failing Home presentation tests**

```swift
import Testing
@testable import GoalRush

@MainActor
struct HomePresentationTests {
    @Test func newPlayerTargetsLevelOne() {
        #expect(HomePresentation.primaryAction(progress: .newPlayer) == .campaign(level: 1))
    }

    @Test func firstUnlockedIncompleteLevelWins() {
        var progress = PlayerProgress.newPlayer
        progress.highestUnlockedLevel = 4
        progress.levelRecords[1] = .init(completed: true, bestTokens: 1, bestStamina: 1)
        progress.levelRecords[2] = .init(completed: true, bestTokens: 1, bestStamina: 1)
        #expect(HomePresentation.primaryAction(progress: progress) == .campaign(level: 3))
    }

    @Test func completedCampaignTargetsEndless() {
        var progress = PlayerProgress.newPlayer
        progress.highestUnlockedLevel = GameContent.levels.count
        for level in GameContent.levels {
            progress.levelRecords[level.number] = .init(completed: true, bestTokens: 1, bestStamina: 1)
        }
        #expect(HomePresentation.primaryAction(progress: progress) == .endless)
    }
}
```

- [ ] **Step 2: Run the focused unit test and observe RED**

Run:

```bash
xcodebuild test -project GoalRush.xcodeproj -scheme GoalRush -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:GoalRushTests/HomePresentationTests
```

Expected: compile failure because `HomePresentation` and `HomePrimaryAction` do not exist.

- [ ] **Step 3: Implement the minimal pure policy**

```swift
enum HomePrimaryAction: Equatable {
    case campaign(level: Int)
    case endless
}

enum HomePresentation {
    static func primaryAction(progress: PlayerProgress) -> HomePrimaryAction {
        guard let level = GameContent.levels.first(where: {
            $0.number <= progress.highestUnlockedLevel
                && progress.levelRecords[$0.number]?.completed != true
        }) else { return .endless }
        return .campaign(level: level.number)
    }

    static func completedMissionCount(_ missions: [MissionState]) -> Int {
        missions.filter { $0.isComplete && !$0.claimed }.count
    }
}
```

- [ ] **Step 4: Add shared components and named theme metrics**

Implement each component in its own file. `AtmosphericGameScreen` renders the
asset with top and bottom localized gradients. `FloatingGameActionButton`
always renders icon plus label, exposes `badge`, and uses a 52-point icon
surface. `GameSurface` provides semantic `.hud`, `.panel`, and `.modal`
modifiers. Do not add screen-specific navigation or domain state.

- [ ] **Step 5: Generate and verify GREEN**

Run `make generate`, rerun the focused test, then run `make build`. Expected:
the focused tests pass and the simulator build ends with `BUILD SUCCEEDED`.

---

### Task 2: Home command stage and detail sheets

**Files:**
- Modify: `GoalRush/UI/HomeView.swift`
- Modify: `GoalRush/UI/DailyRewardCard.swift`
- Modify: `GoalRush/UI/MissionsStrip.swift`
- Modify: `GoalRushUITests/GoalRushUITests.swift`

**Interfaces:**
- Home consumes `HomePresentation` and the Task 1 design-system components.
- Home owns `HomeSheet?` with `.dailyReward` and `.missions` cases.
- Preserve identifiers: `continue-hero`, `daily-chest`, `play`, `endless`, `gear`, `upgrades`, `trophies`, `settings`, `daily-collect`, and `mission-*`.

- [ ] **Step 1: Add the failing disclosure UI test**

```swift
func testHomeProgressivelyDisclosesMissionDetails() {
    let app = XCUIApplication()
    app.launchArguments = ["--reset-save", "--currency", "500"]
    app.launch()

    XCTAssertTrue(app.otherElements["home-root"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["missions"].exists)
    XCTAssertEqual(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "mission-")).count, 0)

    app.buttons["missions"].tap()
    XCTAssertTrue(app.otherElements["missions-sheet"].waitForExistence(timeout: 2))
    XCTAssertGreaterThan(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "mission-")).count, 0)
}
```

- [ ] **Step 2: Run the test and observe RED**

Expected: `home-root` and `missions` do not exist.

- [ ] **Step 3: Replace the Home feed with the command stage**

Use `AtmosphericGameScreen(backgroundImage: "MenuHero")`. At normal Dynamic
Type sizes render top HUD, brand, two satellite columns, the `continue-hero`,
and three-item dock without a `ScrollView`. At accessibility sizes render the
same controls in an anchored scrollable fallback. Use `HomePresentation` for
the primary action.

- [ ] **Step 4: Move Daily and Missions detail into sheets**

The first `daily-chest` tap opens a preview. `daily-collect` performs the claim
and keeps the celebration content in the sheet. The Missions button exposes
`MissionsStrip` only inside a sheet identified as `missions-sheet`.

- [ ] **Step 5: Run focused and existing Home tests**

Run the new disclosure test plus `testHomeLevelAndUpgradeNavigation`,
`testDailyChestClaimsAndPaysTokens`, `testSettingsExposeAccessibilityControls`,
and `testEndlessStartsWithPowerDraftThenCanPause`. Expected: all pass.

---

### Task 3: Campaign and Endless selection stages

**Files:**
- Modify: `GoalRush/UI/LevelSelectView.swift`
- Modify: `GoalRush/UI/EndlessHubView.swift`
- Modify: `GoalRushUITests/GoalRushUITests.swift`

**Interfaces:**
- Campaign owns `selectedPreviewLevel: LevelDefinition?`.
- `level-N` identifies compact level buttons; Play in the preview calls `store.start(level:)`.
- Endless preserves `endless-world-*` and `start-endless`.

- [ ] **Step 1: Add a failing level-preview UI test**

Launch `--reset-save --screen levels`, assert `level-preview` is absent, tap
`level-1`, assert `level-preview` and `level-preview-play` exist.

- [ ] **Step 2: Observe RED**

Expected: the current `level-1` immediately navigates instead of presenting
`level-preview`.

- [ ] **Step 3: Implement the Campaign selection stage**

Use atmospheric world art, `GameDestinationBar`, compact world controls,
compact level nodes, and a `GameSheetScaffold` preview. Locked nodes remain
visible and disabled with a spoken unlock condition.

- [ ] **Step 4: Implement the Endless selection stage**

Use the same top bar and world-button language. Keep a single selected record
summary and one `start-endless` launch action. Keep rules behind its explicit
Info control.

- [ ] **Step 5: Verify selection flows**

Run the new preview test, `testUnlockedMarsCampaignTabIsSelectable`, and
`testMarsEndlessStartsFromHubAndAdvances`. Expected: all pass.

---

### Task 4: Locker, Upgrades, Progress, and Settings

**Files:**
- Modify: `GoalRush/UI/GearView.swift`
- Modify: `GoalRush/UI/UpgradesView.swift`
- Modify: `GoalRush/UI/UpgradeCardView.swift`
- Modify: `GoalRush/UI/TrophiesView.swift`
- Modify: `GoalRush/UI/SettingsView.swift`
- Modify: `GoalRushUITests/GoalRushUITests.swift`

**Interfaces:**
- Upgrades owns `selectedTrack: UpgradeTrack?`; each compact track button keeps `upgrade-<rawValue>`.
- Locker owns explicit selected-item and set-progress sheets while retaining `gear-<slot>-next/previous`.
- The `.trophies` route displays title `Progress` and category buttons `progress-trophies`, `progress-lifetime`, `progress-streak`, and `progress-collections`.

- [ ] **Step 1: Add a failing upgrade disclosure test**

Launch `--reset-save --currency 500 --screen upgrades`, assert
`upgrade-detail` is absent, tap `upgrade-impact`, and assert `upgrade-detail`
and its purchase button exist.

- [ ] **Step 2: Observe RED**

Expected: current full upgrade cards expose purchase controls immediately and
have no `upgrade-detail` container.

- [ ] **Step 3: Convert Upgrades and Locker to management stages**

Upgrades renders compact labeled track buttons and moves `UpgradeCardView`
into a sheet. Locker keeps its stage and cycle controls; move item and set
details behind visible labeled buttons.

- [ ] **Step 4: Build Progress and simplify Settings**

Keep `.trophies` internally, change the visible destination to Progress, and
provide category buttons plus a next milestone summary. Move lifetime stats
out of Settings. Settings retains audio, feedback, accessibility, replay,
reset, and debug controls using shared surfaces.

- [ ] **Step 5: Verify management and utility flows**

Run the new upgrade test, `testLockerCyclesEarnedTorsoGear`,
`testHomeLevelAndUpgradeNavigation`, and `testSettingsExposeAccessibilityControls`.
Expected: all pass.

---

### Task 5: Result, Pause, Draft, and Onboarding consistency

**Files:**
- Modify: `GoalRush/UI/ResultView.swift`
- Modify: `GoalRush/UI/GameContainerView.swift`
- Modify: `GoalRush/UI/AbilityDraftView.swift`
- Modify: `GoalRush/UI/OnboardingView.swift`
- Modify: `GoalRushUITests/GoalRushUITests.swift`

**Interfaces:**
- Result owns `showingMoreActions`; secondary routes appear inside `result-more-actions`.
- Pause exposes `pause-missions` and opens the existing mission details in a sheet.
- Existing gameplay, draft, onboarding, result-primary, pause, and onboarding identifiers remain stable.

- [ ] **Step 1: Add a failing Result disclosure test**

Launch `--screen result-endless`, assert `result-primary` exists, assert
secondary route buttons are absent, tap `result-more`, and assert
`result-more-actions` exists.

- [ ] **Step 2: Observe RED**

Expected: `result-more` does not exist and secondary actions render inline.

- [ ] **Step 3: Simplify Result and Pause**

Keep the outcome, earned rewards, and primary action visible. Move route
utilities into More Actions. Replace the full pause `MissionsStrip` with a
single summary button that opens a mission sheet; Resume remains dominant.

- [ ] **Step 4: Align Draft and Onboarding surfaces**

Apply shared semantic surfaces, spacing, badges, and launch style without
changing ability selection, onboarding persistence, or gameplay start logic.

- [ ] **Step 5: Verify overlays and entry flows**

Run the new Result test, `testEndlessResultShowsNewBestBadge`,
`testDirectLevelLaunchCanPauseAndResume`, and
`testOnboardingShowsOnceAndStartsFirstLevel`. Expected: all pass.

---

### Task 6: App-wide verification and visual audit

**Files:**
- Modify only files needed for defects found by verification.

**Interfaces:**
- No new production interfaces.

- [ ] **Step 1: Run formatting and source checks**

Run `git diff --check` and `make generate`. Expected: no whitespace errors and
no unexpected project-file removals.

- [ ] **Step 2: Run full build and unit tests**

Run `make verify`. Expected: `BUILD SUCCEEDED`, `TEST SUCCEEDED`, and all unit
tests passing.

- [ ] **Step 3: Run the complete UI suite**

Run `make test-ui`. Expected: all UI tests pass. If the simulator session
stalls, rerun the exact failing test alone before classifying it as a product
failure.

- [ ] **Step 4: Capture every shared UI entry point**

Capture Home, Campaign, Endless, Locker, Upgrades, Progress, Settings, Result,
Pause, Draft, and Onboarding on iPhone 17 Pro/iOS 26.5. Inspect—not merely
build—for overlap, clipping, unreadable text, hidden artwork, and accidental
scrolling at the default content size.

- [ ] **Step 5: Repeat accessibility checks**

Run Home, Campaign, Upgrades, Result, and Settings at Accessibility XXXL with
Reduce Motion. Check VoiceOver labels/order and confirm closed sheet details
cannot receive focus.

