# Strikernaut Inked Comic Art Pipeline

## Identity

Strikernaut uses an original dimensional sports-comic language. The signature
motifs are three-lane chevrons, portal brackets, soccer-panel hexagons, hard
black ink, restrained diagonal hatching, and cyan/coral print-registration
accents. It must not reproduce another game's logo, typography, panel geometry,
characters, or interface composition.

The tone is energetic and teen-friendly. Shapes remain readable and colorful;
grit supports form instead of covering it.

## Production rules

1. Keep all words, meters, buttons, icons, and numbers native. Never generate a
   completed screen or accept pseudo-text inside artwork.
2. Preserve approved character anatomy, uniforms, ball geometry, transparent
   edges, sprite anchors, and animation crops.
3. Light every illustration from the upper left. Use broad dimensional shadow
   planes before adding linework.
4. Use a heavy outer silhouette, finer internal feature lines, and crosshatching
   only in shadow. Avoid uniform noise over faces and focal highlights.
5. Review artwork at its real runtime size. Gameplay sprites use broader,
   simpler ink than roster portraits.
6. Reject malformed anatomy, extra parts, asymmetric soccer panels, floating
   objects, accidental text, conflicting light direction, fuzzy edges, melted
   details, and unexplained decorative particles.

## Deterministic conversion

Run the project-local pipeline with the bundled Codex Python runtime:

```sh
/Users/jamespattison/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  Tools/ink_art_pipeline.py GoalRush/Resources/Assets.xcassets --in-place
```

The pipeline applies the same contrast curve, palette compression, inner and
outer ink hierarchy, shadow-masked hatching, restrained grit, and alpha-safe
downstream export to every raster asset. Presets distinguish environments,
sprites, projectiles, and the app icon.

Always begin from a clean Git checkpoint. The command is intentionally
deterministic, so a source image produces the same result on every run.

## Typography

- Display: Barlow Condensed Black Italic.
- Metrics: Barlow Condensed Bold.
- Controls: Barlow Semi Condensed Semibold.
- Body: Barlow Semi Condensed Medium.

Only display headings are uppercase and aggressively styled. Body text stays
clean and scales with Dynamic Type. The bundled font files are licensed under
the SIL Open Font License in `GoalRush/Resources/Fonts/OFL.txt`.

## New raster prompt template

Use case: `stylized-concept`

Asset type: isolated Strikernaut production illustration

Primary request: create the named subject using its approved reference sheet,
preserving identity, anatomy, equipment, silhouette, and lighting direction

Style/medium: dimensional hand-painted sci-fi sports illustration prepared for
a deterministic ink pass; strong 3D form and smooth shadow planes, not flat
cel shading

Color palette: ink black, weathered cream, cobalt, cyan, turf green, warning
gold, and the subject's approved world accent

Constraints: one subject only; no text, letters, numbers, logos, sponsors,
watermark, particles, border, frame, extra limbs, malformed hands, melted
details, fuzzy edges, or inconsistent soccer-ball panels

For transparent assets, generate on a perfectly flat removable chroma-key
background with no floor, reflection, cast shadow, or key color on the subject.
