# Endless, Worlds, and Gear Expansion

## Product contract

- Campaign is organized into authored worlds: Earth contains Levels 1–10, the
  Moon contains 11–20, and Mars contains 21–30. The content model owns world
  membership, theme, background, enemies, objects, boss, rule, and temporary
  powers so another world can be added without rewriting navigation or
  simulation code.
- Endless is one distinct run mode available from the home screen; there is no
  world picker. It starts with a run-only power choice, has no victory condition
  or final wave, grants a new choice after every cleared wave, and ends only
  when stamina reaches zero or the player chooses to leave.
- The circuit uses Earth for waves 1–10, Moon for 11–20, Mars for 21–30, then
  loops to Earth on wave 31. Its sequence is derived from the authored world
  catalog so future worlds slot in before the loop automatically.
- Permanent stat upgrades and equipped gear apply in Campaign and Endless.
  Run-only abilities reset when either type of run ends.
- Gear cannot be bought. A complete five-piece set is awarded the first time a
  world boss is defeated. The player begins with every slot set to None.

## Endless balance

- Regular waves have an enemy defeat quota. Escaped enemies deal stamina
  damage, do not decrement it, and are replaced. This makes the upgrade break a
  true reward for defeating the authored pressure rather than outlasting it.
- Enemy health, contact damage, hostile projectile damage, reward score, and
  movement pressure are functions of wave number. Health and damage continue
  scaling without an authored maximum; spawn rate has a safety floor so device
  performance is not used as the difficulty mechanism.
- Enemy types enter the pool progressively. Every fifth wave is a boss-only
  completion objective with two phase-gated reinforcement pulses; those adds
  do not count toward the displayed objective.
- At each ten-wave boundary, a black interstitial drops the completed world name
  away and slams the incoming world name into place. The scene switches arena,
  geometry, enemy and object families, boss, rule, temporary powers, colors,
  and faction emblem beneath that cover before play resumes.
- Endless power ranks are uncapped. Damage, cadence, pierce, tracking, volley,
  shields, healing, enemy slow, meteor kicks, and reward multipliers support
  distinct stacking builds. Campaign retains a three-rank cap and the original
  six-technique pool.
- Training Tokens are credited on destruction and checkpointed at every draft,
  pause, background transition, and result. Best wave and best score are stored
  as one record for the continuous mode; legacy per-world records merge by
  their maximum values.

## World release

### Earth — Training Grounds

- Existing bright stadium art and training robots.
- Levels 1–10 and Titan Keeper boss.
- First-clear reward: Earth Vanguard gear set.

### Moon — Lunar League

- Original low-gravity arena art with periodic orbital-debris strikes. Debris
  marks a lane in the arena, then damages a player who remains there.
- Levels 11–20 with regolith runners, lunar hoppers, orbit drones, eclipse
  keepers, gravity strikers, lunar equipment, and the Lunar Warden boss.

### Mars — Red Frontier

- Original rust-red crater stadium art with cyan rails and habitat domes.
- Levels 21–30 with alien scouts, crawlers, shield saucers, plasma attackers,
  Martian equipment, and the Mars Colossus boss.
- Every sixth standard defeat and each boss phase arms a Volatile Core. Shooting
  it only neutralizes the threat; ignoring it damages the player.
- First-clear reward: Mars Pioneer gear set.

## Gear and effects

Slots are Head, Torso, Hands, Legs, and Feet. Each slot cycles only through None
and items the player has earned.

- Earth Vanguard: crit visor, stamina jersey, flight gloves, response guards,
  and cadence cleats. Equipping all five starts each run with a shield.
- Mars Pioneer: homing lens, damage core, critical gauntlets, gravity guards,
  and faster comet boots. Equipping all five adds one pierce to every ball.

The locker uses a live SpriteKit character preview over an original locker-room
background. Each body row has explicit 44-point previous/next buttons, a slot
label, and an item name. The focused item card explains the exact gameplay
effect, unlock source, and active full-set bonus.

## UX and accessibility

- Home gives Campaign and Endless distinct primary cards; Upgrades and Gear are
  persistent-progression destinations.
- Campaign keeps world choice and level choice on one screen so locked content,
  completion progress, and rewards remain visible without navigation hunting.
- Endless onboarding states the irreversible run contract before Start. Live
  play keeps Wave, Stamina, and Tokens visible; score continues accumulating
  but stays off the gameplay surface until results.
- The objective plate uses image-generated abstract faction and boss-faction
  sigils in a compact plate below the main status strip. Enemy-count decrements
  roll, glow, and settle; the next wave rolls in when its draft dismisses. The
  combo is a bare number and `x` aligned opposite the objective, with no panel,
  border, or label. Reduce Motion replaces travel and scale with restrained
  opacity changes. Boss health appears only on the boss itself as a red bar
  paired with that world's abstract boss sigil.
- Selection, reward, wave-clear, and equipment changes combine visible state,
  sound, and optional haptics. All icon-only controls retain text labels and at
  least 44-by-44-point targets.
- Reduce Motion replaces large travel/scale transitions with opacity; Reduce
  Flashes suppresses strong gameplay pulses. Color is never the only indicator
  of locked, equipped, completed, or selected state.
- World hazards happen at cadence and use only immediate in-arena warnings. They
  never add a persistent countdown, progress bar, or active timer to the HUD.

## Verification

- Unit tests cover save migration, world unlocking, gear idempotency and stat
  effects, Endless wave/world progression, uncapped difficulty growth,
  repeatable drafts, theme-specific enemy pools, and the singular record.
- UI tests cover Home entry points, world locks, the Endless circuit,
  launch/draft/pause, the Earth-to-Moon interstitial, and gear cycling.
- Simulator screenshots are inspected for Home, Campaign, Mars gameplay,
  Endless hub/HUD/draft, world-clear result, and the locker.
