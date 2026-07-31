# Endless Relics

Endless Relics are account-wide, permanent bonuses that apply only to Endless.
The player may own any number of relics, but can equip exactly one at a time
from the Relics destination on Home.

## Run rewards

- A run earns one relic after clearing at least Wave 5. Because results store
  the wave reached, completed waves are `max(0, result.wave - 1)`.
- The source milestone is the greatest multiple of five at or below completed
  waves.
- The run UUID and source milestone seed the reward. `lastRewardedRunID`
  prevents a recovered or repeated result from paying twice.
- The active relic and derived `PlayerStats` are captured at run launch.
  A recovered checkpoint therefore keeps its original bonuses even if the
  inventory changes later.
- Existing saves keep their best wave, which unlocks the matching Forge tier,
  but do not receive retroactive relics.

## Rarity

| Rarity | Color | Affixes | Value multiplier | Scrap |
| --- | --- | ---: | ---: | ---: |
| Common | `#E8EDF2` | 1 | 1.00x | 5 |
| Uncommon | `#39D353` | 1 | 1.35x | 10 |
| Rare | `#2F7DFF` | 2 | 1.75x | 15 |
| Epic | `#A855F7` | 3 | 2.20x | 25 |
| Legendary | `#FF8A1F` | 4 | 2.80x | 35 |

The UI always pairs color with the written rarity and one to five diamond
markers. Drop percentages stay internal to the reward rules and are not shown
on the Relics or Forge screens.

| Cleared milestone | Common | Uncommon | Rare | Epic | Legendary |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 5 | 70% | 25% | 5% | 0% | 0% |
| 10 | 58% | 30% | 10% | 2% | 0% |
| 20 | 43% | 34% | 17% | 5% | 1% |
| 30 | 30% | 34% | 25% | 9% | 2% |
| 50 | 18% | 30% | 32% | 16% | 4% |
| 70 | 10% | 24% | 36% | 23% | 7% |
| 100 | 5% | 15% | 38% | 30% | 12% |

The greatest listed threshold at or below the milestone applies. Beyond Wave
100, every additional 20 cleared waves transfers one percentage point from the
lowest remaining non-Legendary tier to Legendary.

## Affixes

| Stat | Base roll |
| --- | ---: |
| Attack Damage | 5% |
| Maximum Stamina | 6% |
| Kick Rate | 3% |
| Movement Response | 6% |
| Ball Speed | 5% |
| Critical Chance | 2 percentage points |
| Hero Charge Rate | 6% |
| Training Token Gain | 8% |

Affixes on one relic are unique. Primary values roll from 90–110% of their
scaled value; secondary values roll from 65–85%.

```text
waveScale = 1 + 0.05 * ((sourceMilestone - 5) / 5)
storedPercent = base * rarityMultiplier * waveScale * rolledFactor
```

Displayed values round to 0.1%. Stored affixes use integer basis points and
never recompute if tuning changes later. Kick Rate divides cooldown by
`1 + bonus`; the existing minimum rendered cadence continues converting
overflow into Quick Release damage.

## Forge, inventory, and Salvage

- Forge is a separate destination opened from the top-right of Relics.
- Its roll-type dropdown lists Random first and Focused second. One Forge
  button updates its label and price for the selected type.
- Random costs 40 Scrap.
- Focused costs 80 Scrap and reveals a second dropdown that guarantees the
  selected primary stat.
- Both use rarity odds and scaling from the best completed five-wave
  milestone.
- Forge payment and the new inventory item are persisted before reveal.
- Inventory uses a three-column square grid at normal text sizes and full-width
  cards at accessibility text sizes.
- Salvage enters a visible multi-select mode with Cancel and a count-aware
  confirmation action. Salvaging permanently removes every selected item,
  animates the removal, and pays their combined rarity value. Selecting the
  equipped item also clears the one equipment slot.

Relics cannot be purchased with Training Tokens or ads. There is no rarity pity
or inventory cap.
