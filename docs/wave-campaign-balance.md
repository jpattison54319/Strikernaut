# Enemy-Count Wave Balance

## Completion contract

Campaign and Endless waves end from combat outcomes, never elapsed time.

- A regular wave completes when its quota-role enemy defeat count reaches the
  authored quota.
- An enemy that reaches the player still deals stamina damage, but does not
  reduce the remaining count. The spawn system replaces it.
- Field objects, power targets, Volatile Cores, bosses, and boss
  reinforcements never increment the regular quota.
- Campaign keeps three waves in world levels 1–3, four in 4–7, and five in
  8–10. Only the final wave is a boss wave.
- A non-world-final level ends with a mini-boss. Levels 10, 20, 30, 40, 50,
  60, and 70 end with the current world's mega-boss.
- Endless has no maximum wave. Every fifth wave is a boss wave; the HUD shows
  only the current wave number.

`LevelDefinition.referenceDuration` is retained only as an offline comparison
target. It is not read by the runtime completion path.

## Quota formulas

`CampaignBalance` is the source of truth for Campaign quotas. For a regular
wave:

```text
worldIndex = position in GameContent.worlds (Earth 0 through Neptune 6)
base = 18 + 2 × (globalLevel - 1) + 3 × worldIndex
quota = round(base × (1 + 0.18 × (wave - 1)))
```

This produces opening quotas of 18 on Earth Level 1, 41 on Moon Level 11, 64 on
Mars Level 21, 82 on Mars Level 30, and 174 on Neptune Level 70. Every later
regular wave adds 18% before rounding. The final boss objective is always one.

`EndlessRules` uses:

```text
chapterIndex = floor((wave - 1) / 10)
regularQuota = 18 + (wave - 1) + 2 × chapterIndex
bossQuota = 1 when wave is divisible by 5
```

The linear count curve is layered with uncapped enemy health, damage, and speed
growth, so late Endless pressure keeps rising without turning crowd size into
the only difficulty mechanism.

## Endless world circuit

Endless is a single run, not a per-world selection:

```text
Waves  1–10  Earth
Waves 11–20  Moon
Waves 21–30  Mars
Waves 31–40  Jupiter
Waves 41–50  Saturn
Waves 51–60  Uranus
Waves 61–70  Neptune
Wave      71 Earth again, with all absolute-wave scaling preserved
```

`EndlessRules.worldSequence` is derived from `GameContent.worlds`; a future
world extends the circuit to another ten-wave chapter before it loops. At a
boundary, the new snapshot changes the complete world ruleset: arena and
geometry, enemy/object pools, boss, rule state, temporary powers, colors, and
faction emblem. A black interstitial carries the old name down and offscreen,
drops the new name from above, and lands it with an impact treatment while the
SpriteKit field is rebuilt underneath.

## Crowd and spawn safety

Campaign crowd size grows aggressively but remains explicitly bounded:

```text
Campaign pack =
    min(
        16,
        1
        + floor((globalLevel - 1) / 9)
        + landmarkTier
        + (wave - 1)
    )

Campaign enemy cap =
    min(
        48,
        6
        + floor((globalLevel - 1) / 2)
        + landmarkTier
        + 2 × (wave - 1)
    )

Campaign hostile-projectile cap =
    min(
        10,
        3
        + floor((globalLevel - 1) / 15)
        + landmarkTier
        + floor((wave - 1) / 2)
    )

Endless cap = min(18, 6 + floor((wave - 1) / 4))
```

Campaign calculates a continuously shrinking per-enemy interval, then releases
that workload in pulses:

```text
pressureIndex =
    (globalLevel - 1) + 1.5 × cumulativeLandmarks

perEnemyInterval =
    max(
        1.55 × 0.9745^pressureIndex,
        0.60 × 0.9965^pressureIndex
    )
    × 0.91^(wave - 1)

pulseInterval = max(0.32, perEnemyInterval × packSize)
```

The pack multiplier changes presentation, not average workload. Level 1 opens
with one enemy per pulse, Level 20 with five, Uranus with six, and Neptune's
fourth regular wave with thirteen. An underpowered late-game build can fill the
48-enemy field; a prepared build destroys the same pulses before that backlog
forms. Endless cadence still approaches a 0.25-second floor and its pack size
tops out at five. All spawning respects the remaining active and quota slots,
preventing over-spawn at the end of a wave.

## Strength and upgrade budget

Enemy count is only one axis. Campaign regular health is derived from the
player-independent reference build:

```text
averageEnemyHP =
    referenceBallDamage
    × authoredLevelFraction
    × 1.14^(wave - 1)
```

The authored reference finale ranks are 3, 5, 7, 9, 11, 13, and 15. World
Levels 5 and 8 jump toward the next reference rank, and Level 10 derives boss
health from reference DPS and an increasing 50-to-59-second target. Incoming
damage, movement speed, attack cadence, hostile projectile speed, quota,
per-enemy arrival pressure, and average enemy health all increase independently
from one level to the next. The complete formulas and numerical economy outcomes
are maintained in `docs/balancing.md`.

- Expected Campaign draft offense grows by `1.14^(draft count)`.
- Permanent Impact, Tempo, Flight, and Spin continue changing damage, cadence,
  travel time, and critical tiers without loadout-based rubber-banding.
- Conditioning increases real hit capacity because the smooth single-source
  ceiling stays at 25 baseline stamina instead of rising with upgraded stamina.
- Endless health and damage are uncapped functions of wave number. Quick
  Release approaches its 0.14-second safety floor asymptotically, so additional
  ranks still improve an advanced build.
