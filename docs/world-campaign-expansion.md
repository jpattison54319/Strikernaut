# World Campaign Expansion

## Shipping structure

Campaign is a 30-challenge journey:

| World | Levels | Signature rule | Temporary powers | Hero reward |
| --- | ---: | --- | --- | --- |
| Earth | 1–10 | None | Rapid Fire, Split Shot, Heat Seeking | Volt |
| Moon | 11–20 | Orbital debris periodically marks and strikes a player lane | Reverse, Ice, Orbit Shot | Nova |
| Mars | 21–30 | Defeats and boss phases arm Volatile Cores that damage the player if ignored | Fire, Explosive, Solar Pierce | Aegis |

Ace remains the starter hero. Character abilities remain permanent hero
identity; world pickups remain temporary run modifiers.

## Navigation contract

The Campaign button opens `CampaignRoute.planets`. The first vertical page
places Earth at the bottom, Moon in the middle, and Mars at the top. The route
visibly continues beyond both screen edges. Explicit left/right controls change
pages using a vertical scroll animation; Reduce Motion substitutes a short
transition. Page two currently exposes the locked future Jupiter Citadel.

Selecting an unlocked planet opens `CampaignRoute.worldMap`. Each map owns ten
stable landmark placements, an original world background, a dotted route,
per-level lock state, and the existing zero-to-three-star rating. A landmark
opens a level preview before play.

Navigation remains explicit:

`Home → Planet Journey → World Map → Level Preview → Gameplay → Result`

Result **Map** returns to the world map. World-map **Planets** returns to the
journey. **Home** is always visible in both campaign selection screens.

At accessibility Dynamic Type sizes, the planet journey and landmark map become
linear lists while preserving the same actions and lock descriptions.

## Persistence

`PlayerProgress` schema 5 inserts the Moon without discarding global level
records. Existing Levels 11–20 naturally become Moon records. Character
ownership is rebuilt from completed world finales so the unlock chain remains
deterministic. The old Mars Endless record is cleared because its content and
unlock boundary moved to Levels 21–30.

World rules are strictly hostile. They fire from simulation cadence without a
persistent HUD countdown, progress ring, or active-effect timer. The arena still
telegraphs the lane or core itself long enough for a fair reaction.

## Art ownership

`MoonArena`, `EarthWorldMap`, `MoonWorldMap`, `MarsWorldMap`, and the four
illustrated planet assets are original artwork in `Assets.xcassets`. Every new
raster is processed through `Tools/ink_art_pipeline.py` with its environment or
icon preset; isolated planets additionally use the deterministic chroma-key
stage. The supplied screenshots were used only to understand information
hierarchy and navigation intent; no image, character, landmark, or branded
element was reused.
