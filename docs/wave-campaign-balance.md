# Wave Campaign and Temporary Powers

## Campaign structure

- World levels 1–3 contain three waves.
- World levels 4–7 contain four waves.
- World levels 8–10 contain five waves.
- Every non-final wave ends with a mini-boss selected from the level's active enemy pool.
- The final wave of each world's tenth level replaces the mini-boss with that world's mega-boss.
- Clearing a non-final wave pauses simulation and offers one run-only upgrade before the next wave.

## Difficulty budget

`CampaignBalance` is the single source of truth for campaign scaling.

- Base health increases smoothly between authored levels.
- Each wave adds 15% enemy health.
- The expected offensive value of one between-wave upgrade is budgeted at 20%, keeping the next wave beatable while spawn rate, speed, and incoming damage still increase pressure.
- Spawn intervals contract 9% per wave with a 0.52-second floor.
- Enemy speed increases 4.5% per wave.
- Incoming damage increases 7.5% per wave.
- Mini-boss durability grows by wave. Mega-bosses use their authored high base health plus gentler world progression so they remain durable without becoming multi-minute damage sponges.

## Boss behavior

- Mini-boss scale: 1.28×.
- Mega-boss scale: 1.58×.
- Bosses use slow lateral movement rather than advancing directly into the player.
- Boss phases trigger additional random reinforcements from the current level.
- Normal support spawning continues at reduced frequency during the boss section.
- Ice pauses boss movement and attacks for its status duration.

## Temporary power targets

One power target is scheduled in the middle portion of every wave. It travels downfield quickly with a high-frequency zig-zag and disappears if missed.

Destroying it activates one temporary ball effect:

- Rapid Fire: five-times-faster kick cadence for seven seconds.
- Explosive Balls: area damage around each impact for nine seconds.
- Fire Balls: four-second damage-over-time burn for ten seconds.
- Ice Balls: 1.7-second freeze per hit for eight seconds.
- Reverse Balls: reverses enemy travel for 2.8 seconds per hit, active for eight seconds.
- Split Shot: impacts emit five mini-balls, or eight on critical hits, for nine seconds.

Only one temporary power is active at a time. A new pickup replaces the current power and resets the circular HUD timer.

## Feedback and performance

- Damage values are emitted through the simulation event callback directly to SpriteKit.
- Values use colored, outlined, upward-floating feedback with a larger critical treatment.
- Damage-number nodes, targets, projectiles, impact sparks, and kick waves are pooled or prewarmed to avoid reintroducing collision-time allocation hitches.
- SwiftUI receives only the throttled HUD snapshot for wave and temporary-power timer state.
