# Strikernaut Progressive Stadium UI — Design

Date: 2026-07-22
Status: Approved for implementation

## Goal

Replace Strikernaut's card-heavy menu UI with an app-wide "stadium command
deck" language: atmospheric art remains visible, compact labeled controls
float above it, one action owns primary visual emphasis, and detailed
information appears only after the player asks for it.

The engagement systems added on the current branch remain intact. Daily
rewards, missions, achievements, upgrades, gear, stars, records, audio,
haptics, and celebration logic are reorganized rather than removed.

## Design rules

1. **Atmosphere first.** Full-bleed art is a stage, not wallpaper behind an
   opaque feed. Use localized scrims behind text and controls instead of a
   near-opaque whole-screen gradient.
2. **One hero action.** Only the best next step receives the orange/gold launch
   treatment. Other actions use restrained navy/cyan floating surfaces.
3. **Buttons explain the architecture.** Every destination has a visible icon
   and short label. Badges appear only for actionable states such as a reward,
   completed mission, affordable upgrade, new gear, or new trophy.
4. **Details on demand.** Mission lists, reward terms, upgrade comparisons,
   trophy requirements, rules, and set bonuses live in focused sheets.
5. **State-stable controls.** A control remains in the same place when its
   status changes. A badge or subtitle changes; the route does not disappear.
6. **Consistency without sameness.** Hub, selection, management, and utility
   screens share components and hierarchy while retaining layouts suited to
   their tasks.

## Screen families

### Command stage

Home uses `MenuHero` full-screen with:

- a token pill at top-leading and Settings at top-trailing;
- the Strikernaut title near the top;
- Daily and Missions as two labeled satellite buttons on the left;
- Campaign and Endless as two labeled satellite buttons on the right;
- one next-match launch button near the bottom;
- a three-item dock for Locker, Upgrades, and Progress.

At normal Dynamic Type sizes Home does not scroll. At accessibility sizes it
switches to a safe scrollable anchored layout that preserves every label and a
44-point minimum target.

Daily opens a preview sheet. Claiming happens inside that sheet, preventing an
accidental claim from the first tap. Missions opens a sheet containing the
three existing mission rows and inline claim actions. Mission rows do not
exist in Home's accessibility tree while the sheet is closed.

### Selection stage

Campaign and Endless retain atmospheric world art and use the same destination
top bar. Choices are compact first:

- Campaign shows Earth/Mars controls and compact level nodes. A level tap opens
  a focused preview with name, objective, rewards, stars, lock state, and Play.
- Endless shows Earth/Mars arena controls, the selected record, and one Start
  Run action. Rules remain behind an Info button.

The existing route identifiers (`play`, `endless`, `level-N`,
`endless-world-*`, and `start-endless`) remain stable for automation.

### Management stage

Locker and Upgrades expose selectable objects rather than all details:

- Locker keeps the character stage and visible slot controls. The selected
  item's effect and set progress move to sheets opened by explicit buttons.
- Upgrades shows six compact labeled track buttons grouped spatially around
  the stage. Rank and actionable state remain visible. Tapping a track opens
  its current-to-next comparison and purchase action in a sheet.

### Progress stage

The existing Trophies route becomes a user-facing Progress destination without
changing the route enum case. It combines:

- trophy completion;
- lifetime journey statistics currently in Settings;
- streak status;
- gear collection progress;
- the next attainable milestone.

Categories are visible as buttons; detailed trophy rows and statistics appear
in sheets. Settings returns to preferences, accessibility, onboarding support,
and reset controls.

### Focused overlays

- Result keeps the reward outcome and one Next/Retry button visible. Secondary
  destinations move behind a labeled More Actions control.
- Pause keeps Resume visually dominant. Missions collapse to one labeled
  summary button that opens mission detail; End Run remains visible and
  destructive.
- Ability Draft keeps the three authored choices but adopts shared surfaces,
  status badges, spacing, and press feedback.
- Onboarding keeps one concept per page and the existing completion behavior,
  using shared launch/surface styling.
- Gameplay remains a gameplay canvas. Only SwiftUI HUD and overlay surfaces
  inherit the shared tokens; SpriteKit composition and simulation do not
  change.

## Shared components

