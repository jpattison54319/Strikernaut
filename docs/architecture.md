# Architecture

The SwiftUI `GameStore` owns navigation, settings, progression, and save data.
The active game screen owns a `GameSessionModel`, which coordinates a pure
fixed-step `GameSimulation`, the SpriteKit `GoalRushScene`, and `GameAudio`.

The simulation uses normalized coordinates, deterministic random seeds, and
manual geometric collision checks. It has no dependency on SpriteKit, making
combat, rewards, checkpoints, and permanent stat calculations directly
testable. SpriteKit renders the simulation snapshot with perspective scaling,
depth sorting, and reusable node identities.

`RunMode` selects authored Campaign rules or generated Endless rules without
forking the renderer. `WorldDefinition` owns a world's level range, arena,
enemy family, boss, and clear reward. Endless scaling is calculated from the
current wave rather than stored in a finite table, and pauses after each cleared
wave for a run-only power draft. `GearCatalog` is the single source of truth for
unlock source, slot, visible effect copy, simulation modifiers, and full-set
bonuses. The Locker and gameplay scene both render the same equipped loadout.

Progress is a versioned Codable document in Application Support; the version 2
decoder supplies safe defaults for version 1 saves. It includes per-world
Endless records, earned gear, and the equipped five-slot loadout. Writes are
atomic. Enemy and equipment defeats increase the in-run currency immediately;
there are no pickup entities or collection collision checks. Earned currency is
flushed to permanent progress on pause, draft, result, quit, and background
transitions. Settings use UserDefaults and contain no personal data.

There are no external packages, accounts, servers, ads, analytics, StoreKit,
CloudKit, or Game Center dependencies.

Engagement systems live in `Domain/Engagement`: pure, testable engines for daily
missions (`MissionCatalog`), streak-based daily rewards (`DailyRewardEngine`),
and achievements (`AchievementCatalog`), all driven by `LifetimeStats` counters
recorded when a run ends. `PlayerProgress` schema version 3 stores those stats
alongside daily-reward state, mission state, unlocked achievements, and the
onboarding flag, decoding older saves with safe defaults. The simulation feeds
these systems through combo scoring (defeats inside a three-second window raise
a score multiplier and emit milestone events) and per-run counters (targets,
bosses, best combo, drafted abilities). Menu effects play through `UIAudio`,
which pools three AVAudioPlayers per sound for low-latency overlap, while
reusable SwiftUI juice (`ConfettiBurst`, `CountUpText`, shimmer, pulse glow,
toast banners) celebrates rewards and achievements with every effect gated on
Reduce Motion. The Home screen acts as a daily hub (reward card plus missions
strip), achievement toasts overlay the root view after runs, and a first-time
onboarding flow introduces the loop (replayable via `--reset-onboarding`).
