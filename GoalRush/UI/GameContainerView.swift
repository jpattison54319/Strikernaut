import SpriteKit
import SwiftUI

struct GameContainerView: View {
    @Environment(GameStore.self) private var store
    @Environment(RewardedAdService.self) private var rewardedAds
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var session: GameSessionModel
    @State private var scene: GoalRushScene
    @State private var audio: GameAudio
    @State private var creditedRunTokens = 0
    @State private var lastCheckpoint: RunCheckpoint?
    @State private var checkpointWriteTask: Task<Void, Never>?
    @State private var savedRunWasInvalidatedByDeath = false
    @State private var isRestarting = false
    @State private var isFinalizing = false

    init(
        mode: RunMode,
        progress: PlayerProgress,
        settings: GameSettings,
        checkpoint: RunCheckpoint? = nil
    ) {
        let session = GameSessionModel(
            mode: mode,
            progress: progress,
            settings: settings,
            checkpoint: checkpoint
        )
        _session = State(initialValue: session)
        _scene = State(initialValue: GoalRushScene(session: session, reducedEffects: settings.reducedFlashes))
        _audio = State(initialValue: GameAudio(settings: settings))
        _creditedRunTokens = State(
            initialValue: checkpoint?.creditedRunTokens ?? 0
        )
        _lastCheckpoint = State(initialValue: checkpoint)
    }

