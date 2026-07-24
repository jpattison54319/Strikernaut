# Strikernaut Performance Audit

Date: July 22, 2026

## Scope

The audit followed the interaction paths for app launch, home navigation, sheets,
locker changes, campaign and Endless startup, the fixed-step simulation, SpriteKit
rendering, kick/impact feedback, audio and haptics, HUD publication, saving, pause,
and results. It also reviewed every SwiftUI screen for repeated sorting/filtering,
eager large collections, live materials, unbounded animations, and synchronous
work in view construction or button actions.

## Findings and changes

### Critical: gameplay events rebuilt the SwiftUI overlay

`GameSessionModel` published `eventPulse`, `recentEvents`, and a new `HUDState`
whenever any kick or impact occurred. `GameContainerView` observed those values,
so a kick could invalidate the whole overlay in the same frame that SpriteKit was
creating its visual feedback. The HUD also used a live material over the game,
forcing a backdrop sample and blur of the SpriteKit surface during redraws.

- Simulation snapshots and events now stay outside Observation.
- SpriteKit consumes the event batch directly through a lightweight callback.
- HUD publication is capped at a steady 10 Hz instead of being forced by combat.
- The gameplay HUD uses an opaque game surface instead of a live backdrop blur.

### High: entering a run synchronously prepared all audio and haptics

Constructing `GameContainerView` previously activated the audio session, created
the haptic engine and its player pools, decoded 28 effect players, decoded three
music tracks, and started all music before the new game screen could settle.
The app store similarly decoded 24 UI audio players during bootstrap.

- Audio objects now have cheap initializers.
- UI and gameplay audio preparation starts after the first rendered frame.
- Preparation yields between haptic, effect, and music pools.
- If a sound has not finished preparing, it is skipped instead of decoded inside
  a button or combat action.

### High: the renderer repeatedly allocated and traversed scene graphs

Every frame allocated temporary ID arrays/sets, searched each procedural enemy's
node hierarchy for its rig, four limbs, health bar, and lights, and wrote health
bar state even when health had not changed. Balls and complex enemy artwork were
destroyed and rebuilt throughout a run.

- Live-ID sets retain their capacity between frames.
- `TargetRenderNode` caches all hot render-node references once at construction.
- Health visuals update only when the health ratio changes.
- Friendly balls, hostile balls, and enemy/object nodes are pooled and reused.
- Procedural enemy/object hierarchies are now built once per kind and copied from
  cached prototypes. Prototype construction is staged across the early frames,
  before the first scheduled spawn, rather than performed on a live spawn frame.
- The automatic-kick ring is preallocated and recycled instead of recreated for
  every kick.
- Kick animation action graphs are initialized once and reused. Impact sparks are
  staged one node per early frame, then recycled after every hit.
- SpriteKit culls non-visible nodes.

On Level 7, the authored enemy spawn interval and the base automatic-kick
interval are both 1.12 seconds. This made target construction, kick feedback,
and the haptic request land on the same frame and explained the reported
once-per-second cadence. Routine automatic kicks now keep their immediate audio
and visual feedback but do not wake Core Haptics; haptics remain on impacts,
critical hits, rewards, damage, checkpoints, abilities, bosses, and results.

### Medium: navigation and locker actions did avoidable work

Root route changes cross-faded and scaled two full-screen image hierarchies at
once, delaying the perceived destination response. Locker entry and cycling could
also perform bursts of redundant atomic saves while marking visible gear.

- Route swaps are immediate; button press feedback remains local to each control.
- Gear selection and seen-state saves are coalesced over a 150 ms window.

## Reviewed and retained

- The fixed-step simulation is deterministic and already clamps large frame deltas.
- Simulation removal sets retain capacity across frames instead of allocating
  three new hash tables on every update.
- Collision work is bounded by the active target/projectile collections and was
  not the source of the one-second kick hitch in current content.
- Menu collections are small; eager stacks and their derived values are bounded.
- Progress documents are small and atomic saving is retained for run completion,
  purchases, rewards, and other durability-critical actions.
- Background art is device-appropriate at 1024 x 1536. Re-encoding it would reduce
  bundle size but not its decoded GPU memory footprint or address input latency.

## Verification

- Generic iOS Simulator build: passed.
- Unit suite: 66 tests passed, including simulation, persistence, progression,
  rendering contracts, audio assets, and engagement behavior.
- UI suite on iPhone 17 Pro / iOS 26.5: 19 tests passed across home, settings,
  trophies, upgrades, locker, campaign, Endless, onboarding, missions, results,
  daily reward, and pause/resume.
- `git diff --check`: passed.
- Signed Debug and whole-module-optimized Release device builds: passed for an
  iPhone 16 Pro Max running iOS 27.0 beta; both were installed successfully.

The simulator validates behavior and catches large CPU/main-thread regressions,
but final frame pacing, thermal behavior, haptic startup, and GPU hitch counts must
be judged on the single-process Release build on a physical target. The first
physical comparison was contaminated by simultaneous stale Debug and Release
processes after an in-place install; both were terminated before the final run.
An all-process Time Profiler capture also failed to retain GoalRush samples, so it
is not presented as performance evidence.
