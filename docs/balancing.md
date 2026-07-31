# Progression and Difficulty Formula Contract

This document is the numeric source of truth for Strikernaut's Campaign,
Endless, permanent-upgrade, and reward curves. Runtime formulas live in
`BalanceFormulas`, `CampaignBalance`, `EndlessRules`, and `UpgradeRules`.
Views may present those values but must not own balance constants.

The design goal is:

- permanent upgrades always make the player meaningfully stronger;
- replaying early Campaign and early Endless becomes visibly easier;
- Campaign has no hard rank gates or loadout-based rubber-banding;
- every Campaign level raises durability, damage, speed, quota, effective spawn
  pressure, hostile attack cadence, and projectile speed;
- Campaign waves arrive as increasingly large horde pulses while active enemies
  and hostile projectiles retain explicit readability limits;
- World Levels 5 and 8 are persistent pressure steps, and Level 10 is a boss
  step;
- the expected Campaign path deliberately underfunds a balanced build after
  Earth, leaving a gap worth roughly two or three appropriately deep Endless
  runs;
- Endless difficulty and rewards remain uncapped, but reward multipliers grow
  sublinearly so high-wave currency cannot outrun the permanent economy.

All token projections below exclude optional destructible objects, missions,
daily rewards, failed-run earnings, and Golden Goal. They are a repeatable
progression floor, not a promise of an exact run payout.

## Permanent player power

For a permanent rank `r`:

```text
maximum stamina       H(r) = 100 × (1 + 0.08r)
movement response     M(r) =   8 × (1 + 0.07r)
ball damage           D(r) =  10 × (1 + 0.10r)
ball speed            V(r) = 0.88 × (1 + 0.06r)
critical power        C(r) = 0.05 + 0.03r
```

Critical overflow creates guaranteed tiers plus a fractional tier. Its expected
damage multiplier is therefore exactly `1 + C(r)`, even after critical power
exceeds 100%.

Tempo is multiplicative through rank 5, then approaches a device-safe floor:

```text
openingCooldown(r) = 1.12 × 0.88^min(r, 5)

kickCooldown(r) =
    openingCooldown(r)                                      when r <= 5
    0.12 + (openingCooldown(r) - 0.12) × 0.88^(r - 5)      when r > 5
```

A balanced equal-rank build's expected single-target automatic-kick DPS is:

```text
DPS(r) = D(r) × (1 + C(r)) / kickCooldown(r)
```

Campaign difficulty uses that formula only with an authored reference rank. It
never reads the player's actual ranks. A stronger real build therefore clears
faster instead of causing enemies to scale up behind the scenes.

## Character ability charge

Character supers use objective-normalized charge instead of a fixed number of
defeats. Let `Q` be the current regular-wave enemy quota. On a Campaign boss
wave, `Q` is the preceding regular-wave quota; Endless always uses its authored
quota for the current wave.

```text
enemyDefeatCharge(Q) = 100 × 1.25 / Q
fieldObjectCharge(Q) = 0.25 × enemyDefeatCharge(Q)

bossDamageCharge =
    50 × min(effectiveDamage, remainingBossHP) / maximumBossHP
```

A regular wave therefore contains 125 points of potential defeat charge, so
the first full super becomes available near 80% objective progress and the
theoretical cadence remains 1.25 supers per wave at every Campaign level and
Endless wave. Standard boss-wave reinforcements grant the same defeat charge,
while damage to the boss contributes up to another 50 points across its full
health bar. Actual cadence is slightly lower because defeats caused by a
character super grant zero charge.

Boss damage from normal kicks, special balls, and damage-over-time effects can
contribute at most 50 points across the full boss health bar. Super-origin
damage, boss defeats, boss reinforcements, power-ups, and Volatile Cores grant
zero charge. This prevents high-density waves and renewable reinforcements from
turning the super into a basic attack.

## Permanent upgrade prices

Ranks 0 through 4 use the opening marginal costs:

```text
[100, 275, 600, 1,050, 1,800]
```

For current rank `r >= 5`, the next marginal cost is linear and rounded to the
nearest 25:

```text
nextCost(r) =
    25 × round((1,800 × (1 + 0.14 × (r - 5))) / 25)
```

Because the marginal cost is linear, cumulative post-mastery spending is
quadratic. Ranks remain unlimited, but currency can no longer buy an unlimited
number of equally priced upgrades. Prestige payments of 2,600 are additionally
required before crossing ranks 10, 20, 50, 100, and 200.

The saved global rank remains the combat input. The upgrade card presents a
badge-local level after prestige:

```text
badgeStart(p) = [0, 10, 20, 50, 100, 200][clamp(p, 0, 5)]
visibleLevel(r, p) = max(0, r - badgeStart(p))
```

