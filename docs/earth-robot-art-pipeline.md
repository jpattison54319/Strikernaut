# Earth Robot Art Pipeline

Earth World uses one cohesive stadium-security robot family. The approved visual
language is white ceramic armor, cobalt chassis parts, restrained orange hazard
markings, cyan normal-state lights, and red only for hostile charge telegraphs.
The designs are original; angular transforming-mech construction is a broad
influence, not a reference to any existing character or insignia.

## Progression

| Existing game ID | Player-facing design | Gameplay read |
| --- | --- | --- |
| `coneRunner` | Scout Runner | Small wedge helmet, long sprinter legs, fastest and most fragile |
| `dummyDefender` | Blocker Defender | Low dome helmet, broad armor, slow and durable |
| `tackleBot` | Tackle Bot | Falcon helmet, athletic frame, sharp lateral cuts |
| `keeperDrone` | Aegis Keeper | Cage helmet, dual cyan shields, slow tank |
| `ballLauncher` | Ball Launcher | Asymmetric targeting helmet, integrated ball cannon, ranged danger |
| `titanKeeper` | Titan Keeper | Crown sensor, huge gauntlets, independent final boss silhouette |

The Swift enum cases remain unchanged so saved progress, campaign balance,
simulation behavior, and tests stay compatible.

## Runtime approach

Each enemy is a transparent 512-by-512 pre-rendered 2.5D sprite inside the
existing pooled `motion-body` node. SpriteKit continues to control perspective
scale, depth sorting, health/status UI, hit reactions, and movement.

The first animation pass deliberately uses inexpensive runtime transforms:

- cadence-specific bob, sway, and squash for locomotion;
- stronger tilt for the Scout Runner and Tackle Bot;
- pulsing red charge light for the Ball Launcher;
- pulsing cyan reactor for the Titan Keeper;
- existing boss scale, phases, reinforcements, and hostile projectiles.

This preserves the polished rendered materials at gameplay size without paying
for full skeletal animation or frame atlases. A later refinement can split only
the head, forearms, shields, or cannon into layers where independent movement
will be visible on a phone.

## Arena integration standard

`GameplayArena.png` is the authoritative camera, lighting, and material
reference for every Earth World render. Enemy art must use all of the following
as one locked setup:

- the same elevated portrait-gameplay camera, with the robot facing directly
  down its lane toward the player;
- soft warm sunlight from the upper-left/front, cool blue skylight in the
  shadows, and subtle green turf bounce on lower armor;
- rounded toy-like low-poly forms with broad highlights and restrained surface
  detail, matching the arena rather than reading as a separate glossy sticker;
- feet visible at the bottom of the silhouette and calibrated to a soft,
  green-black contact shadow in SpriteKit;
- no baked environment pieces, platforms, backboards, goal frames, nets, or
  scenery attached to any enemy, including the Titan Keeper.

The six roles may vary in height and mass, but they may not introduce a second
camera angle or a different lighting rig. Perspective consistency takes
priority over showing extra design detail.

Each role has its own runtime foot offset, shadow footprint, and health-bar
height. These values are calibrated from actual gameplay captures so the feet
touch the turf and larger enemies feel heavier without floating.

## Source and verification

Concept boards live in `Design/Concepts/EarthRobots`. Final transparent sprites
live in the corresponding `Earth*.imageset` folders in the asset catalog.
Verification screenshots are saved under
`Design/Concepts/EarthRobots/Verification`.

Every source render was generated on a uniform `#ff00ff` background, converted
to alpha with the shared chroma-key helper, downsampled to 512 pixels square,
and checked for transparent corners and visible edge contamination. The first
studio-render pass remains archived in
`Design/Concepts/EarthRobots/ProductionV1`; the arena-calibrated pass and its
six-role contact sheet are the current visual reference.
