# Task 3 report: Campaign and Endless selection stages

## Status

Complete on branch `ux-engagement-overhaul`.

Implementation commit: `9cbb2f4fd36a17e0cce80972de9e12cfc10aee46`
(`feat: redesign campaign and endless selection`)

## Implementation

- Replaced the Campaign feed with an atmospheric selection stage using the
  selected world's hero art and `GameDestinationBar`.
- Added compact, shared Earth/Mars controls with the stable `world-*` and
  `endless-world-*` identifiers.
- Kept locked worlds and levels visible and disabled, with their exact unlock
  conditions included in the spoken accessibility label and hint.
- Added compact `level-N` nodes and local
  `selectedPreviewLevel: LevelDefinition?` disclosure state.
- Added a `GameSheetScaffold` level preview containing objective, reward,
  result/stars, ready state, and the `level-preview-play` action. Only that Play
  action calls `store.start(level:)`.
- Replaced the Endless arena cards with the same compact world-button language,
  one selected-world record/loadout summary, and one `start-endless` action.
- Kept all five Endless rules behind the explicit Rules/Info control.
- Preserved world-selection haptics, route/start domain methods, record values,
  rewards, stars, tap audio, and all requested stable identifiers.
- Extracted focused Campaign, Endless, and shared world-selection components so
  the two screen owners remain small and state-focused.

## TDD evidence

### RED

Before production edits, the existing new preview test was run unchanged:

```sh
xcodebuild test -project GoalRush.xcodeproj -scheme GoalRush \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:GoalRushUITests/GoalRushUITests/testCampaignLevelShowsPreviewBeforeLaunch
```

Observed result:

- exit code 65 / `TEST FAILED`;
- 1 test executed, 1 failure, 0 unexpected failures;
- expected assertion failure at `GoalRushUITests.swift:120` because tapping
  `level-1` navigated immediately and `level-preview` never appeared.

RED result bundle:
`/Users/jamespattison/Library/Developer/Xcode/DerivedData/GoalRush-cppgzrjkavsickcnmxkbxymabqsu/Logs/Test/Test-GoalRush-2026.07.22_19-49-41--0400.xcresult`

### GREEN

The preview test first passed independently after implementation: 1 test,
0 failures.

The final required focused command ran:

```sh
xcodebuild test -project GoalRush.xcodeproj -scheme GoalRush \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:GoalRushUITests/GoalRushUITests/testCampaignLevelShowsPreviewBeforeLaunch \
  -only-testing:GoalRushUITests/GoalRushUITests/testUnlockedMarsCampaignTabIsSelectable \
  -only-testing:GoalRushUITests/GoalRushUITests/testMarsEndlessStartsFromHubAndAdvances
```

Result: 3 tests executed, 0 failures, 0 unexpected failures, `TEST SUCCEEDED`.

GREEN result bundle:
`/Users/jamespattison/Library/Developer/Xcode/DerivedData/GoalRush-cppgzrjkavsickcnmxkbxymabqsu/Logs/Test/Test-GoalRush-2026.07.22_19-55-41--0400.xcresult`

Two adjacent regressions also passed together:

- `testHomeLevelAndUpgradeNavigation`, covering the preserved
  `app.buttons["Home"]` query and new destination bar;
- `testEndlessStartsWithPowerDraftThenCanPause`, covering the default-world
  Endless launch, draft, pause, and resume flow.

Result: 2 tests executed, 0 failures.

## Build and quality checks

Generic simulator build:

```sh
xcodebuild build -project GoalRush.xcodeproj -scheme GoalRush \
  -destination 'generic/platform=iOS Simulator'
```

Result: `BUILD SUCCEEDED`.

Both `git diff --check` and the staged `git diff --cached --check` exited 0.
Xcode emitted the existing non-fatal App Intents metadata warning; it did not
produce a build or test failure.

## Files

Created:

- `GoalRush/UI/CampaignSelectionComponents.swift`
- `GoalRush/UI/EndlessSelectionComponents.swift`
- `GoalRush/UI/WorldSelectionBar.swift`

Modified:

- `GoalRush/UI/LevelSelectView.swift`
- `GoalRush/UI/EndlessHubView.swift`
- `GoalRushUITests/GoalRushUITests.swift`
- `GoalRush.xcodeproj/project.pbxproj` to compile the focused component files.

No `Home*.swift`, domain, persistence, economy, asset, gameplay, or task-ledger
file was modified.
