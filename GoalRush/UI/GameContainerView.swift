import SpriteKit
import SwiftUI

struct GameContainerView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var session: GameSessionModel
    @State private var scene: GoalRushScene
    @State private var showQuitConfirmation = false
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
        .onChange(of: session.eventPulse) { _, _ in
            for event in session.recentEvents { audio.handle(event) }
            let progress = session.hudState.elapsed / session.hudState.duration
            audio.updateIntensity(progress: progress, bossActive: session.hudState.bossActive)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                if session.phase == .playing { session.togglePause() }
                checkpointRunTokens()
            }
        }
        .confirmationDialog("End this run?", isPresented: $showQuitConfirmation, titleVisibility: .visible) {
            Button("End Run", role: .destructive) {
                let result = RunResult(
                    mode: session.mode,
                    didWin: false,
                    tokensEarned: session.snapshot.tokens,
                    remainingStamina: session.snapshot.stamina,
                    wave: session.snapshot.wave,
                    score: session.snapshot.score
                )
                store.finish(result, tokensAlreadyCredited: creditedRunTokens)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(session.mode.isEndless
                 ? "Training Tokens and your best wave are saved. Run powers reset."
                 : "Collected Training Tokens are kept, but level progress is lost.")
        }
        .onDisappear { audio.stop() }
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

                Button("Pause", systemImage: "pause.fill") { session.togglePause() }
                    .labelStyle(.iconOnly)
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.11), in: .circle)
                    .overlay { Circle().stroke(.white.opacity(0.18)) }
                    .contentShape(.circle)
                    .accessibilityIdentifier("pause")
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
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
        .background(GoalRushTheme.navy.opacity(0.40), in: .rect(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.15)) }
        .shadow(color: .black.opacity(0.28), radius: 14, y: 7)
    }

    private var pauseOverlay: some View {
        Color.black.opacity(0.70).ignoresSafeArea()
            .overlay {
                GameCard {
                    VStack(spacing: 20) {
                        Image(systemName: "pause.fill")
                            .font(.title2.bold())
                            .foregroundStyle(GoalRushTheme.navy)
                            .frame(width: 54, height: 54)
                            .background(GoalRushTheme.gold, in: .circle)
                            .shadow(color: GoalRushTheme.gold.opacity(0.30), radius: 12)
                        VStack(spacing: 5) {
                            Text("Run Paused").font(.title.bold())
                            Text(pauseSubtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Button("Resume Run", systemImage: "play.fill") { session.togglePause() }
                            .buttonStyle(PrimaryGameButton())
                            .accessibilityIdentifier("Resume")
                        Button("End Run", systemImage: "xmark.circle") { showQuitConfirmation = true }
                            .buttonStyle(SecondaryGameButton())
                            .tint(GoalRushTheme.orange)
                    }
                }
                .frame(maxWidth: 360)
                .padding(24)
            }
    }

    private var staminaColor: Color {
        let ratio = session.hudState.stamina / max(1, session.hudState.maxStamina)
        if ratio > 0.55 { return GoalRushTheme.positive }
        if ratio > 0.28 { return GoalRushTheme.gold }
        return GoalRushTheme.orange
    }

    private var levelProgress: Double {
        if session.mode.isEndless {
            return min(1, max(0, session.hudState.waveElapsed / max(1, session.hudState.waveDuration)))
        }
        return min(1, max(0, session.hudState.elapsed / max(1, session.hudState.duration)))
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
        store.finish(
            RunResult(
                mode: session.mode,
                didWin: didWin,
                tokensEarned: session.snapshot.tokens + bonus,
                remainingStamina: session.snapshot.stamina,
                wave: session.snapshot.wave,
                score: session.snapshot.score
            ),
            tokensAlreadyCredited: creditedRunTokens
        )
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

    private var progressLabel: String {
        if session.hudState.bossActive { return session.mode.isEndless ? "BOSS WAVE \(session.hudState.wave)" : "BOSS" }
        if session.mode.isEndless {
            return session.hudState.waveElapsed >= session.hudState.waveDuration
                ? "CLEAR WAVE \(session.hudState.wave)"
                : "WAVE \(session.hudState.wave)"
        }
        return "LEVEL \(session.levelNumber ?? 1)"
    }

    private var pauseSubtitle: String {
        if session.mode.isEndless {
            return "Wave \(session.hudState.wave) • \(session.hudState.score.formatted()) score"
        }
        return "Level \(session.levelNumber ?? 1) • \(session.hudState.tokens) tokens earned"
    }
}

private extension GameSessionModel.Phase {
    var isDraft: Bool {
        if case .draft = self { true } else { false }
    }
}
