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
