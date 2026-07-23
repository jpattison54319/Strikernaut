# Result and Home Action Layout

## Goal

Make post-match navigation direct and simplify the Home screen's action hierarchy.

## Result screen

- Remove the More Actions button and its sheet from every result state.
- Keep the existing primary action: retry or replay after a loss/end, and the existing next-level or replay action after a win.
- Render Home and Upgrade directly beneath the primary action in one horizontal row.
- Give Home and Upgrade equal widths with the design system's standard spacing between them.
- Home routes to the Home screen. Upgrade routes to Upgrades.

## Home screen

- Place a circular Campaign icon button immediately to the left of the existing Next Match control.
- Give Campaign the same launch-control visual treatment, a centered campaign icon, a minimum accessible tap target, and a VoiceOver label.
- Let Next Match occupy all remaining horizontal space.
- Replace Campaign's former floating action with Progress.
- Keep only Locker and Upgrades in the bottom dock.
- Preserve the existing accessibility-size layout so labels and controls remain usable with large Dynamic Type.

## Implementation boundaries

- Reuse the existing button styles, theme metrics, routes, and audio feedback.
- Do not change game progression, result persistence, or destination behavior.
- Remove result-sheet code if it has no remaining callers.
- Preserve unrelated working-tree changes.

## Verification

- Update UI tests to assert that result actions are immediately available and More Actions is absent.
- Verify Home, Upgrade, Campaign, Progress, Locker, and Upgrades route correctly.
- Run focused tests for the affected result and Home flows, then run the relevant build validation.
