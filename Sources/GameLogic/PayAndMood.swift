/// Ported from OpenKeeper:
/// game/logic/PayDaySystem.java:102-257 (payday clock, wages, anger),
/// game/logic/CreatureMoodSystem.java:63-221 (anger accumulation),
/// game/component/CreatureMood.java:143-155 (/4 conversions).

import Foundation

public struct PayDayClock: Sendable {
    public var nextPayDay: Double
    public var lastPayDay: Double
    public var ticksLeft: Int
    public var period: Int
    public var cost: Int

    public init(nextPayDay: Double, lastPayDay: Double,
                ticksLeft: Int = 0, period: Int = 0, cost: Int = 0) {
        self.nextPayDay = nextPayDay
        self.lastPayDay = lastPayDay
        self.ticksLeft = ticksLeft
        self.period = period
        self.cost = cost
    }
}

public struct PayDayRules: Sendable {
    public let timeBeforeFirstPayDay: Double
    public let payDayFrequency: Double
    public let cutOffTime: Double

    public init(timeBeforeFirstPayDay: Double = 600,
                payDayFrequency: Double = 600,
                cutOffTime: Double = 120) {
        self.timeBeforeFirstPayDay = timeBeforeFirstPayDay
        self.payDayFrequency = payDayFrequency
        self.cutOffTime = cutOffTime
    }

    /// PayDaySystem.startPayDayClock (lines 183-192).
    public func startClock(gameTime: Double) -> PayDayClock {
        PayDayClock(nextPayDay: gameTime + timeBeforeFirstPayDay,
                    lastPayDay: gameTime)
    }

    /// Skip when the next payday is closer than the cut-off (lines 175-181).
    public func shouldSkip(gameTime: Double, clock: PayDayClock) -> Bool {
        clock.nextPayDay - gameTime < cutOffTime
    }

    /// PayDaySystem.payDay (lines 194-205).
    public func payDay(gameTime: Double, clock: inout PayDayClock) {
        clock.nextPayDay = gameTime + payDayFrequency
        clock.lastPayDay = gameTime
    }

    /// updatePayDayClocks (lines 137-148): ceil/round of remaining time.
    public mutating func updateClock(_ clock: inout PayDayClock, gameTime: Double, cost: Int) {
        clock.ticksLeft = Int(ceil(clock.nextPayDay - gameTime))
        clock.period = Int((clock.nextPayDay - clock.lastPayDay).rounded())
        clock.cost = cost
    }

    public func addWage(unpaid: Int, pay: Int, skipNextPayDay: Bool) -> Int {
        skipNextPayDay ? unpaid : unpaid + pay
    }

    /// updateAnger (lines 238-257): applied every tick while unpaid.
    public func angerPerTick(angerNoPay: Int, unpaid: Int, held: Bool) -> Int {
        guard unpaid > 0 && !held else { return 0 }
        return CreatureMood.toRuntimeValue(angerNoPay)
    }
}

public struct MoodTickConfig: Sendable {
    public var lairRoomAvailable = false
    public var hatcheryAvailable = false
    public var hungerAmountNeeded = 0
    public var hungerFill = 1
    public var hasLairBed = false
    public var angerHeld = false
    public var secondsInHand: Double = 0
    public var lastMoodCheckTime: Double = 0
    public var lairRecoveryPerSecond = -550
    public static let secondsInHandBeforeAnger: Double = 20

    public init() {}
}

public enum MoodSystemRules {
    /// CreatureMoodSystem no-lair anger: per tick.
    public static func noLairAnger(angerNoLair: Int, config: MoodTickConfig) -> Int {
        guard config.lairRoomAvailable else { return 0 }
        if config.angerHeld || config.hasLairBed { return 0 }
        return CreatureMood.toRuntimeValue(angerNoLair)
    }

    /// CreatureMoodSystem no-food anger: per tick.
    public static func noFoodAnger(angerNoFood: Int, config: MoodTickConfig) -> Int {
        guard config.hatcheryAvailable,
              config.hungerAmountNeeded >= config.hungerFill else { return 0 }
        if config.angerHeld { return 0 }
        return CreatureMood.toRuntimeValue(angerNoFood)
    }

    /// In-hand anger: once per game second, only after 20 seconds.
    public static func inHandAnger(angerInHand: Int, config: MoodTickConfig,
                                   gameTime: Double) -> Int {
        guard config.secondsInHand >= secondsInHandBeforeAnger,
              gameTime - config.lastMoodCheckTime >= 1 else { return 0 }
        return CreatureMood.toRuntimeValue(angerInHand)
    }

    /// Lair recovery: once per game second, raw signed value (not /4).
    public static func lairRecovery(config: MoodTickConfig, gameTime: Double) -> Int {
        guard config.hasLairBed,
              gameTime - config.lastMoodCheckTime >= 1 else { return 0 }
        return config.lairRecoveryPerSecond
    }
}
