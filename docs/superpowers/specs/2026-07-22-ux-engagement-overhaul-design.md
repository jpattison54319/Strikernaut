# Strikernaut UX & Engagement Overhaul — Design

Date: 2026-07-22
Status: Approved (Approach A: Foundation → Systems → Screens → Art/Polish)

## Goal

Turn Strikernaut from a well-built arcade game into a highly polished, highly
engaging one by applying modern UX/UI principles to every screen and modern
interaction design to every flow, plus ethical compulsion loops (variable
rewards, visible progress, always-a-next-goal) from contemporary game design.

## Decisions locked with the product owner

- Build all four engagement systems: in-run dopamine, daily rewards & streaks,
  missions, achievements.
- Generate new art where needed (onboarding, daily chest, badges); keep good
  existing assets.
- Lightweight FTUE: 3-page welcome, in-run coach marks, feel-good first win.
- Add menu/UI sound effects, synthesized locally as `.wav`, respecting the
  existing sound setting.
- Balance tuning is allowed (e.g. first-level forgiveness, early reward
  density).

## Design pillars

1. **Every action is acknowledged.** Any tap, kick, purchase, or claim produces
   visible + audible + haptic feedback inside 100 ms.
2. **Progress is always visible.** Bars, pips, streaks, and counts on every
   screen; no hidden advancement.
3. **There is always a next goal.** Missions, achievements, next unlock, and
   streaks are surfaced on Home so a session never ends without a reason to
   start another.
4. **Celebrate everything proportionally.** Big wins get full-screen moments;
   small wins get pops and ticks; losses stay constructive and point at the
   next step.
5. **Ethical compulsion only.** Variable rewards, goals, and streaks — but no
   punish-timers, no pay-to-continue, no notifications, no dark patterns. A
   missed day resets the streak count, never removes earned content.

## Architecture

Follows the existing pattern: `GameStore` owns navigation/progression; pure
testable domain types own rules; SwiftUI renders state. New code slots into
three places:

### 1. Domain — `GoalRush/Domain/Engagement/` (new, pure, testable)

- `LifetimeStats.swift` — Codable counters: `totalTokensEarned`, `totalRuns`,
  `totalWavesCleared`, `totalTargetsDefeated`, `bossesDefeated`, `bestCombo`,
  `upgradesPurchased`.
- `DailyRewardState.swift` — `lastClaimDay`, `streak`. Reward table indexed by
  streak day (caps at day 7, then repeats the day-7 reward). Claim logic takes
  an injected `Calendar`/`Date` for tests. Claiming again the same day is a
  no-op; missing a day resets `streak` to 1 on next claim.
- `Mission.swift` — `MissionKind` catalog (~10 kinds: defeat N targets, earn N
  tokens, reach wave N, clear N levels, draft N abilities, win with N% stamina,
  achieve combo N, …). `MissionState { kind, goal, progress, claimed }`.
  `MissionCatalog.dailyMissions(for: Date)` returns 3 deterministic missions
  seeded by the local day, so every device/day agrees and tests are stable.
  Mission goals scale slightly with `highestUnlockedLevel` so they stay
  attainable for new players and relevant for veterans.
- `Achievement.swift` — `AchievementID` (~16 milestones across campaign,
  endless, tokens, upgrades, gear, combo, streak). `AchievementCatalog`
  evaluates `PlayerProgress` → newly unlocked IDs, so unlocks are derived
  rather than event-driven (idempotent, migration-safe).

### 2. Persistence — `PlayerProgress` schema v3

New optional-decoded fields (same pattern as the v1→v2 migration):

- `lifetimeStats`, `dailyReward`, `missions` (+ `missionsDay` stamp),
- `unlockedAchievements: Set<AchievementID>`,
- `seenGearIDs: Set<GearID>` (drives Locker "NEW" badges),
- `hasSeenOnboarding: Bool`.

`reconcileUnlockedContent()` bumps `schemaVersion` to 3. Old saves decode with
safe defaults. Debug launch arg `--reset-onboarding` re-arms the FTUE.

### 3. Game feel — simulation + rendering

- **Combo system** in `GameSimulation`: defeating a target starts/extends a
  3.0 s window; each defeat inside the window increments `combo`. Combo adds a
  score bonus in Endless (`+10% per combo step, capped +100%`) and emits new
  `SimulationEvent`s: `comboChanged(Int)`, `comboMilestone(Int)` (shipped
  milestone set: 5/10/15/25/50/100),
  `targetDefeated(Vector2, isBoss)`. `HUDState` gains `combo`,
  `comboFraction` (window remaining). Combo resets on taking damage (risk/
  reward tension) and decays when the window lapses.
- **First-win forgiveness** (balance, approved): Level 1 enemy HP/speed
  scaled −15% and the first checkpoint grants +10 stamina, so a new player's
  first session ends in a clear. (Shipped checkpoint threshold is 0.40 — the
  heal must land before a stationary player takes lethal damage.)
