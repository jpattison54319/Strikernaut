# Endless, Worlds, and Gear Expansion

## Product contract

- Campaign is organized into authored worlds. Earth contains Levels 1–10 and
  Mars contains Levels 11–20. The content model owns world membership, theme,
  background, enemies, objects, boss, and world-clear reward so another world
  can be added without rewriting navigation or simulation code.
- Endless is a distinct run mode available from the home screen. It starts with
  a run-only power choice, has no victory condition or final wave, grants a new
  choice after every cleared wave, and ends only when stamina reaches zero or
  the player chooses to leave.
- Permanent stat upgrades and equipped gear apply in Campaign and Endless.
  Run-only abilities reset when either type of run ends.
- Gear cannot be bought. A complete five-piece set is awarded the first time a
  world boss is defeated. The player begins with every slot set to None.

## Endless balance

- Waves have an authored time target, followed by a clear-the-field phase. This
  prevents a wave transition from deleting live threats and makes the upgrade
  break a true reward for clearing pressure.
- Enemy health, contact damage, hostile projectile damage, reward score, and
  movement pressure are functions of wave number. Health and damage continue
  scaling without an authored maximum; spawn rate has a safety floor so device
  performance is not used as the difficulty mechanism.
- Enemy types enter the pool progressively. Every fifth wave introduces the
  selected world's boss alongside the regular pool.
- Endless power ranks are uncapped. Damage, cadence, pierce, tracking, volley,
  shields, healing, enemy slow, meteor kicks, and reward multipliers support
  distinct stacking builds. Campaign retains a three-rank cap and the original
  six-technique pool.
- Training Tokens are credited on destruction and checkpointed at every draft,
  pause, background transition, and result. Best wave and best score are stored
  per world.

## World release

### Earth — Training Grounds

- Existing bright stadium art and training robots.
- Levels 1–10 and Titan Keeper boss.
- First-clear reward: Earth Vanguard gear set.

### Mars — Red Frontier

- Original rust-red crater stadium art with cyan rails and habitat domes.
- Levels 11–20 with alien scouts, crawlers, shield saucers, plasma attackers,
  Martian equipment, and the Mars Colossus boss.
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
- Endless onboarding states the irreversible run contract before Start, then
  keeps Wave, Score, Stamina, and Tokens visible in the HUD.
- Selection, reward, wave-clear, and equipment changes combine visible state,
  sound, and optional haptics. All icon-only controls retain text labels and at
  least 44-by-44-point targets.
- Reduce Motion replaces large travel/scale transitions with opacity; Reduce
  Flashes suppresses strong gameplay pulses. Color is never the only indicator
  of locked, equipped, completed, or selected state.

## Verification

- Unit tests cover save migration, world unlocking, gear idempotency and stat
  effects, Endless wave progression, uncapped difficulty growth, repeatable
  drafts, and per-world records.
- UI tests cover Home entry points, world locks, Endless launch/draft/pause, and
  gear cycling.
- Simulator screenshots are inspected for Home, Campaign, Mars gameplay,
  Endless hub/HUD/draft, world-clear result, and the locker.
