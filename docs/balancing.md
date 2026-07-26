# Vertical Slice Balance Contract

- Levels 1–3 teach mechanics and are beatable without upgrades.
- A first permanent upgrade is affordable after Level 1.
- Levels 4–6 reward focused upgrades but do not intentionally require replay.
- Levels 7–9 may require one or two replays for an average player.
- The Titan Keeper expects a developed build but has readable, avoidable attacks.
- Earth occupies Levels 1–10, the Moon occupies Levels 11–20, and Mars occupies
  Levels 21–30. Each world introduces a new enemy/object family and ends with
  its own boss.
- Earth has no world modifier. The Moon alternates between normal gravity and
  a six-second zero-G phase. Mars spawns a Volatile Core after every six
  standard defeats and on boss-phase changes.
- Temporary pickup pools are world-specific: Rapid Fire/Split Shot/Heat Seeking
  on Earth, Reverse/Ice/Orbit Shot on the Moon, and Fire/Explosive/Solar Pierce
  on Mars.
- Defeats retain earned Training Tokens. Enemy and equipment rewards are granted
  immediately on destruction, with no pickup step. Replays have smaller
  completion bonuses but full enemy and object rewards. There are no energy
  timers or caps.
- Base automatic kicks occur every 1.12 seconds. Permanent Tempo ranks shorten
  that interval by 12% multiplicatively, making cadence a major build choice.
- Wide Volley creates a three-ball spread at rank 1, a wider three-ball spread
  at rank 2, and a five-ball spread at rank 3.
- Endless waves use a 24-second pressure window followed by clear-the-field.
  Health, damage, speed, score, and reward pressure continue to grow from the
  wave number without a final authored wave. Spawn interval and simultaneous
  pack size use device-safety limits; numeric enemy strength does not.
- Endless run powers have no rank cap. Cadence approaches a 0.14-second device
  safety floor asymptotically so every Quick Release rank still improves it.
  Boss waves occur every fifth wave.
- Equipped gear stacks multiplicatively with permanent Training upgrades before
  either Campaign or Endless begins. World rewards add a shield and
  projectile pierce respectively.

Permanent upgrade costs are centralized in `UpgradeRules`; level rewards and
spawn pacing are centralized in `GameContent`. Automated tests verify basic
economy reachability and content integrity. Final numeric tuning should follow
physical-device play sessions rather than changing rules inside views.
