# Character roster assets

Production characters use one front roster sprite and one true rear gameplay
sprite at 512 x 512. They share Ace's proportions, elevated field camera,
upper-left stadium key light, cool fill, soft 3D shading, and grounded sports
materials.

## Roster

- Ace — Pinball Blitz — available from the start
- Volt — Time Break — clear Level 10
- Nova — Meteor Volley — clear Level 15
- Aegis — Last Stand — clear Level 20

## Generation

Built-in image generation was used. Ace's processed two-view master was the
strict style and composition reference for Volt, Nova, and Aegis. Each prompt
requested two separated full-body views, front on the left and true rear on the
right, on a uniform `#00FF00` background with no props, text, shadows, floor,
reflections, or cropped anatomy.

Chroma sources are retained in `ChromaSource`. Transparent two-view sheets are
in `Processed`. Production views live in corresponding imagesets under
`GoalRush/Resources/Assets.xcassets`.
