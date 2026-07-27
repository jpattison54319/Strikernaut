# Vertical Slice Balance Contract

- Levels 1–3 teach mechanics and remain the onboarding runway.
- A first permanent upgrade is affordable after Level 1.
- World Levels 5, 8, and 10 are intentional organic progression walls. The
  calibration target is one to three losses for an average under-invested build,
  followed by a clear after replay or Endless earnings fund focused upgrades.
  There is no hard rank gate and enemy stats never inspect the player's loadout.
- The Level 5 and Level 8 steps persist through the rest of their world. Level 10
  adds the world's substantially stronger mega-boss.
- Deterministic representative-player tests compare under-budget and recovered
  builds at all nine landmarks. Final retry counts remain a physical-device
  playtest target, not a claim derived from automation.
- Earth occupies Levels 1–10, the Moon occupies Levels 11–20, and Mars occupies
  Levels 21–30. Each world introduces a new enemy/object family and ends with
  its own boss.
- Earth has no world hazard. Moon orbital debris begins at gameplay cadence,
  marks one lane, strikes it, and follows with a second strike. Mars arms a
  Volatile Core after every six standard defeats and on boss-phase changes.
  Shooting a core only neutralizes it; ignoring it damages the player.
- World hazards are always net-negative. They do not slow enemies, enhance balls,
  damage enemies, grant score, or award Training Tokens.
- World hazards do not occupy persistent HUD space. There is no countdown,
  progress bar, or active-effect timer; only the immediate arena telegraph and
  impact feedback are shown.
- Temporary pickup pools are world-specific: Rapid Fire/Split Shot/Heat Seeking
  on Earth, Reverse/Ice/Orbit Shot on the Moon, and Fire/Explosive/Solar Pierce
  on Mars.
- Defeats retain earned Training Tokens. Enemy and equipment rewards are granted
  immediately on destruction, with no pickup step. Replays have smaller
  completion bonuses but full enemy and object rewards. There are no energy
  timers or caps.
- Authored first-clear bonuses total 1,725 on Earth, 3,450 on the Moon, and
  6,405 on Mars. Level 1 still buys one opening rank, but Earth bonuses alone
  cannot buy the first two ranks of every track.
- Base automatic kicks occur every 1.12 seconds. Permanent Tempo ranks shorten
  that interval by 12% multiplicatively, making cadence a major build choice.
- Wide Volley creates a three-ball spread at rank 1, a wider three-ball spread
  at rank 2, and a five-ball spread at rank 3.
- Campaign and Endless waves complete from enemy defeat quotas rather than a
  timer. Escaped enemies damage stamina and are replaced without decrementing
  the objective. Counts grow by level, world, and wave while active crowds use
  device-safety caps.
- Endless health, damage, speed, score, reward pressure, and regular-wave quota
  continue to grow from the wave number without a final authored wave. Spawn
  interval, active count, and simultaneous pack size use device-safety limits;
  numeric enemy strength does not.
- Endless is one continuous circuit: Earth on waves 1–10, Moon on 11–20, Mars
  on 21–30, then back to Earth on 31 while absolute-wave scaling continues.
  The order is sourced from `GameContent.worlds`, so another authored world
  extends the circuit automatically.
- Endless run powers have no rank cap. Cadence approaches a 0.14-second device
  safety floor asymptotically so every Quick Release rank still improves it.
  Boss-only objective waves occur every fifth wave, with phase-gated
  reinforcements that do not count toward completion.
- Equipped gear stacks multiplicatively with permanent Training upgrades before
  either Campaign or Endless begins. World rewards add a shield and
  projectile pierce respectively.

Permanent upgrade costs are centralized in `UpgradeRules`; enemy quotas,
landmark/world steps, and wave pacing are centralized in `CampaignBalance` and
`EndlessRules`, while level content and rewards remain in `GameContent`.
Automated tests verify the economy, formulas, hazard outcomes, objective roles,
and content integrity. Final numeric tuning should follow physical-device play
sessions rather than changing rules inside views.