Here `p` is the number of earned badges. Rank 10 therefore reads `Level 10`
before the Bronze payment and `Bronze 0` afterward; rank 20 becomes `Silver 0`
after the Silver payment. This reset is visual only and never reduces damage,
cooldown, stamina, or any other upgrade effect. Each progress dot represents
one actual global rank toward the next badge, so the five segments contain
10, 10, 30, 50, and 100 dots. Diamond has no next badge and therefore no dot
segment; its local level continues upward without a cap.

Representative total investment for one track, including prestige:

| Rank | One track | Six balanced tracks |
| ---: | ---: | ---: |
| 3 | 975 | 5,850 |
| 5 | 3,825 | 22,950 |
| 7 | 7,675 | 46,050 |
| 9 | 12,525 | 75,150 |
| 11 | 20,975 | 125,850 |
| 13 | 27,850 | 167,100 |
| 15 | 35,750 | 214,500 |

These are comparison budgets, not mandatory gates. A player who specializes in
Impact and Tempo can beat a balanced six-track budget, while a defensive build
trades clear speed for survivability.

## Campaign completion rewards

For zero-based `worldIndex`, one-based `worldLevel`, and `boss = 1.25` only on a
world finale:

```text
firstClear =
    roundTo5(
        100
        × 1.55^worldIndex
        × (1 + 0.06 × (worldLevel - 1))
        × boss
    )

replay = roundTo5(0.42 × firstClear)
```

Enemy values are centralized in `CombatBalance`. Expected mandatory combat
income for a level is:

```text
regular combat =
    sum over regular waves(
        quota(wave) × mean(tokenValue(level enemy pool))
    )

final reward =
    5 × tokenValue(miniBoss)     for Levels 1-9 in each world
    tokenValue(worldBoss)        for Level 10 in each world
```

Boss reinforcements grant score, combo, and target-defeat credit, but zero
character charge or Training Tokens. This removes both super and currency
farming from renewable boss support in Campaign and Endless.

The expected first-pass results are:

| World end | First-clear bonuses in world | Cumulative Campaign income | Reference rank | Balanced cost | Intended gap | Baseline Endless run used for comparison | Runs to close gap |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Earth 10 | 1,310 | 7,246 | 3 | 5,850 | 1,396 surplus | — | — |
| Moon 20 | 2,030 | 19,514 | 5 | 22,950 | 3,436 | Wave 10: 1,196 | 2.87 |
| Mars 30 | 3,140 | 37,121 | 7 | 46,050 | 8,929 | Wave 20: 3,502 | 2.55 |
| Jupiter 40 | 4,865 | 60,723 | 9 | 75,150 | 14,427 | Wave 30: 6,791 | 2.12 |
| Saturn 50 | 7,545 | 91,265 | 11 | 125,850 | 34,585 | Wave 40: 11,173 | 3.10 |
| Uranus 60 | 11,705 | 130,225 | 13 | 167,100 | 36,875 | Wave 50: 16,842 | 2.19 |
| Neptune 70 | 18,145 | 179,904 | 15 | 214,500 | 34,596 | Wave 60: 24,025 | 1.44 |

The full first-clear bonus total is 48,740. Expected mandatory combat adds
approximately 131,164, for 179,904 through Level 70. The replay-bonus total is
20,460. Regular enemies retain their full authored token values: the economy
absorbs the much larger hordes through higher upgrade prices, not reduced
per-enemy rewards.

The table explains the intended feel: Earth establishes the build, then later
worlds increasingly ask the player to replay, specialize, or spend time in
Endless. Optional object rewards and failed attempts make the real gap less
rigid. No level checks the player's token balance or blocks Start.

## Campaign reference ranks and walls

World-finale reference ranks are:

```text
endRank(worldIndex) = 3 + 2 × worldIndex
                    = [3, 5, 7, 9, 11, 13, 15]
```

Earth starts at rank zero. Each later world starts 0.15 rank above the prior
finale so even a world opener is strictly harder than the level before it. The
reference rank is interpolated as:

```text
targetRank = startRank + (endRank - startRank) × f(worldLevel)

f(1...10) =
    [0.00, 0.08, 0.16, 0.25, 0.43, 0.52, 0.62, 0.79, 0.89, 1.00]

cumulativeLandmarks =
    3 × completedWorldCount
    + count(worldLevel >= each of [5, 8, 10])
```

Every entry is larger than the one before it. Levels 5 and 8 take larger steps
to form organic upgrade walls; Level 10 adds the third wall through a mega-boss
and the final cumulative-landmark increment.

## Campaign regular enemies and hordes

Regular-enemy durability is based on the non-critical damage of the authored
reference build. It is independent of spawn density, so larger/faster hordes do
not silently make each enemy weaker:

