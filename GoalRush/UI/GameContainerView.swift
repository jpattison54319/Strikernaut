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
            VStack(spacing: 10) {
                hud
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
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(.ultraThinMaterial, in: .capsule)
                        .overlay { Capsule().stroke(GoalRushTheme.cyan.opacity(0.45)) }
                        .shadow(color: GoalRushTheme.cyan.opacity(0.22), radius: 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

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
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: session.phase)
        .onChange(of: session.phase) { _, phase in
            if phase == .paused || phase.isDraft { checkpointRunTokens() }
            if phase == .finished { finishRun() }
        }
        .task {
            scene.eventHandler = handleSimulationEvents
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

    private var hud: some View {
        VStack(spacing: 9) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(staminaColor)
                        Text("STAMINA")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 4)
                        Text("\(Int(session.hudState.stamina))")
                            .font(.subheadline.bold())
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    ProgressView(value: session.hudState.stamina, total: session.hudState.maxStamina)
                        .tint(staminaColor)
                        .scaleEffect(y: 1.35)
                        .pulseGlow(session.hudState.stamina / max(1, session.hudState.maxStamina) <= 0.28, color: GoalRushTheme.orange)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Stamina \(Int(session.hudState.stamina)) of \(Int(session.hudState.maxStamina))")

                Rectangle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 1, height: 38)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("TOKENS")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Label("\(session.hudState.tokens)", systemImage: "hexagon.fill")
                        .font(.headline)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.snappy, value: session.hudState.tokens)
                }
                    .foregroundStyle(GoalRushTheme.gold)

                if session.hudState.shieldCharges > 0 {
                    Label("\(session.hudState.shieldCharges)", systemImage: "shield.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(GoalRushTheme.cyan)
                        .overlay(alignment: .topTrailing) {
                            Text("\(session.hudState.shieldCharges)")
                                .font(.caption2.bold())
                                .padding(3)
                                .background(GoalRushTheme.navy, in: .circle)
                                .offset(x: 8, y: -7)
                        }
                        .frame(width: 32)
                        .accessibilityLabel("\(session.hudState.shieldCharges) shield blocks")
                }

                Button("Pause", systemImage: "pause.fill") {
                    store.uiAudio.play(.whoosh, volume: 0.4)
                    session.togglePause()
                }
                    .labelStyle(.iconOnly)
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.11), in: .circle)
                    .overlay { Circle().stroke(.white.opacity(0.18)) }
                    .contentShape(.circle)
                    .accessibilityIdentifier("pause")
            }

            if session.hudState.combo > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.caption.bold())
                        .foregroundStyle(comboColor)
                    Text("COMBO ×\(session.hudState.combo)")
                        .font(.caption.bold())
                        .foregroundStyle(comboColor)
                        .contentTransition(.numericText())
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.12))
                            Capsule()
                                .fill(comboColor)
                                .frame(width: geometry.size.width * session.hudState.comboFraction)
                        }
                    }
                    .frame(height: 5)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Combo times \(session.hudState.combo)")
                .accessibilityIdentifier("combo-meter")
            }

            HStack(spacing: 9) {
                Text(progressLabel)
                    .font(.caption2.bold())
                    .foregroundStyle(session.hudState.bossActive ? GoalRushTheme.orange : .secondary)
                ProgressView(value: levelProgress)
                    .tint(session.hudState.bossActive ? GoalRushTheme.orange : GoalRushTheme.cyan)
                    .accessibilityIdentifier("run-progress")
                if session.mode.isEndless {
                    Label(session.hudState.score.formatted(), systemImage: "trophy.fill")
                        .font(.caption2.bold())
                        .monospacedDigit()
                        .foregroundStyle(GoalRushTheme.gold)
                        .frame(minWidth: 58, alignment: .trailing)
                        .accessibilityLabel("Score \(session.hudState.score)")
                } else {
                    Text("\(Int(levelProgress * 100))%")
                        .font(.caption2.bold())
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .trailing)
                }
            }
        }
        .padding(12)
        // A live material samples and blurs the SpriteKit surface whenever this
        // frequently-changing HUD redraws. An opaque game surface preserves the
        // visual hierarchy without forcing that expensive cross-framework pass.
        .background(hudBackground, in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(hudBorderColor, lineWidth: session.world.id == .mars ? 1.5 : 1)
        }
        .shadow(color: hudShadowColor, radius: 14, y: 7)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: session.hudState.combo > 0)
    }

    private var hudBackground: AnyShapeStyle {
        if session.world.id == .mars {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.035, blue: 0.20).opacity(0.95),
                        Color(red: 0.035, green: 0.09, blue: 0.18).opacity(0.93)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(GoalRushTheme.navy.opacity(0.90))
    }

    private var hudBorderColor: Color {
        session.world.id == .mars
            ? Color(red: 0.25, green: 0.88, blue: 1).opacity(0.42)
            : .white.opacity(0.15)
    }

    private var hudShadowColor: Color {
        session.world.id == .mars
            ? Color(red: 0.18, green: 0.72, blue: 1).opacity(0.18)
            : .black.opacity(0.28)
    }

    private var pauseOverlay: some View {
        Color.black.opacity(0.70).ignoresSafeArea()
            .overlay {
                VStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
                    Text("Run Paused")
                        .font(.title.bold())

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

    private func activateCharacterAbility() {
        guard session.hudState.characterAbilityReady else { return }
        store.uiAudio.play(.fanfare, volume: 0.75)
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

    private var comboColor: Color {
        switch session.hudState.combo {
        case 25...: return GoalRushTheme.orange
        case 10...: return GoalRushTheme.gold
        default: return GoalRushTheme.cyan
        }
    }

    private var levelProgress: Double {
        min(1, max(0, session.hudState.waveElapsed / max(1, session.hudState.waveDuration)))
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
        for event in events { audio.handle(event) }
        audio.updateIntensity(
            progress: snapshot.waveElapsed / max(1, snapshot.waveDuration),
            bossActive: snapshot.targets.contains { target in
                target.bossTier != .standard
            }
        )
    }

    private var progressLabel: String {
        if session.hudState.bossActive {
            return session.mode.isEndless
                ? "BOSS WAVE \(session.hudState.wave)"
                : "BOSS • WAVE \(session.hudState.wave) OF \(session.hudState.waveCount)"
        }
        if session.mode.isEndless {
            return session.hudState.waveElapsed >= session.hudState.waveDuration
                ? "CLEAR WAVE \(session.hudState.wave)"
                : "WAVE \(session.hudState.wave)"
        }
        return "WAVE \(session.hudState.wave) OF \(session.hudState.waveCount)"
    }

}

private extension GameSessionModel.Phase {
    var isDraft: Bool {
        if case .draft = self { true } else { false }
    }
}
