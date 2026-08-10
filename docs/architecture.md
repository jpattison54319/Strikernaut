# Architecture

The SwiftUI `GameStore` owns navigation, settings, progression, and save data.
The active game screen owns a `GameSessionModel`, which coordinates a pure
fixed-step `GameSimulation`, the SpriteKit `GoalRushScene`, and `GameAudio`.

The simulation uses normalized coordinates, deterministic random seeds, and
manual geometric collision checks. It has no dependency on SpriteKit, making
combat, rewards, checkpoints, and permanent stat calculations directly
testable. SpriteKit renders the simulation snapshot with perspective scaling,
depth sorting, and reusable node identities.

`RunMode` selects authored Campaign rules or one generated Endless circuit
without forking the renderer. `WorldDefinition` owns a world's level range,
arena, enemy family, boss, rule, and temporary-power pool. Endless derives its
world sequence from `GameContent.worlds`, spends ten waves in each world, then
loops to the first world while all numeric pressure continues growing from the
absolute wave number. Adding another authored world therefore extends the
circuit without adding another run mode or selection path.

Both modes complete waves from simulation-owned enemy roles and defeat quotas;
elapsed time remains only a scheduler for spawn cadence, effects, powers, and
readable boss telegraphs. Endless pauses after every clear for a run-only power
draft. At a world boundary the simulation advances the active world and resets
world-specific runtime state, SpriteKit rebuilds and crossfades the field, and
SwiftUI covers the handoff with a black old-name/new-name slam interstitial.
The next HUD snapshot is deliberately held until the draft dismisses so the
visible wave number animates at kickoff instead of behind the overlay. The live
SwiftUI chrome is split into a shallow opaque status strip and an independent
objective/combo row; score stays in the simulation and result model rather than
occupying gameplay space. Boss health is rendered only above the boss in
SpriteKit, where a world-specific sigil and red bar remain coupled to the
character; bosses use a lower fixed arena lane so that plate and damage numbers
stay clear of the SwiftUI chrome.

Progress is a versioned Codable document in Application Support. Schema 8
stores one Endless best-wave/best-score record; decoding older per-world
records merges their maxima so existing achievements are not lost. Writes are
atomic. Enemy and field-object defeats increase the in-run currency
immediately; there are no pickup entities or collection collision checks.
Earned currency is flushed to permanent progress on pause, draft, result, quit,
and background transitions. Settings use UserDefaults and contain no personal
data.

There are no external packages, accounts, servers, ads, analytics, StoreKit,
CloudKit, or Game Center dependencies.

Engagement systems live in `Domain/Engagement`: pure, testable engines for daily
missions (`MissionCatalog`), streak-based daily rewards (`DailyRewardEngine`),
and achievements (`AchievementCatalog`), all driven by `LifetimeStats` counters
recorded when a run ends. The current progress schema stores those stats
alongside daily-reward state, mission state, unlocked achievements, briefing
history, character unlocks, and the onboarding flag, decoding older saves with
safe defaults. The simulation feeds these systems through combo scoring
(defeats inside a three-second window raise a score multiplier and emit
milestone events) and per-run counters (targets, bosses, best combo, drafted
abilities). Menu effects play through `UIAudio`, which pools three
AVAudioPlayers per sound for low-latency overlap, while reusable SwiftUI juice
(`ConfettiBurst`, `CountUpText`, shimmer, pulse glow, toast banners) celebrates
rewards and achievements with every effect gated on Reduce Motion. The Home
screen acts as a daily hub (reward card plus missions strip), achievement
toasts overlay the root view after runs, and a first-time onboarding flow
introduces the loop (replayable via `--reset-onboarding`).
