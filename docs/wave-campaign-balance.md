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
- A non-world-final level ends with a mini-boss. Levels 10, 20, and 30 end with
  the current world's mega-boss.
- Endless has no maximum wave. Every fifth wave is a boss wave; the HUD shows
  only the current wave number.

`LevelDefinition.referenceDuration` is retained only as an offline comparison
target. It is not read by the runtime completion path.

## Quota formulas

`CampaignBalance` is the source of truth for Campaign quotas. For a regular
wave:

```text
worldIndex = Earth 0, Moon 1, Mars 2
base = 18 + round(0.9 × (globalLevel - 1)) + 3 × worldIndex
quota = round(base × (1 + 0.12 × (wave - 1)))
```

This produces an 18-enemy opening on Earth Level 1, 30 on Moon Level 11, 42 on
Mars Level 21, and 50 on Mars Level 30. Each later regular wave in a level adds
12% before rounding. The final boss objective is always one.

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
Wave      31 Earth again, with all absolute-wave scaling preserved
```

`EndlessRules.worldSequence` is derived from `GameContent.worlds`; a future
world extends the circuit to another ten-wave chapter before it loops. At a
boundary, the new snapshot changes the complete world ruleset: arena and
geometry, enemy/object pools, boss, rule state, temporary powers, colors, and
faction emblem. A black interstitial carries the old name down and offscreen,
drops the new name from above, and lands it with an impact treatment while the
SpriteKit field is rebuilt underneath.

## Crowd and spawn safety

Counts can rise indefinitely while active enemies remain bounded:

```text
Campaign cap = min(8, 4 + worldIndex + floor((wave - 1) / 2))
Endless cap = min(10, 5 + chapterIndex)
```

Campaign spawn cadence is:

```text
1.55 × 0.985^(globalLevel - 1)
     × 0.90^worldIndex
     × 0.96^landmarkTier
     × 0.91^(wave - 1)
```

It has a 0.60-second safety floor. Endless cadence approaches a 0.32-second
floor and its pack size tops out at four. A spawn is allowed only when both an
active slot and an unspawned quota slot remain, preventing over-spawn at the end
of a wave.

## Strength and upgrade budget

Enemy count is only one axis. Campaign health uses:

```text
world health base = Earth 0.92, Moon 1.60, Mars 2.80
level health      = world base × 1.03^(worldLevel - 1)
landmark tier     = 0 on 1–4, 1 on 5–7, 2 on 8–10
wave health       = level health × 1.08^landmarkTier × 1.15^(wave - 1)
```

Level 1 keeps a separate forgiving `0.78` opening multiplier. Campaign damage
uses:

```text
world damage base = Earth 1.00, Moon 1.34, Mars 1.75
wave damage       = world base
                  × (1 + 0.015 × (worldLevel - 1))
                  × 1.025^landmarkTier
                  × 1.07^(wave - 1)
```

The same landmark tiers also make spawn cadence 4% faster. This makes World
Levels 5 and 8 persistent steps instead of one-level spikes; World Level 10
adds the mega-boss. The Moon and Mars entries each jump opening-wave health by
more than 14%, damage by roughly 10% or more, speed by at least 8%, and cadence
again. Their harmful world rules add another pressure axis.

- A wave raises health by 15%, slightly ahead of the 14% expected offensive
  value of one average draft choice. Damage rises 7%, speed rises 5%, and spawn
  cadence contracts 9%.
- Permanent Impact, Tempo, Flight, and Spin continue changing damage, cadence,
  travel time, and critical tiers.
- Endless health and damage are uncapped functions of wave number. Quick
  Release approaches its 0.14-second safety floor asymptotically, so additional
  ranks still improve an advanced build.

The fixed authored quota deliberately does not inspect the player's actual
loadout. Strong builds clear faster; weaker builds face more escape pressure.
This keeps upgrades truthful and avoids silently moving the target after a
purchase.

## Harmful world cadence

Earth has no world hazard. Moon and Mars effects are strictly negative:

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

Earth, Moon, and Mars each have an original image-generated abstract faction
sigil and a more imposing boss-faction variant. The whole plate is one
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
hazards, and HUD values. A deterministic seeded playtest compares under-budget
and recovered builds at World Levels 5, 8, and 10 in all three worlds. UI
coverage asserts the combined Campaign, boss, and Endless objective labels and
the absence of a persistent world-effect HUD. Simulator and physical-device play
remain necessary for visual readability, real frame pacing, and final retry/fun
tuning.