- Boss reinforcements grant combat feedback and score but no Training Tokens,
  preventing infinite boss-stalling income.
- Campaign enemies retain full token rewards. Higher permanent-upgrade prices
  absorb the extra horde income.

The fixed authored quota deliberately does not inspect the player's actual
loadout. Strong builds clear faster; weaker builds face more escape pressure.
This keeps upgrades truthful and avoids silently moving the target after a
purchase.

## Harmful world cadence

Earth has no world hazard. Every later world's effect is strictly negative.
Moon and Mars establish the cadence contract:

- Moon schedules its first orbital-debris strike after ten seconds of active
  play. A second strike follows three seconds later; the pair repeats every
  sixteen seconds. Each strike marks one arena lane for 1.25 seconds, then deals
  16 base damage to a player who remains in it. Debris never slows enemies or
  projectiles and never enhances player shots.
- Mars arms a Volatile Core after every sixth standard enemy defeat and at
  mega-boss phase changes. A shot removes only the core: it deals no area damage,
  advances no objective, charges no ability, and grants no score or Training
  Tokens. An ignored core detonates for 18 base damage.

Authored base damage is multiplied by current wave damage. World cadence never
adds a persistent SwiftUI countdown, progress bar, badge, or active timer. The
only warning is the immediate lane/core treatment rendered inside the arena,
followed by impact feedback. Reduce Motion and Reduce Flashes continue to
restrain those treatments without removing the warning.

## Boss waves

The boss spawns immediately and is the sole completion objective. Regular
quota spawning stops.

- Bosses occupy a fixed lower arena lane so their complete silhouette,
  overhead health plate, and rising damage numbers remain below the compact
  status/objective chrome on every world.
- The only boss-health display is attached above the boss in SpriteKit: a
  persistent red bar with the current world's abstract boss-faction sigil.
  Standard targets retain their smaller color-changing health bars.
- Health transitions at approximately 67% and 34% queue two reinforcement
  pulses. Adds never count toward the displayed one-enemy objective.
- A new pulse waits until the prior pulse is defeated and then enforces a
  three-second quiet gap.
- The first boss-wave power target appears after seven seconds. Later targets
  are scheduled every sixteen seconds when no uncollected target is active.
- Ice or stun pauses boss movement, hostile attacks, and the start of a new
  signature attack. Existing telegraphs still resolve so a warning cannot be
  erased after it appears.

World-boss signatures are deterministic simulation hazards:

- Titan Keeper: locks the player's current horizontal position, telegraphs an
  orbital corridor for 1.75 seconds, then fires for 1.25 seconds for 24 base
  damage. It starts after six seconds and repeats every ten.
- Lunar Warden: marks two of three lanes for 1.6 seconds, leaving one readable
  safe lane, then fires for 1.2 seconds for 22 base damage. It repeats every
  eleven seconds.
- Mars Colossus: snapshots the player's position for three markers spaced 0.45
  seconds apart. Each marker telegraphs for 1.4 seconds and impacts for 0.3
  seconds for 18 base damage. The sequence repeats every ten seconds.

Each marker can damage the player once. Campaign or Endless wave damage
multipliers are applied after the authored base damage.

## Objective HUD

The opaque SwiftUI status strip publishes at 10 Hz. Its compact heart bar is
kept below one third of the strip width, with Tokens, shields, and the 44-point
Pause control occupying the remaining space. Score is intentionally absent
during play and remains available in the result. World-effect state is also
intentionally absent; only temporary beneficial pickups retain a HUD timer.

The wave objective sits independently just below that strip, left-aligned
opposite the bare combo count. It uses a reduced slanted comic plate:

```text
Campaign:  2/5 | [world enemy emblem] 31
Endless:    12 | [world enemy emblem] 31
Boss:      5/5 | [world boss emblem]   1
```

Every authored world has an original abstract faction sigil and a more imposing
boss-faction variant. The whole plate is one
accessibility element, announcing the current wave and remaining enemy count.
Enemy-count decrements use a rolling numeric transition, direction-aware
movement, a short scale punch, glow, and spring settle. The advanced wave value
is held through the intermission and published when the draft dismisses, so the
wave roll is visible at kickoff rather than hidden behind the draft. Serial
guards keep rapid decrements from leaving the counter in a stale animation
state. Reduce Motion uses opacity without travel or scale.

Music pressure follows objective completion rather than elapsed time. Boss
health is not duplicated in the SwiftUI HUD; its in-world red sigil plate is the
single health source for phase changes and reinforcement timing.

## Temporary power targets

Regular waves schedule one zig-zag power target at half quota. Boss waves use
the seven/ sixteen-second schedule above. Destroying a target activates the
world-specific temporary ball effect; missing one never changes the enemy
objective.

Only one temporary power is active at a time. A new pickup replaces the current
power and resets the circular HUD timer.

## Verification

Unit coverage pins the formulas, active caps, kill-only completion, escape
replacement, objective-role exclusions, final-wave bosses, Endless fifth-wave
bosses, reinforcement gaps, power-target timing, signature telegraphs, one-hit
hazards, strict level-to-level pressure growth, horde pulse sizes, hostile
projectile limits, and HUD values. Deterministic seeded playtests compare
under-budget and recovered builds at every world finale and prove that a
Moon-ready rank-5 build cannot skip to Uranus while a recovered build can win.
UI coverage asserts the combined Campaign, boss, and Endless objective labels
and the absence of a persistent world-effect HUD. Simulator and physical-device
play remain necessary for visual readability, real frame pacing with 48 active
enemies, and final retry/fun tuning.