- `GoalRushScene`: light screen shake on player damage and boss phase
  (skipped when `reducedEffects` or system Reduce Motion is on).

### 4. UI infrastructure — `GoalRush/UI/Juice/` (new)

- `UIAudio` (`GoalRush/App/UIAudio.swift`) — pooled `AVAudioPlayer` for menu
  SFX, mirrors `GameAudio`'s pooling, honors `soundEnabled`, no-op on missing
  files. New synthesized WAVs: `ui-tap`, `ui-whoosh`, `ui-purchase`,
  `ui-claim`, `ui-fanfare`, `ui-draft`, `ui-locked`, `ui-combo`. Generated by a
  committed `Tools/generate_ui_sfx.py` (standard library only, 16-bit PCM sine/
  arpeggio/noise-burst recipes matching the toy-like aesthetic).
- `CountUpText` — animates an integer 0→N over ~0.9 s with `.numericText`
  transition; used on Result and claim flows. Honors Reduce Motion (jumps
  straight to final).
- `FloatingTextOverlay` — SwiftUI layer above `SpriteView` translating
  simulation events (`reward`, `heal`, combo milestones, crits) into rising
  fade-out labels at normalized→view mapped positions. Capped at 12 live
  labels; reused via identified views. (Dropped in favor of in-scene
  presentations: the existing `spawnReward`/`spawnHeal` plus the new combo
  popup in `GoalRushScene`.)
- `ConfettiBurst` — `Canvas`-based particle celebration (single draw pass,
  capped particle count), used on Result wins, claims, and achievement toasts.
  Disabled under Reduce Motion.
- `AchievementToast` / `ClaimToast` — global overlay banners owned by
  `RootView`, queued from `GameStore`.
- Modifiers: `pulseGlow(when:)`, `shimmer()` (Reduce-Motion-aware), shared
  `BannerView`.

### 5. GameStore additions

- `claimDailyReward() -> Int?`, `claimMission(_:)`, `evaluateAchievements()`
  (called after every `finish`, `purchase`, `equip`, and claim),
- `pendingCelebrations: [Celebration]` queue driving toasts,
- `recordRunStats(_ result:)` folding run outcomes into `LifetimeStats` and
  mission progress,
- `completeOnboarding()`.

## Screen-by-screen design

### Onboarding (new, shows once)

Three swipeable pages over generated art: (1) "Welcome to Strikernaut" — fantasy
+ drag-to-aim; (2) "Draft powers every run" — roguelite promise; (3) "Get
stronger forever" — tokens → upgrades → gear. Final CTA drops into Level 1.
Coach marks during the first run reuse the existing "Drag to aim" pill, then a
one-time pulse on the stamina bar after first damage. After the first clear, a
"First Clear!" celebration routes to Upgrades with an affordable card
pre-highlighted. Skippable; `hasSeenOnboarding` persisted; never shown again.

### Home → becomes the daily hub

- Top: token pill + settings (unchanged pattern, plus UIAudio tap).
- **Continue hero card**: next campaign level (or "Start Endless" when
  campaign-complete) — one thumb-tap from launch to gameplay.
- **Daily reward chest**: generated chest art, `pulseGlow` when claimable,
  streak flame with count; tap → claim sheet with `CountUpText`, confetti,
  `ui-claim` + success haptic.
- **Missions strip**: 3 compact cards with progress rings; completed ones glow
  and can be claimed inline.
- Mode cards (Campaign/Endless) kept, restated statuses ("Next: Level 7",
  "Best wave 12").
- Utility row gains **Trophies** (achievements) entry.
- Achievement toasts overlay everything.

### Level Select

- Completed cards show 1–3 stars instead of only a check — replay motivation.
  Thresholds: 3 stars when best remaining stamina ≥ 70% of max, 2 stars at
  ≥ 35%, otherwise 1 star.
- First-clearable level card gets `shimmer` "READY" treatment.
- World progress bar under the world card (X/10 with fill).

### Endless Hub

- Personal-best wave/score gets a crown treatment; "Beat your best" target
  shown on the start button (`Start Run • Best: Wave 12`).

### Gameplay HUD & feedback

- **Combo meter**: thin arc/bar under stamina with count + decay; milestone
  popups ("COMBO ×10!") center-screen via `FloatingTextOverlay`; `ui-combo`
  ticks pitch-up per step (cap). (Shipped with milestone-only ticks instead
  of per-step pitch-up.)
- **Floating rewards**: `+N` token pops at defeat positions, crit calls, heal
  pops.
- **Damage feedback**: brief red edge vignette + screen shake (skipped under
  reduced effects); stamina bar pulse when low.
- **Boss banner**: "BOSS WAVE" slide-in with `boss-phase` sound (already
  exists) + haptic.
- **Wave clear banner** (Endless): "WAVE 7 CLEARED" + tokens earned flash
  before the draft appears (draft already follows checkpoint).
- Pause overlay: adds current missions mini-progress so pausing still shows
  goals.

### Ability Draft

