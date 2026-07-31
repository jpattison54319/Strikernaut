# World Campaign Expansion

## Shipping structure

Campaign is a 70-challenge journey:

| World | Levels | Signature rule | Temporary powers | Hero reward |
| --- | ---: | --- | --- | --- |
| Earth | 1–10 | None | Rapid Fire, Split Shot, Heat Seeking | Volt |
| Moon | 11–20 | Orbital debris periodically marks and strikes a player lane | Reverse, Ice, Orbit Shot | Nova |
| Mars | 21–30 | Defeats and boss phases arm Volatile Cores that damage the player if ignored | Fire, Explosive, Solar Pierce | Aegis |
| Jupiter | 31–40 | Wind Shear pushes the player and friendly balls across a charged rail | Heat Seeking, Volt, Gravity Well | Gale |
| Saturn | 41–50 | Ring Sweep blocks two lanes and leaves one readable opening | Orbit Shot, Split, Ring Return | Halo |
| Uranus | 51–60 | Cryo Drift adds sideways momentum while frozen edge rails close in | Ice, Reverse, Polar Link | Flux |
| Neptune | 61–70 | Pressure Tide forms crushing walls around a shifting safe channel | Explosive, Solar Pierce, Undertow | Surge |

Ace remains the starter hero. Character abilities remain permanent hero
identity; world pickups remain temporary run modifiers.

## Navigation contract

The Campaign button opens `CampaignRoute.planets`. The first vertical page
places Earth at the bottom, Moon in the middle, and Mars at the top. The route
visibly continues beyond both screen edges. Explicit left/right controls change
pages using a vertical scroll animation; Reduce Motion substitutes a short
transition. The second page carries Jupiter, Saturn, and Uranus. The third
carries Neptune and a locked Andromeda signal, hinting at the first destination
beyond the Milky Way without exposing a nonfunctional level map.

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

`PlayerProgress` schema 10 adds the outer-world unlock chain without discarding
global level records, upgrades, characters, or Endless history. Character
ownership is rebuilt from completed world finales so Gale, Halo, Flux, and
Surge unlock deterministically after Levels 40, 50, 60, and 70.

World rules are strictly hostile. They fire from simulation cadence without a
persistent HUD countdown, progress ring, or active-effect timer. The arena still
telegraphs the lane or core itself long enough for a fair reaction.

## Art ownership

The four outer-world arenas are original generated artwork in
`Assets.xcassets`; each also supplies its campaign-map background. Saturn,
Uranus, Neptune, and the Andromeda signal use compact vector planet glyphs so
the journey never depends on a missing raster. The visual concept board and
prompt record live under `Design/Concepts/OuterWorlds`.
