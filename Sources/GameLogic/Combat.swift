/// Ported from OpenKeeper:
/// game/controller/entity/EntityController.java:225-279 (damage scaling),
/// game/logic/HealthSystem.java:163-239, 440-551 (health changes),
/// game/controller/creature/CombatRules.java:60-79 (rear attack bonus),
/// game/logic/CreatureExperienceSystem.java:166-228,
/// game/controller/CreaturesController.java:634-727 (level scaling).

import Foundation

public struct DamageConfig: Sendable {
    public var possessed = false
    public var hasArmour = false
    public var frozen = false
    public var stunned = false
    public var fallen = false
    public var gettingUp = false
    public var invulnerable = false

    public init() {}
}

public enum DamageRules {
    /// EntityController.scaleDamage (lines 255-279). Multiplier in 128ths.
    public static func scale(_ amount: Int, config: DamageConfig) -> Int {
        if amount <= 0 { return amount }  // healing is never scaled
        var multiplier = 128
        if config.possessed || config.hasArmour { multiplier -= 64 }
        if config.frozen { multiplier += 32 }
        if !config.frozen && (config.stunned || config.fallen || config.gettingUp) {
            multiplier += 128
        }
        let scaled = Int64(amount) * Int64(multiplier) / 128
        return Int(min(Int64(Int.max), scaled))
    }

    public static func applyExisting(existing: Int, amount: Int,
                                     config: DamageConfig) -> Int {
        if amount > 0 && config.invulnerable { return existing }
        return existing + scale(amount, config: config)
    }
}

public struct HealthRules: Sendable {
    /// HealthSystem.calculateHealthChange: clamp to [0, maxHealth], death at 0.
    public static func apply(health: Int, maxHealth: Int, damage: Int,
                             regeneration: Int = 0, healing: Int = 0) -> (health: Int, dead: Bool) {
        let value = max(0, min(maxHealth, health - damage + regeneration + healing))
        return (value, value <= 0)
    }

    /// HealthSystem: non-workers below 20% max health attack at half speed.
    public static func attacksDelayed(health: Int, maxHealth: Int, isWorker: Bool) -> Bool {
        !isWorker && health < maxHealth * 20 / 100
    }

    public static func delayedAttackStartTime(current: Double, tpf: Double) -> Double {
        current + tpf / 2
    }
}

public enum CombatRules {
    public static let maxMeleeAttackers = 8
    public static let maxRangedAttackers = 8
    private static let halfCircleSteps = 1024
    private static let stepsPerBonusPercent = 20
    public static let minRearBonusPercent = 16

    /// CombatRules.addRearAttackBonus (lines 60-79).
    public static func rearAttackBonus(damage: Int, dot: Double,
                                       facingLength: Double, directionLength: Double) -> Int {
        let denominator = facingLength * directionLength
        guard denominator > 0 else { return damage }
        let raw = max(-1.0, min(1.0, dot / denominator))
        let angle = acos(raw)
        let steps = min(halfCircleSteps - 1,
                        Int(angle / Double.pi * Double(halfCircleSteps)))
        let bonusPercent = steps / stepsPerBonusPercent
        guard bonusPercent >= minRearBonusPercent else { return damage }
        return damage + damage * bonusPercent / 100
    }

    public static func canBeHurt(targetIsHorny: Bool, targetOnlyHorny: Bool,
                                 attackerIsHorny: Bool) -> Bool {
        if targetIsHorny { return false }
        if targetOnlyHorny { return attackerIsHorny }
        return true
    }
}

public struct ExperienceRules: Sendable {
    public static let maxCreatureLevel = 10

    public static func fightingGain(experiencePerSecond: Int, ticksPerSecond: Int) -> Int {
        guard experiencePerSecond > 0 else { return 0 }
        return max(1, experiencePerSecond / ticksPerSecond)
    }

    public static func trainingGain(perTick: Int, experience: Int,
                                    experienceToNextLevel: Int) -> Int {
        max(0, min(perTick, experienceToNextLevel - experience))
    }

    public static func loseExperience(_ experience: Int, lossPerTick: Int) -> Int {
        max(0, experience - min(lossPerTick, experience))
    }

    public static func addExperience(_ experience: Int, level: Int,
                                     experienceToNextLevel: Int) -> (level: Int, experience: Int) {
        if experience >= experienceToNextLevel {
            return (min(maxCreatureLevel, level + 1), 0)
        }
        return (level, experience)
    }

    /// CreaturesController.scaleByLevel: value * percent / 100.
    public static func scaledByLevel(_ value: Int, levelPercent: Int) -> Int {
        value * levelPercent / 100
    }

    public static func pointsPerTick(pointsPerSecond: Int, ticksPerSecond: Int) -> Int {
        max(1, pointsPerSecond / max(1, ticksPerSecond))
    }
}
