# Mars Alien Art Pipeline

Mars World uses one original alien-invasion family built around red-rock
carapace, dark violet armor, cyan bioluminescent technology, and small amber
sunlight accents. Pulp science fiction, space opera, creature features, and
kaiju-scale finales are broad genre influences; no existing franchise
character, costume, insignia, or vehicle is reproduced.

## Progression

| Existing game ID | Player-facing design | Gameplay read |
| --- | --- | --- |
| `dustSprite` | Dust Sprite | Wiry wedge-headed grunt, four cyan eyes, fastest and most fragile |
| `roverRaider` | Rover Raider | Broad beetle-crab infantry, heavy shoulders, slow and durable |
| `craterCrawler` | Crater Crawler | Low six-limbed hunter, widest silhouette, sharp lateral cuts |
| `saucerKeeper` | Saucer Keeper | Crescent helmet, dual carapace shields, integrated hover ring |
| `plasmaStriker` | Plasma Striker | Tall comet helmet, asymmetric integrated plasma cannon |
| `marsColossus` | Mars Colossus | Four arms, split crown, chest reactor, independent final-boss silhouette |

The Swift enum cases remain unchanged, preserving saved progress, campaign
balance, simulation behavior, and compatibility.

## Locked arena camera and lighting

`MarsArena.png` is the authoritative camera, lighting, palette, and material
reference. Every Mars render uses the same elevated portrait-gameplay view,
with the alien facing down the lane toward the player.

- Warm orange sunset comes from the upper-left and cyan colony lighting rims
  the right and lower armor.
- Armor highlights are broad and painted rather than studio-glossy, keeping
  the enemies inside the illustrated 2.5D world.
- Feet or contact limbs remain visible and align with a soft red-black runtime
  shadow.
- No enemy includes a baked platform, throne, goal, net, background fragment,
  or scenery.
- The Colossus is grounded directly on the lane and achieves scale through its
  silhouette, four arms, reactor, runtime shadow, and boss multiplier.

The live vertical projection is Mars-specific. Standard enemies enter at the
illuminated colony gate, then grow naturally as they travel toward the player.
Mini-bosses and the Colossus start slightly forward on the same lane plane.
This avoids the old appearance of enemies dropping from behind the phone
header or entering from an unrelated part of the skyline.

The top HUD uses a plum-to-navy surface, cyan colony rim, and restrained cyan
shadow. It remains opaque for stable SpriteKit performance while sharing the
background's sunset/cyan color story.

The replaced three-corridor arena and the approved open-field revision are
archived together in `Design/Concepts/MarsAliens/Background`.

## Runtime approach

Each role is a transparent 512-by-512 pre-rendered sprite inside the pooled
`motion-body` rig. SpriteKit continues to own movement, perspective scale,
depth order, shadows, health bars, hit reactions, boss phases, and projectile
attacks.

Role-specific bob, sway, compression, hover, and lateral motion keep the art
alive without flattening it into frame-heavy animation sheets. Per-role sprite
size, foot offset, shadow footprint, status envelope, and health-bar height
were calibrated from iPhone 17 Pro simulator captures.

## Universal status effects

Mars aliens use the same model-bound elemental system as Earth robots:

- Ice tints the rendered body, locks its movement pose, overlays a translucent
  frost glaze, and grows six silhouette-bound icicle clusters.
- Fire warms the body and runs animated foreground and background flames at
  multiple heights around the model.
- Reverse adds a violet body treatment and animated directional trails.
- Fire and ice replace one another with a steam reaction instead of producing
  contradictory stacked states.

The envelopes scale from the Dust Sprite through the Colossus, so none of the
effects are detached circles. Pooled enemies reset all tint, animation, and
effect state before reuse.

## Generation and source handling

The six production renders were generated with the built-in image generator,
using `MarsArena.png` as an explicit camera, lighting, and style reference.
Each prompt locked:

- a single complete original alien on a flat `#00ff00` chroma background;
- a transparent-sprite-ready composition with no text or environment;
- the shared elevated camera and warm-left/cool-right Mars lighting;
- the role's unique head, mass, weapon, locomotion, and gameplay silhouette;
- a strict ban on platforms, goals, nets, scenery, and franchise likenesses.

Chroma sources live in `Design/Concepts/MarsAliens/ChromaSource`. Final RGBA
sprites live in the corresponding `Mars*.imageset` folders. All final files
were downsampled to 512 pixels square and checked for transparent corners and
green edge contamination.

Live progression and status-effect captures are archived under
`Design/Concepts/MarsAliens/Verification`. These are the visual acceptance
reference for the arena entry plane, header treatment, camera consistency,
ground contact, scale progression, and elemental effects.
