import Foundation

struct GearModifiers: Equatable, Sendable {
    var staminaBonus = 0.0
    var movementMultiplier = 1.0
    var kickCooldownMultiplier = 1.0
    var damageMultiplier = 1.0
    var ballSpeedMultiplier = 1.0
    var criticalChanceBonus = 0.0
    var homingStrength = 0.0
    var startingShields = 0
    var extraPierce = 0
    var tokenMultiplier = 1.0

    mutating func combine(_ other: GearModifiers) {
        staminaBonus += other.staminaBonus
        movementMultiplier *= other.movementMultiplier
        kickCooldownMultiplier *= other.kickCooldownMultiplier
        damageMultiplier *= other.damageMultiplier
        ballSpeedMultiplier *= other.ballSpeedMultiplier
        criticalChanceBonus += other.criticalChanceBonus
        homingStrength += other.homingStrength
        startingShields += other.startingShields
        extraPierce += other.extraPierce
        tokenMultiplier *= other.tokenMultiplier
    }
}