- Cards stagger in (Reduce-Motion-aware), `ui-draft` on appearance.
- One card gets a subtle "RECOMMENDED" tag (heuristic: lowest current rank,
  tie-break to synergy with highest-damage ability).
- Endless cards at rank ≥ 5 get a gold "MASTERED SOON" shimmer frame — visible
  long-goal.

### Result

- Hero + `ConfettiBurst` on wins and new bests; defeat stays constructive:
  shows mission progress made and "tokens kept" prominently.
- `CountUpText` for tokens and score; `ui-fanfare` on new records.
- **NEW BEST** badge with burst when a personal record falls.
- **Stars** for campaign wins (1–3 by remaining stamina).
- **Next-goal teaser**: "120 tokens to Power Shot II" with a progress bar when
  an upgrade is within 1.5× of the token balance — converts the result high
  into an upgrade visit.
- Inline mission completions ("Mission complete: +150") fold into the token
  total.
- Primary CTA unchanged ("Play Next Level" / "Run It Back") — the loop stays
  one tap.

### Upgrades

- Affordable tracks glow with a "READY" pill; tapped purchase plays
  `ui-purchase`, success haptic, and a rank-pip fill animation; row flashes
  gold.
- Maxed tracks show a "MAX" seal.
- Unaffordable rows show a progress bar to the next rank ("340 / 500") instead
  of only greying out — every visit shows movement.

### Locker (Gear)

- Equipping plays `ui-tap` + haptic; newly unlocked (unseen) items get a
  "NEW" badge until viewed once (tracked in progress). (Shipped with
  slot-aggregate badge semantics — a per-item badge would self-clear when
  items are marked seen on appear.)

### Settings

- Existing toggles kept; adds "Replay Onboarding" (debug + support) and shows
  lifetime stats summary (runs, waves, best combo) as a pride panel.

### Achievements (new "Trophies" screen from Home)

- Sections by category; unlocked show date, locked show progress
  ("Wave 12 / 20"). Unlock triggers `AchievementToast` + `ui-fanfare` wherever
  the player is. (Shipped as a single ordered list — no sections or dates.)

## Audio & haptics

- UI SFX set synthesized by `Tools/generate_ui_sfx.py` (no network, no
  dependencies): short sine-marimba taps, filtered noise whoosh, two-note
  purchase chime, rising arpeggio claim/fanfare, low thud locked, pitch-laddered
  combo tick. Committed as WAVs under `GoalRush/Resources/Audio`.
- Haptics: menu taps keep `.selection`; claims/purchases `.success`; locked
  taps `.warning`; combo milestones reuse gameplay haptics in-run only.
- Music: existing 3-layer adaptive system untouched.

## Performance

- Floating labels capped at 12, confetti ≤ 60 particles, single `Canvas` draw;
  no per-particle `View` allocations during gameplay.
- HUD publish throttle (0.10 s) preserved; combo bar driven by the same tick.
- All celebration overlays render after phase transitions, never inside the
  SpriteKit update loop.
- Target: steady 60 fps on the test destination (iPhone 17 Pro, iOS 26.5).

## Accessibility

- Every new control labeled and identified (missions, chest, trophies, stars).
- Combo meter and confetti are `accessibilityHidden`; combo milestones are
  announced via a throttled `AccessibilityAnnouncement`.
- Reduce Motion disables shake, confetti, stagger, shimmer; Reduce Flashes
  also gates the damage vignette.
- Dynamic Type: all new cards use scalable type, no fixed text frames.

## Testing

- Unit (`GoalRushTests`):
  - v2→v3 migration decodes fixtures with defaults;
  - daily reward: claim, same-day no-op, streak increment, missed-day reset
    (injected calendar);
  - mission rotation deterministic for a fixed date; progress increments;
    claim awards tokens once;
  - achievement evaluation unlocks expected IDs from fixture progress;
  - combo: increments inside window, resets on damage/lapse, score bonus cap;
  - GameStore: claim/evaluate flows update progress and queue celebrations.
- UI (`GoalRushUITests`): onboarding appears once and completes; daily chest
  claims; mission claim updates tokens; result screen shows NEW BEST for
  preview args.
- Full `make verify` green before completion.

## Rollout (Approach A)

1. **Foundation**: progress v3 + migration tests; engagement domain types;
   `UIAudio` + SFX generation; Juice components (`CountUpText`,
   `FloatingTextOverlay`, `ConfettiBurst`, modifiers).
2. **Systems**: combo in simulation (+tests); daily/missions/achievements
   engines in GameStore (+tests); FTUE flow.
3. **Screens**: Home hub, Level Select, Endless Hub, HUD/gameplay feedback,
   Draft, Result, Upgrades, Locker, Settings, Trophies.
4. **Art + final polish**: generate chest/onboarding/badge art, integrate,
   performance + accessibility audit, full verify.

## Explicit non-goals

- No notifications, no Game Center, no ads, no purchases, no network.
- No punish mechanics: streaks reset counts only; nothing earned is lost.
- No changes to enemy/level design beyond the approved Level-1 forgiveness and
  combo scoring.