    var body: some View {
        ZStack {
            SpriteView(
                scene: scene,
                isPaused: shouldPauseScene,
                preferredFramesPerSecond: 60
            )
                .ignoresSafeArea()
                .accessibilityLabel("Active soccer training run")
                .accessibilityHidden(session.phase != .playing)
            VStack(spacing: 6) {
                GameplayStatusBar(
                    world: session.world.id,
                    stamina: session.hudState.stamina,
                    maxStamina: session.hudState.maxStamina,
                    staminaTint: staminaColor,
                    tokens: session.hudState.tokens,
                    endlessScore: session.mode.isEndless
                        ? session.hudState.score
                        : nil,
                    shieldCharges: session.hudState.shieldCharges,
                    pause: pauseRun
                )
                .allowsHitTesting(session.phase == .playing)

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
            .accessibilityHidden(session.phase != .playing)

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
            .accessibilityHidden(session.phase != .playing)

            if case .briefing(let discoveries) = session.phase, let level = session.level {
                CampaignBriefingView(level: level, discoveries: discoveries, session: session)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            if case .draft(let choices) = session.phase {
                AbilityDraftView(choices: choices, session: session)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            if session.phase == .paused {
                pauseOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            if session.phase == .deathSaveOffer {
                DeathSaveOfferView(
                    mode: session.mode,
                    wave: session.hudState.wave,
                    continueRun: continueAfterDeathSave,
                    finishRun: finishWithoutDeathSave
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(30)
            }
            if session.phase == .deathSaveCountdown {
                DeathSaveCountdownView(
                    secondsRemaining: session.deathSaveCountdownSeconds
                )
                .transition(.opacity)
                .zIndex(30)
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
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains(
                "--gameplay-runtime-probe"
            ) {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityLabel("Gameplay runtime")
                    .accessibilityValue(
                        "\(Int(session.hudState.elapsed * 10))"
                    )
                    .accessibilityIdentifier("gameplay-runtime-probe")
            }
#endif
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: session.phase)
        .onChange(of: session.phase) { _, phase in
            synchronizeScenePlayback()
            if phase.isRunCheckpointBoundary {
                checkpointRunTokens()
                persistWaveCheckpoint()
            } else if phase == .deathSaveOffer {
                checkpointRunTokens()
                invalidateSavedRunAfterDeath()
            } else if phase == .paused {
                checkpointRunTokens()
                persistCheckpointMetadata()
            }
            if phase == .finished { finishRun() }
        }
        .onAppear(perform: handleContainerAppearance)
        .task {
            if case .briefing = session.phase, let levelNumber = session.levelNumber {
                store.markCampaignBriefingSeen(level: levelNumber)
            }
            await Task.yield()
            await audio.prepare()
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            synchronizeScenePlayback()
            await audio.resumeHaptics()
        }
        .task(id: rewardedAds.isPresenting) {
            await handleRewardedAdPresentationChange()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                if session.phase == .playing { session.togglePause() }
                checkpointRunTokens()
                persistCheckpointMetadata()
            }
            synchronizeScenePlayback()
        }
        .onDisappear(perform: handleContainerDisappearance)
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
                            .disabled(isRestarting)
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
        synchronizeScenePlayback()
    }

    private func pauseRun() {
        store.uiAudio.play(.whoosh, volume: 0.4)
        session.togglePause()
        synchronizeScenePlayback()
    }

    private func continueAfterDeathSave() {
        guard session.continueAfterDeathSave() else { return }
        synchronizeScenePlayback()
        restoreSavedRunAfterRewardedContinue()
        store.uiAudio.play(.fanfare, volume: 0.7)
    }

    private func finishWithoutDeathSave() {
        store.uiAudio.play(.locked, volume: 0.65)
        session.declineDeathSave()
    }

    private func activateCharacterAbility() {
        guard session.hudState.characterAbilityReady else { return }
        store.uiAudio.play(.fanfare, volume: 0.75, feedback: nil)
        session.activateCharacterAbility(
            cinematic: !reduceMotion && !store.settings.reducedFlashes
        )
    }

    private func leaveForHome() {
        store.uiAudio.play(.tap)
        checkpointRunTokens()
        persistCheckpointMetadata()
        scene.prepareForRemoval()
        store.route = .home
    }

    private func retryRun() {
        guard !isRestarting else { return }
        store.uiAudio.play(.tap)
        checkpointRunTokens()
        scene.prepareForRemoval()
        checkpointWriteTask?.cancel()
        checkpointWriteTask = nil
        isRestarting = true

        Task {
            try? await store.runCheckpointStore.delete(for: session.mode)
            guard !Task.isCancelled else { return }

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
            lastCheckpoint = nil
            session = replacementSession
            scene = replacementScene
            synchronizeScenePlayback()
            isRestarting = false
        }
    }

    private var shouldPauseScene: Bool {
        scenePhase != .active
            || rewardedAds.isPresenting
            || session.phase.pausesScene
    }

    private func synchronizeScenePlayback() {
        scene.synchronizePlayback(isPaused: shouldPauseScene)
    }

    private func handleContainerAppearance() {
        scene.eventHandler = handleSimulationEvents
        synchronizeScenePlayback()
    }

    private func handleContainerDisappearance() {
        if rewardedAds.isPresenting {
            scene.synchronizePlayback(isPaused: true)
            return
        }
        scene.prepareForRemoval()
        audio.stop()
    }

    private func handleRewardedAdPresentationChange() async {
        if rewardedAds.isPresenting {
            scene.synchronizePlayback(isPaused: true)
            return
        }

        // Let the full-screen presenter finish restoring the underlying view
        // before clearing SpriteKit's own pause state.
        await Task.yield()
        guard !Task.isCancelled, !rewardedAds.isPresenting else { return }
        scene.eventHandler = handleSimulationEvents
        synchronizeScenePlayback()
        if scenePhase == .active {
            await audio.resumeHaptics()
        }
    }

    private var staminaColor: Color {
        let ratio = session.hudState.stamina / max(1, session.hudState.maxStamina)
        if ratio > 0.55 { return GoalRushTheme.positive }
        if ratio > 0.28 { return GoalRushTheme.gold }
        return GoalRushTheme.orange
    }

    private func buildResult(didWin: Bool, bonus: Int = 0) -> RunResult {
        RunResult(
            runID: session.runID,
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
            character: session.character.id,
            characterAbilityDefeats: session.snapshot.characterAbilityDefeats,
            staminaFraction: session.snapshot.stamina / max(1, session.snapshot.maxStamina)
        )
    }

    private func finishRun() {
        guard !isFinalizing else { return }
        guard case .finished(let didWin) = session.lastEvent else { return }
        isFinalizing = true
        let bonus: Int
        if let level = session.level {
            let wasCompleted = store.progress.hasClearedCurrentCampaignLevel(
                level.number
            )
            let baseBonus = wasCompleted ? level.replayBonus : level.firstClearBonus
            bonus = didWin
                ? CampaignDifficulty.scaledCompletionBonus(
                    baseBonus,
                    cycle: session.campaignCycle
                )
                : 0
        } else {
            bonus = 0
        }
        let result = buildResult(didWin: didWin, bonus: bonus)
        scene.prepareForRemoval()
        checkpointWriteTask?.cancel()
        checkpointWriteTask = nil
        Task {
            try? await store.runCheckpointStore.delete(for: session.mode)
            guard !Task.isCancelled else { return }
            lastCheckpoint = nil
            store.finish(
                result,
                tokensAlreadyCredited: creditedRunTokens
            )
        }
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

    private func persistWaveCheckpoint() {
        guard !savedRunWasInvalidatedByDeath else { return }
        guard lastCheckpoint?.wave != session.snapshot.wave,
              let checkpoint = session.makeRunCheckpoint(
                creditedRunTokens: creditedRunTokens,
                previous: lastCheckpoint
              ) else {
            return
        }
        lastCheckpoint = checkpoint
        enqueueCheckpointWrite(checkpoint)
    }

    private func persistCheckpointMetadata() {
        guard !savedRunWasInvalidatedByDeath else { return }
        guard let checkpoint = lastCheckpoint else { return }
        let updated = checkpoint.updatingRunMetadata(
            creditedRunTokens: creditedRunTokens,
            deathSaveWasUsed: session.deathSaveWasUsed
        )
        guard updated.creditedRunTokens != checkpoint.creditedRunTokens
                || updated.deathSaveWasUsed != checkpoint.deathSaveWasUsed else {
            return
        }
        lastCheckpoint = updated
        enqueueCheckpointWrite(updated)
    }

    private func invalidateSavedRunAfterDeath() {
        savedRunWasInvalidatedByDeath = true
        checkpointWriteTask?.cancel()
        checkpointWriteTask = Task {
            try? await store.runCheckpointStore.invalidateAfterDeath(
                for: session.mode
            )
        }
    }

    private func restoreSavedRunAfterRewardedContinue() {
        guard savedRunWasInvalidatedByDeath,
              let checkpoint = lastCheckpoint else {
            return
        }
        let restored = checkpoint.updatingRunMetadata(
            creditedRunTokens: creditedRunTokens,
            deathSaveWasUsed: true
        )
        savedRunWasInvalidatedByDeath = false
        lastCheckpoint = restored
        checkpointWriteTask?.cancel()
        checkpointWriteTask = Task {
            // Always finish the death invalidation before making the rewarded
            // continuation resumable. Closing the app before the reward callback
            // therefore leaves no live checkpoint to exploit.
            try? await store.runCheckpointStore.invalidateAfterDeath(
                for: session.mode
            )
            guard !Task.isCancelled else { return }
            try? await store.runCheckpointStore.save(restored)
        }
    }

    private func enqueueCheckpointWrite(_ checkpoint: RunCheckpoint) {
        checkpointWriteTask?.cancel()
        checkpointWriteTask = Task {
            try? await store.runCheckpointStore.save(checkpoint)
        }
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

    var pausesScene: Bool {
        switch self {
        case .paused, .deathSaveOffer, .finished:
            true
        default:
            false
        }
    }

    var isRunCheckpointBoundary: Bool {
        switch self {
        case .draft, .worldTransition:
            true
        default:
            false
        }
    }
}
