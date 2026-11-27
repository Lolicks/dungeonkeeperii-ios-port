/// Ported from OpenKeeper:
/// game/logic/BattleSystem.java:54-56 (battle grouping),
/// game/logic/SlapSystem.java:186-263 (slap damage/anger/sleep),
/// game/logic/CreatureTorturingSystem.java:158, 209 (torture),
/// game/task/creature/CollectPay.java:95-117 (pay collection).

import Foundation

public struct BattleRules: Sendable {
    public static let maxBattles = 8
    public static let joinRadiusTiles = 5
    public static let minimumStaySeconds = 4

    /// Creatures join an existing battle within Manhattan radius 5.
    public static func joinsBattle(creature: Tile, battleCenter: Tile) -> Bool {
        MapPathFinder.heuristic(from: creature, to: battleCenter) <= joinRadiusTiles
    }

    public static func canLeaveBattle(gameTime: Double, joinedAt: Double) -> Bool {
        gameTime - joinedAt >= Double(minimumStaySeconds)
    }
}

public struct SlapRules: Sendable {
    /// SlapSystem: damage is the raw attribute, anger is NOT divided by 4,
    /// and a slap reduces accumulated sleep debt.
    public static func apply(health: Int, maxHealth: Int, slapDamage: Int,
                             otherAnger: Int, slapAnger: Int,
                             sleepNeed: Int) -> (health: Int, anger: Int, sleepNeed: Int) {
        let newHealth = max(0, min(maxHealth, health - slapDamage))
        return (newHealth, otherAnger + slapAnger, max(0, sleepNeed - slapDamage))
    }
}

public struct TortureRules: Sendable {
    public static func moodChangePerSecond(emotionless: Bool,
                                           moodChange: Int) -> Int {
        emotionless ? 0 : moodChange
    }

    /// CreatureTorturingSystem line 158: instant kill applies current health.
    public static func instantKillDamage(health: Int) -> Int { health }
}

public struct CollectPayRules: Sendable {
    /// CollectPay: the creature keeps half of what it collected, capped.
    public static func keptByCreature(collected: Int, maxGold: Int,
                                      currentGold: Int) -> Int {
        min(collected / 2, max(0, maxGold - currentGold))
    }
}
