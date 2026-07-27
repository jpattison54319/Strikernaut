struct BossHazardState: Identifiable, Equatable, Sendable {
    let id: Int
    let kind: BossAttackKind
    let position: Vector2
    let halfWidth: Double
    let telegraphDuration: Double
    var telegraphRemaining: Double
    let activeDuration: Double
    var activeRemaining: Double
    let damage: Double
    var hasDamagedPlayer = false

    var isActive: Bool {
        telegraphRemaining <= 0 && activeRemaining > 0
    }

    var isFinished: Bool {
        telegraphRemaining <= 0 && activeRemaining <= 0
    }

    var telegraphProgress: Double {
        guard telegraphDuration > 0 else { return 1 }
        return min(1, max(0, 1 - telegraphRemaining / telegraphDuration))
    }
}