```text
referenceBallDamage = 10 × (1 + 0.10 × targetRank)

openingDamageFraction =
    0.62 + 0.03 × (globalLevel - 1)                    for Levels 1...4
    0.94 + 0.0003 × (globalLevel - 5)
         + 0.0003 × cumulativeLandmarks                afterward

averageEnemyHP =
    referenceBallDamage
    × (openingDamageFraction + 0.05 × (wave - 1))
    × 1.14^(wave - 1)

healthMultiplier = averageEnemyHP / meanBaseEnemyHP
```

The opening fraction stays just below one reference non-critical kick. This
keeps the horde focused on aiming, cadence, pierce, volleys, and supers rather
than damage-sponge cleanup. Every later level still raises average durability,
and every later wave compounds durability beyond the expected 14% value of one
offensive draft.

Campaign count and pulse formulas are:

```text
quotaBase = 18 + 2 × (globalLevel - 1) + 3 × worldIndex
quota(wave) = round(quotaBase × (1 + 0.18 × (wave - 1)))

packSize =
    min(
        16,
        1
        + floor((globalLevel - 1) / 9)
        + landmarkTier
        + (wave - 1)
    )

activeEnemyCap =
    min(
        48,
        6
        + floor((globalLevel - 1) / 2)
        + landmarkTier
        + 2 × (wave - 1)
    )
```

Level 1 opens with one enemy per pulse. Level 20 opens with five, Uranus opens
with six, and Neptune's fourth regular wave releases thirteen at once. The
active cap rises from 6 to 48, allowing an underpowered build to accumulate the
large on-field backlog that defines the intended horde pressure.

Pulse timing preserves an independently increasing per-enemy arrival rate:

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

Multiplying by pack size turns a continuous trickle into readable horde pulses
without reducing total arrival pressure. Enemy stats, quotas, packs, and
intervals never inspect the live loadout. Replaying early content with a
stronger build therefore reduces escape pressure exactly as the upgrade UI
promises.

## Campaign bosses and incoming damage

Campaign boss health is derived directly from reference DPS:

```text
bossHP =
    DPS(targetRank)
    × 1.14^(wave - 1)
    × targetSeconds

miniBoss targetSeconds =
    7
    + 0.16 × (globalLevel - 1)
    + 1.5 × landmarkTier
    + 0.5 × max(0, wave - 3)

megaBoss targetSeconds =
    50 + 1.5 × worldIndex
```

Bosses also receive more support:

```text
supportCapacity =
    min(6, 2 + floor(worldIndex / 2) + landmarkTier)

supportInterval =
    max(1.75, 3.6 × attackCadenceMultiplier)
```

Campaign movement and aggression rise independently:

```text
openingSpeed =
    0.80                                                     at Level 1
    1.0065^(globalLevel - 2) × 1.008^cumulativeLandmarks    afterward

speedMultiplier =
    openingSpeed × (1 + 0.04 × (wave - 1))

attackCadenceMultiplier =
    1 / (
        1
        + 0.006 × (globalLevel - 1)
        + 0.015 × cumulativeLandmarks
        + 0.04 × (wave - 1)
    )

hostileProjectileSpeed =
    1
    + 0.006 × (globalLevel - 1)
    + 0.012 × cumulativeLandmarks
    + 0.035 × (wave - 1)
```

Attack cadence multiplies authored intervals, so a smaller result means more
frequent attacks. A mixed horde cannot produce an unreadable projectile wall:

```text
hostileProjectileCap =
    min(
        10,
        3
        + floor((globalLevel - 1) / 15)
        + landmarkTier
        + floor((wave - 1) / 2)
    )
```

Incoming damage is solved against a fixed 100-stamina baseline. No exposure,
spawn-density, or live-loadout term is allowed to reduce it:

```text
targetEffectiveFraction =
    min(
        0.245,
        0.075
        + 0.002 × (globalLevel - 1)
        + 0.0007 × cumulativeLandmarks
        + 0.005 × (wave - 1)
    )

targetEffectiveDamage = 100 × targetEffectiveFraction
L = 25
rawReferenceDamage = -L × ln(1 - targetEffectiveDamage / L)
damageMultiplier = rawReferenceDamage / 14
```

Runtime sources then use a smooth ceiling:

```text
runtimeLimit = 0.25 × min(maximumStamina, 100)
effectiveDamage =
    runtimeLimit × (1 - exp(-rawDamage / runtimeLimit))
```

The derivative at zero is 1, so small hits stay near their authored value. A
single extreme source can approach 25 baseline stamina but cannot exceed it.
Conditioning increases the number of hits the player can actually take without
also increasing this ceiling. Against the same rank-5 Moon build, a Uranus
runner now deals more than twice its Moon-opening damage; the old one-damage
far-skip failure cannot recur.

The developer unlock changes only level and character accessibility. It grants
no Training Tokens, permanent ranks, or hidden combat stats. Debug-selecting a
late planet therefore exercises the same underpowered difficulty as a normal
player who somehow skipped progression.

