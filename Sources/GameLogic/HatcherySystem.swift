/// Ported from OpenKeeper:
/// game/logic/ChickenSpawnSystem.java:84-86, 148-178, 188-211
/// game/controller/chicken/ChickenController.java:198-223.

import Foundation

public struct HatcheryConfig: Sendable {
    public var firstChickenDelay: Double = 10
    public var maxFreeRange: Int = 4
    public var roomCapacity: Int = 8
    public var ticksPerSecond: Int = 20

    public init() {}
}

public struct HatcheryState: Sendable {
    public var chickens: Int = 0
    public var lastSpawnTime: Double = 0
    public var timeElapsed: Double = 0

    public init() {}
}

public enum HatcherySystem {
    /// evaluateAndSpawnCreature (lines 148-178): spawn when cooldown elapsed
    /// and the room is not full; otherwise allow free-range up to a cap.
    public static func evaluate(config: HatcheryConfig, state: inout HatcheryState,
                                tiles: Int) -> Bool {
        let cooldown = ChickenSpawnRules.cooldown(tiles: tiles,
                                                  firstDelay: config.firstChickenDelay)
        let isFirst = state.lastSpawnTime == 0
        let due = state.timeElapsed - state.lastSpawnTime >= cooldown || (isFirst && state.timeElapsed >= config.firstChickenDelay)
        if due && state.chickens < config.roomCapacity {
            state.chickens += 1
            state.lastSpawnTime = state.timeElapsed
            return true
        }
        if state.chickens < config.maxFreeRange && state.timeElapsed >= config.firstChickenDelay {
            state.chickens += 1
            state.lastSpawnTime = state.timeElapsed
            return true
        }
        return false
    }

    /// ChickenController.isTimeToReEvaluate (line 198): motionless >= 5 s.
    public static func shouldReEvaluate(motionless: Double) -> Bool {
        motionless >= 5
    }

    /// ChickenController.isStateTimeExceeded (lines 211-223):
    /// HATCHING_* needs one animation duration, PECKING needs two.
    public static func stateTimeExceeded(elapsed: Double, animationSeconds: Double,
                                         pecking: Bool) -> Bool {
        elapsed >= animationSeconds * (pecking ? 2 : 1)
    }
}
