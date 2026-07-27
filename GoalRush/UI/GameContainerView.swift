import SpriteKit
import SwiftUI

struct GameContainerView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var session: GameSessionModel
    @State private var scene: GoalRushScene
    @State private var audio: GameAudio
    @State private var creditedRunTokens = 0

    init(mode: RunMode, progress: PlayerProgress, settings: GameSettings) {
        let session = GameSessionModel(mode: mode, progress: progress, settings: settings)
        _session = State(initialValue: session)
        _scene = State(initialValue: GoalRushScene(session: session, reducedEffects: settings.reducedFlashes))
        _audio = State(initialValue: GameAudio(settings: settings))
    }

    var body: some View {
        ZStack {
            SpriteView(scene: scene, isPaused: session.phase == .paused, preferredFramesPerSecond: 60)
                .ignoresSafeArea()
                .accessibilityLabel("Active soccer training run")
            VStack(spacing: 6) {
                GameplayStatusBar(
                    world: session.world.id,
                    stamina: session.hudState.stamina,
                    maxStamina: session.hudState.maxStamina,
                    staminaTint: staminaColor,
                    tokens: session.hudState.tokens,
                    shieldCharges: session.hudState.shieldCharges,
                    pause: pauseRun
                )

                HStack(alignment: .center, spacing: GoalRushTheme.Metrics.compactSpacing) {
                    WaveObjectiveHUD(
                        world: session.world.id,
                        wave: session.hudState.wave,
                        waveCount: session.hudState.waveCount,
                        remainingEnemies: session.hudState.remainingEnemies,
                        isEndless: session.mode.isEndless,
                        isBossWave: session.hudState.isBossWave
                    )

                    Spacer(minLength: GoalRushTheme.Metrics.compactSpacing)

                    if session.hudState.combo > 0 {
                        FloatingComboView(combo: session.hudState.combo)
                            .transition(
                                reduceMotion
                                    ? .opacity
                                    : .scale(scale: 0.86, anchor: .topTrailing)
                                        .combined(with: .opacity)
                            )
                    }
                }
                .frame(minHeight: 38)

                if let ability = session.hudState.activeTemporaryAbility {
                    HStack {
                        Spacer()
                        TemporaryAbilityTimerView(
                            ability: ability,
                            remaining: session.hudState.temporaryAbilityRemaining,
                            duration: session.hudState.temporaryAbilityDuration
                        )
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                Spacer()
                if session.mode.isEndless && session.hudState.elapsed < 5 && session.phase == .playing {
                    Label("Drag to aim", systemImage: "hand.draw.fill")
                        .font(GoalRushTheme.Typography.subheadlineEmphasized)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(GoalRushTheme.surfaceRaised.opacity(0.94), in: ComicPanelShape(cut: 7))
                        .overlay {
                            ComicPanelShape(cut: 7)
                                .stroke(GoalRushTheme.cyan.opacity(0.62), lineWidth: 2)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .animation(
                reduceMotion ? .easeOut(duration: 0.16) : .snappy(duration: 0.20),
                value: session.hudState.combo > 0
            )

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    CharacterAbilityButton(
                        character: session.character,
                        charge: session.hudState.characterAbilityCharge,
                        isReady: session.hudState.characterAbilityReady,
                        activate: activateCharacterAbility
                    )
                }
            }
            .padding(.trailing, 18)
            .padding(.bottom, 116)
            .allowsHitTesting(session.phase == .playing)

            if case .briefing(let discoveries) = session.phase, let level = session.level {
                CampaignBriefingView(level: level, discoveries: discoveries, session: session)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            if case .draft(let abilities) = session.phase {
                AbilityDraftView(abilities: abilities, session: session)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            if session.phase == .paused {
                pauseOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            if case .worldTransition(let from, let to, _) = session.phase {
                EndlessWorldTransitionView(
                    from: from,
                    to: to,
                    hapticsEnabled: store.settings.hapticsEnabled,
                    onComplete: session.completeWorldTransition
                )
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: session.phase)
        .onChange(of: session.phase) { _, phase in
            if phase == .paused || phase.isDraft { checkpointRunTokens() }
            if phase == .finished { finishRun() }
        }
        .task {
            scene.eventHandler = handleSimulationEvents
            if case .briefing = session.phase, let levelNumber = session.levelNumber {
                store.markCampaignBriefingSeen(level: levelNumber)
            }
            await Task.yield()
            await audio.prepare()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                if session.phase == .playing { session.togglePause() }
                checkpointRunTokens()
            }
        }
        .onDisappear {
            scene.eventHandler = nil
            audio.stop()
        }
    }

    private var pauseOverlay: some View {
        Color.black.opacity(0.70).ignoresSafeArea()
            .overlay {
                VStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
                    Text("Run Paused")
                        .font(GoalRushTheme.Typography.title)

                    Button("Continue", action: continueRun)
                    .buttonStyle(GameLaunchButtonStyle())
                    .accessibilityIdentifier("pause-continue")

                    HStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                        Button("Home", action: leaveForHome)
                            .buttonStyle(SecondaryGameButton())
                            .accessibilityIdentifier("pause-home")

                        Button("Retry", action: retryRun)
                            .buttonStyle(SecondaryGameButton())
                            .accessibilityIdentifier("pause-retry")
                    }
                }
                .padding(GoalRushTheme.Metrics.sectionSpacing)
                .gameSurface(.modal)
                .frame(maxWidth: 360)
                .padding(24)
            }
    }

    private func continueRun() {
        store.uiAudio.play(.tap)
        session.togglePause()
    }

    private func pauseRun() {
        store.uiAudio.play(.whoosh, volume: 0.4)
        session.togglePause()
    }

    private func activateCharacterAbility() {
        guard session.hudState.characterAbilityReady else { return }
        store.uiAudio.play(.fanfare, volume: 0.75, feedback: nil)
        session.activateCharacterAbility()
    }

    private func leaveForHome() {
        store.uiAudio.play(.tap)
        checkpointRunTokens()
        store.route = .home
    }

    private func retryRun() {
        store.uiAudio.play(.tap)
        checkpointRunTokens()
        scene.eventHandler = nil

        let replacementSession = GameSessionModel(
            mode: session.mode,
            progress: store.progress,
            settings: store.settings
        )
        let replacementScene = GoalRushScene(
            session: replacementSession,
            reducedEffects: store.settings.reducedFlashes
        )
        replacementScene.eventHandler = handleSimulationEvents
        creditedRunTokens = 0
        session = replacementSession
        scene = replacementScene
    }

    private var staminaColor: Color {
        let ratio = session.hudState.stamina / max(1, session.hudState.maxStamina)
        if ratio > 0.55 { return GoalRushTheme.positive }
        if ratio > 0.28 { return GoalRushTheme.gold }
        return GoalRushTheme.orange
    }

    private func buildResult(didWin: Bool, bonus: Int = 0) -> RunResult {
        RunResult(
            mode: session.mode,
            didWin: didWin,
            tokensEarned: session.snapshot.tokens + bonus,
            remainingStamina: session.snapshot.stamina,
            wave: session.snapshot.wave,
            score: session.snapshot.score,
            targetsDefeated: session.snapshot.targetsDefeated,
            bossesDefeated: session.snapshot.bossesDefeated,
            bestCombo: session.snapshot.bestCombo,
            abilitiesDrafted: session.draftsChosen,
            staminaFraction: session.snapshot.stamina / max(1, session.snapshot.maxStamina)
        )
    }

    private func finishRun() {
        guard case .finished(let didWin) = session.lastEvent else { return }
        let bonus: Int
        if let level = session.level {
            let wasCompleted = store.progress.levelRecords[level.number]?.completed == true
            bonus = didWin ? (wasCompleted ? level.replayBonus : level.firstClearBonus) : 0
        } else {
            bonus = 0
        }
        store.finish(buildResult(didWin: didWin, bonus: bonus), tokensAlreadyCredited: creditedRunTokens)
    }

    private func checkpointRunTokens() {
        let uncredited = max(0, session.snapshot.tokens - creditedRunTokens)
        guard uncredited > 0 else {
            store.saveProgress()
            return
        }
        store.creditRunTokens(uncredited)
        creditedRunTokens += uncredited
        store.saveProgress()
    }

    private func handleSimulationEvents(_ events: [SimulationEvent], snapshot: SimulationSnapshot) {
        audio.handle(events)
        audio.updateIntensity(
            progress: snapshot.waveObjectiveProgress,
            bossActive: snapshot.targets.contains { target in
                target.bossTier != .standard
            }
        )
    }

}

private extension GameSessionModel.Phase {
    var isDraft: Bool {
        if case .draft = self { true } else { false }
    }
}