## Endless difficulty and tokens

Endless partially responds to the permanent combat power present when the run
starts. Let `S` be the checkpointed `PlayerStats` for the run:

```text
rawOffense(S) =
    (ballDamage / 10)
    × ((1 + criticalPower) / 1.05)
    × (1.12 / kickCooldown)

offenseFactor(S)  = sqrt(max(1, rawOffense(S)))
survivalFactor(S) = sqrt(max(1, maximumStamina / 100))
```

The square root absorbs only half of the multiplicative starting advantage.
Permanent upgrades and the equipped relic therefore remain meaningful without
letting an advanced profile enter Endless at wave-one pressure.

For `i = max(0, wave - 1)`, Endless difficulty remains truly uncapped:

```text
health(wave, S) =
    offenseFactor(S) × 1.085^i × (1 + 0.04i)

damage(wave, S)         = survivalFactor(S) × 1.05^i
speed(wave)             = 1 + 0.11 × log2(wave + 1)
attackInterval(wave)    = 1 / (1 + 0.025i)
hostileShotSpeed(wave)  = 1 + 0.018i
spawnInterval(wave)     = max(0.22, 0.95 × 0.965^i)
quota(wave)             = 18 + floor(1.5i) + 3 × floor(i / 10)
packSize(wave)          = min(6, 1 + floor(i / 7))
activeEnemies(wave)     = min(24, 7 + floor(i / 3))
hostileShots(wave)      = min(12, 4 + floor(i / 5))
```

Enemy health, damage, movement, attack cadence, and projectile speed have no
terminal wave. Spawn, pack, active-enemy, and hostile-projectile limits protect
readability and frame pacing rather than serving as the only difficulty axes.

Endless run upgrades are also uncapped, but continuous offensive effects begin
diminishing after rank 5:

```text
effectiveRank(r) = r
    when r <= 5

effectiveRank(r) =
    5 + 5 × ln(1 + (r - 5) / 5)
    when r > 5
```

Power Drive uses `1.25^effectiveRank`. Quick Release uses `effectiveRank` for
its theoretical cadence and overflow damage. Curler steering, Second Wind
recovery, Meteor Strike damage, and Wide Volley's secondary-projectile mastery
use the same curve. Through Ball and Wide Volley still add one visible target
or projectile per rank, and Clean Sheet still grants one block per selection.
Golden Goal remains logarithmic, Gravity Boots remains hyperbolic, and special
balls retain their square-root scaling. Every rank therefore changes gameplay
without preserving the former exponential or roughly quadratic runaway.

Every enemy, object, boss, and wave-clear token award passes through:

```text
waveRewardMultiplier(wave) =
    (1 + (wave - 1) / 10)^0.32

goldenGoalMultiplier(rank) =
    1 + 0.42 × ln(1 + rank)

awardedTokens =
    round(
        baseValue
        × playerTokenMultiplier
        × waveRewardMultiplier
        × goldenGoalMultiplier
    )
```

The wave-clear base is `max(4, 2 × wave)`. Both reward multipliers are
uncapped. Their sublinear/logarithmic shapes prevent exponential combat
difficulty from being paired with runaway currency inflation.

Baseline expected mandatory Endless totals are approximately:

| Through wave | Rank 0 Golden Goal | Rank 5 Golden Goal |
| ---: | ---: | ---: |
| 10 | 1,267 | 2,254 |
| 30 | 7,777 | 13,460 |
| 70 | 39,624 | 69,048 |
| 100 | 95,126 | 166,297 |
| 200 | 467,656 | 819,504 |

Optional objects increase actual totals. Reinforcements remain token-neutral.

## Validation contract

Automated tests must continue to pin:

- upgrade marginal and cumulative costs, including prestige;
- Campaign reward totals and the one-to-four Endless-run world gaps;
- strict level-to-level increases across every continuous Campaign pressure
  axis;
- horde pack growth, quota growth, active-enemy limits, and hostile-projectile
  limits;
- reference-rank and boss-health escalation through all seven worlds;
- Levels 5, 8, and 10 as persistent authored pressure landmarks;
- uncapped/sublinear Endless rewards and diminishing Golden Goal returns;
- token-neutral boss reinforcements;
- quota-normalized character charge and zero-charge reinforcements;
- the smooth baseline-stamina incoming-damage asymptote;
- debug unlocks granting access without granting permanent power;
- seeded under-budget versus recovered world-finale runs;
- a rank-5 Moon build losing every Uranus skip seed while a recovered build
  retains a winning seed.

Automation establishes consistency, not fun. Final retry counts, aiming feel,
hazard readability, and perceived grind require physical-device play sessions.
Tune the named coefficients in the formula owners, update this document and the
tests together, and never hide compensating constants inside a view.
