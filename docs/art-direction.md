# Strikernaut Art Direction

Strikernaut uses an original all-ages toy-like 3D visual language: rounded forms,
large silhouettes, saturated turf, cobalt/teal player colors, orange training
robots, and yellow boss accents. No real clubs, sponsors, flags, or player
likenesses are used.

The gameplay reference supplied by the product owner informed only the elevated
portrait composition and lane-based mechanics. Production characters, stadium,
objects, interface, app icon, and audio are original.

## Image-generation prompts

### App icon

Use case: `logo-brand`. A hand-directed graphic arcade-sports icon with no
text. Ace is seen from behind in a powerful kick, launching one geometrically
correct black-and-white ball up three converging lanes toward a compact
futuristic portal-goal. The lower half reads as the green Earth stadium and the
portal opens into the coral-red Mars world. Use a bold silhouette, intentional
cel-shaded planes, crisp controlled edges, a poster-like large/medium/small
hierarchy, restrained screen-print texture, and generous safe padding. Keep
the palette to navy/cobalt/cyan, turf green, coral/rust/violet, and one warm
gold impact accent. No words, marks, sponsors, flags, borders, transparency,
robot mascot, extra characters or balls, sparkles, lens flare, excessive glow,
glossy plastic, malformed anatomy, inconsistent ball panels, fuzzy edges, or
generic fantasy detail.

### Menu hero

Use case: `stylized-concept`. Portrait futuristic soccer training stadium with
three converging turf lanes, a small cobalt/teal player from behind, friendly
orange training robots upfield, soccer balls and equipment carts. Premium
rounded toy-like 3D render, elevated camera, clear lower negative space for
native controls, no text, UI, real club marks, sponsors, flags, or watermark.

### Gameplay arena

Use case: `stylized-concept`. Empty portrait soccer training arena with three
clear converging turf lanes, padded cobalt-and-white rails, a centered distant
goal, crowd shapes, and bright daylight. Premium rounded low-poly 3D render;
no players, robots, balls, equipment, pickups, text, logos, or UI. This is the
static depth layer beneath live SpriteKit characters and effects.

### Mars arena

Use case: `stylized-concept`

Asset type: portrait iPhone gameplay arena background for Strikernaut

Primary request: an empty futuristic soccer training stadium on Mars, designed
as the second campaign world

Scene/backdrop: three very clear converging rust-red playing lanes cut through
a Martian crater, translucent cyan safety rails, distant sci-fi goal, rounded
habitat domes and soft alien rock formations, subtle view of space and a small
moon overhead

Style/medium: premium rounded toy-like low-poly 3D game render matching a
colorful all-ages mobile arcade game

Composition/framing: portrait 2:3, elevated camera looking up three lanes,
close foreground kept empty for the player, midground and lanes readable for
live SpriteKit entities, no baked-in characters

Lighting/mood: dramatic warm coral sunset with cool cyan rim lights,
adventurous and welcoming rather than threatening

Color palette: rust red, coral, violet, cyan, cobalt, warm gold

Constraints: original design; no players, enemies, balls, equipment, pickups,
text, UI, logos, sponsors, flags, real clubs, watermark, or border; preserve
strong lane readability and uncluttered foreground

### Locker room

Use case: `stylized-concept`

Asset type: portrait iPhone character customization screen background for Goal
Rush

Primary request: an empty futuristic soccer locker room that feels like a
prestigious earned-gear vault

Scene/backdrop: symmetrical cobalt-and-teal locker bay, softly glowing
equipment alcoves, circular presentation platform centered in the lower-middle,
subtle trophy silhouettes and warm gold accent lighting, no actual gear
displayed

Style/medium: premium rounded toy-like low-poly 3D mobile game render matching
a colorful all-ages soccer sci-fi arcade game

Composition/framing: portrait 2:3, centered character-sized negative space from
head to feet, darker edges for native UI controls, clear empty left and right
margins for arrow controls

Lighting/mood: cinematic celebratory locker-room lighting, aspirational,
polished, welcoming

Color palette: deep navy, cobalt, teal, cyan, restrained warm gold

Constraints: original design; no character, clothing, shoes, balls, text, UI,
arrows, logos, sponsors, flags, real clubs, watermark, or border

### Daily reward chest

Use case: `stylized-concept`. Premium rounded toy-like 3D render of a glowing
treasure chest slightly open with golden light and soccer-ball-patterned coins
spilling out, cobalt and gold palette, dark navy background, centered
composition, no text, no watermark.

### Onboarding hero

Use case: `stylized-concept`. Premium rounded toy-like 3D render, portrait 2:3
futuristic soccer training stadium, three converging turf lanes, small
cobalt/teal player dribbling a soccer ball toward friendly orange training
robots upfield, subtle motion lines, sunny lighting, quiet empty lower third
for UI overlay, elevated camera, no text, no UI, no watermark.

The seven environment and UI images above were generated with the built-in
image-generation tool in the prompt modes named above and copied into
`GoalRush/Resources/Assets.xcassets` for the app target.

## Soccer ball projectile sprites

The standard projectile is an unmistakable black-and-white stitched soccer ball
rendered in the same premium rounded toy-like 3D style. Six power variants
preserve the same panel geometry and add a compact, readable effect:

- `SoccerBallRapidFire`: golden electric corona and cobalt lightning.
- `SoccerBallExplosive`: pressurized red-orange energy shell and impact spikes.
- `SoccerBallFire`: yellow-orange arcade flames with no smoke.
- `SoccerBallIce`: pale-cyan frost plates, rime, crystals, and icicles.
- `SoccerBallReverse`: violet directional energy ring and reverse arrows.
- `SoccerBallSplit`: emerald aura and five miniature soccer-ball echoes.

Each sprite was generated with the built-in image-generation tool as a
`stylized-concept` base or `precise-object-edit` variant on a flat `#ff00ff`
background. The key background was removed locally, the output was downsampled
to a transparent 384-pixel square PNG, and the final images were copied into
individual image sets under `GoalRush/Resources/Assets.xcassets`.
