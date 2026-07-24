# Modular Player Character Kit

This kit replaces the procedural circle-and-rectangle player with a rendered
human hero that matches the home artwork, Earth robots, Mars aliens, and both
live arena cameras.

## Production assets

`GoalRush/Resources/PlayerParts` contains 30 transparent sprites:

- Base, Earth, and Mars styles
- Head, torso, arm, leg, and foot components
- Front locker and elevated rear gameplay views for every component

The runtime mirrors each right-side limb for the left side while preserving
separate leg joints for the kick animation. Equipment remains independently
swappable across all five existing gear slots.

## Generation workflow

The built-in image-generation workflow first created a two-view master human
striker based on `MenuHero`, `GameplayArena`, and the rendered enemy style.
Fifteen subsequent prompts generated one modular slot component at a time,
always producing a locker view and gameplay view of the same part. Earth prompts
referenced Earth robot materials; Mars prompts referenced Mars alien materials.

Every source used a flat green chroma background. `ChromaSource` preserves those
originals and `Processed` preserves the transparent two-view working sheets.
The final resources are split, trimmed, padded, and normalized 512-pixel PNGs.
