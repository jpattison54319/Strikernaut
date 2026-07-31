# Planetary Roster

These sheets define the production identity for all eight playable characters.
Each generated source contains one matching front roster view and rear gameplay
view on a removable chroma background. The `-Alpha` sheets are the cleaned
masters used to export the 512 × 512 asset-catalog sprites.

## Identity map

| Character | World | Signature silhouette |
| --- | --- | --- |
| Ace | Earth | Varsity flight jacket, shoulder tab, ball-panel hip holster |
| Volt | Earth | Open lightning visor, twin capacitor prongs, arm power coil |
| Nova | Moon | Crescent bubble helmet, oxygen collar, survey telescope |
| Aegis | Mars | Dust respirator, pressure tanks, twin shield gauntlets |
| Gale | Jupiter | Cloudborn alien crest, gas mask, tubes, storm-ball docks |
| Halo | Saturn | Gyroscopic shoulder ring, orbital monocle, shepherd sensors |
| Flux | Uranus | Cryo hood, diagonal magnetic coil, six trap cartridges |
| Surge | Neptune | Amphibious fins, gills, coral collar, dorsal water reservoir |

Gale and Surge are intentionally nonhuman. Halo and Flux remain
human-adjacent. Every character retains an expressive hero read, soccer kit,
cleats, and a grounded two-legged stance so none can be confused with the
faceless mechanical enemy factions.

## Generation prompt set

The built-in image generator was given one character-specific prompt per
sheet. Every prompt required:

- Strikernaut dimensional inked sports-comic rendering with upper-left light;
- exactly two consistent full-body views: three-quarter front and direct rear;
- the world-specific species, clothing, and accessories in the table above;
- attached equipment above the hips for the segmented kicking-leg renderer;
- a perfectly flat `#00FF00` background with no floor, shadow, or reflection;
- no text, logos, weapons, extra limbs, faceless helmets, enemy silhouettes, or
  detached effects.

`CharacterIdentityBoard.png`, `GameplayCameraValidationBoard.png`, and
`CharacterSilhouetteValidation.png` are the approval references for palette,
camera angle, runtime proportions, and color-independent silhouette identity.
