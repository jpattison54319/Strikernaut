# Outer Worlds Concept Art

`OuterWorldsConceptBoard.png` establishes the visual split between the four
campaign worlds:

- Jupiter: amber cyclones, lightning rails, and violent lateral wind.
- Saturn: gold ring architecture, ice shards, and moving lane apertures.
- Uranus: cyan axial tilt, magnetic auroras, and glassy frost rails.
- Neptune: cobalt pressure trenches, current channels, and abyssal storm walls.

The production arena prompts asked for a portrait 2:3 mobile-game field with
three readable lanes, open combat space, dark HUD-safe edges, no characters,
no text, and no baked-in interface. Each prompt then constrained the world to
its own material and hazard language. The resulting arena images are installed
as `JupiterArena`, `SaturnArena`, `UranusArena`, and `NeptuneArena`, and are
reused as their corresponding campaign-map backgrounds.

`JupiterFactionSigilConcept.png` is retained as exploratory art only because
its generated checkerboard is baked into the pixels. Shipping faction sigil
assets use clean-alpha catalog resources.

## Character model sheets

`Characters/` contains the built-in image-generation source sheets used for
the four outer-world unlocks. Each sheet pairs the roster three-quarter view
with the matching elevated, back-facing gameplay view:

- Gale: Jupiter amber storm armor, cyclone curls, and three defense nodes.
- Halo: Saturn violet-and-gold orbital armor with an anchored ring silhouette.
- Flux: Uranus polar armor with six docked magnetic trap cartridges.
- Surge: Neptune wave armor, a trident crest, and three tidal chevrons.

The shipping catalog images are clean-alpha 512×512 crops normalized to the
same body bounds as the original character set. Gameplay views keep a clear
lower-body split so the segmented SpriteKit kick rig can animate each leg.