Create focused reusable SwiftUI types under `GoalRush/UI/DesignSystem/`:

- `AtmosphericGameScreen`: full-bleed named asset, localized top/bottom scrims,
  safe-area-aware overlay content.
- `GameDestinationBar`: visible Home control, centered title, token/status
  trailing pill.
- `FloatingGameActionButton`: icon, persistent label, optional subtitle and
  actionable badge, minimum 44-point activation target.
- `GameStatusBadge`: ready/new/count/completed presentation.
- `GameLaunchButtonStyle`: sole high-emphasis orange/gold launch treatment.
- `GameSheetScaffold`: consistent dark focused sheet with title, optional
  subtitle, scrollable content, and a visible Done control.
- `GameSurface`: semantic HUD, panel, and modal surface styles.

Extend `GoalRushTheme` with named metrics for spacing, corner radius, stroke,
shadow, localized scrims, and motion. Screens must consume these roles instead
of inventing new opacity/radius combinations.

## State and data flow

`GameStore` remains the owner of navigation, progression, settings, claims,
purchases, equipment, and persistence. The redesign does not duplicate domain
state in views.

Ephemeral disclosure is local view state:

- Home owns an optional `HomeSheet` enum.
- Campaign owns an optional selected level preview.
- Upgrades owns an optional selected upgrade track.
- Progress owns an optional progress category.
- Result owns a Boolean/enum for More Actions.

Closing or leaving a screen clears its disclosure state. Deep-link debug
arguments and the existing root route enum continue to work.

A small pure `HomePresentation` type derives the next-match destination and
action badges from `PlayerProgress`; tests pin campaign and campaign-complete
behavior independently of SwiftUI.

## Accessibility and responsive behavior

- Every interactive icon retains a visible text label.
- All activation targets are at least 44 by 44 points.
- Closed sheet content is absent from the accessibility tree.
- Dynamic Type is never constrained by fixed text heights. Accessibility
  sizes use anchored/scrollable fallbacks where spatial floating layouts would
  collide.
- VoiceOver order follows visual priority: resources, next action, daily
  actions, modes, clubhouse actions.
- Reduce Motion disables nonessential entrance, shimmer, scale, and parallax
  motion. Press feedback may use a short opacity change.
- Existing Reduce Flashes behavior remains unchanged.
- Decorative background art and status ornamentation remain hidden from
  accessibility.

## Empty, locked, and error states

- Locked levels and worlds remain visible, labeled with their unlock condition,
  and disabled.
- A claimed daily reward remains visible without a false actionable badge; its
  sheet explains when the next claim becomes available.
- No missions produces a neutral "Missions refresh soon" sheet state rather
  than an empty floating panel.
- Maximum upgrades remain selectable so their completed comparison can be
  inspected, but no purchase action appears.
- Gear slots with no earned choices remain selectable and explain how gear is
  earned.
- Failed or invalid domain actions retain existing store behavior and provide
  locked/warning audio without mutating progress.

## Testing and verification

### Unit

- next action is Level 1 for a new player;
- next action is the first unlocked incomplete campaign level;
- campaign completion falls back to Endless;
- home badge counts include only actionable unclaimed states.

### UI automation

- Home exposes all labeled action buttons without scrolling at the default
  destination.
- Mission rows are absent until Missions is tapped and absent again after the
  sheet closes.
- Daily reward opens before claiming; Collect updates the reward state.
- Campaign, Endless, Locker, Upgrades, Progress, and Settings remain reachable
  through their stable identifiers.
- Upgrade details are absent until a track button is tapped.
- Result secondary routes are absent until More Actions opens.

### Manual simulator

Verify each shared entry point on iPhone 17 Pro/iOS 26.5 at default and
Accessibility XXXL text sizes, with VoiceOver, Reduce Motion, and increased
contrast. Capture Home, Campaign, Endless, Locker, Upgrades, Progress,
Settings, Result, Pause, Draft, and Onboarding.

## Non-goals

- No new packages, backend, analytics, purchases, ads, or network calls.
- No changes to deterministic simulation, economy values, mission rules,
  achievement rules, progression storage schema, or SpriteKit gameplay art.
- No replacement of the existing approved image assets in this pass.

