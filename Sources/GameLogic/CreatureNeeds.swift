/// Ported formulas from OpenKeeper creature need components and systems:
/// CreatureMood.java, CreatureSleepSystem.java:117-142,
/// CreatureController.java:3074-3106 (hunger), PayDaySystem.java.

public enum MoodReason: Int, Sendable {
    case general = 0
    case noFood = 1
    case noLair = 2
    case noWork = 3
    case noPay = 4
    case other = 5
}

public struct CreatureMood: Sendable {
    public static let maxAnger = 65533

    public var values: [Int]

    public init() {
        values = [Int](repeating: 0, count: 6)
    }

    public mutating func add(_ amount: Int, _ reason: MoodReason) {
        let index = reason.rawValue
        values[index] = max(0, min(Self.maxAnger, values[index] + amount))
    }

    public mutating func clear(_ reason: MoodReason) {
        values[reason.rawValue] = 0
    }

    public var dominantReason: MoodReason {
        var best = 0
        for i in 1..<values.count where values[i] > values[best] { best = i }
        return MoodReason(rawValue: best) ?? .general
    }

    public var average: Int { values.reduce(0, +) / values.count }

    /// 0 = normal, 1 = unhappy, 2 = angry (CreatureMood.getState).
    public func state(unhappyThreshold: Int) -> Int {
        let maximum = values.max() ?? 0
        if maximum >= unhappyThreshold && maximum <= 32767 { return 1 }
        if maximum > 32767 { return 2 }
        return 0
    }

    public static func toRuntimeValue(_ authored: Int) -> Int { authored / 4 }
    public static func toRuntimeThreshold(_ percent: Int) -> Int { percent * 32767 / 100 }
}

public struct SleepUpdate: Sendable {
    public let sleepNeed: Int
    public let lastSleepTime: Double

    public init(sleepNeed: Int, lastSleepTime: Double) {
        self.sleepNeed = sleepNeed
        self.lastSleepTime = lastSleepTime
    }
}

public enum CreatureSleepLogic {
    /// CreatureSleepSystem.updateSleep (lines 117-142).
    public static func update(sleepNeed: Int, lastSleepTime: Double, gameTime: Double,
                              timeAwake: Double, timeSleep: Double, ticksPerSecond: Int,
                              isSleeping: Bool) -> SleepUpdate {
        if isSleeping {
            return SleepUpdate(sleepNeed: max(0, sleepNeed - 1), lastSleepTime: gameTime)
        }
        if gameTime - lastSleepTime >= timeAwake {
            return SleepUpdate(sleepNeed: Int(timeSleep) * ticksPerSecond,
                               lastSleepTime: gameTime)
        }
        return SleepUpdate(sleepNeed: sleepNeed, lastSleepTime: lastSleepTime)
    }
}

public enum CreatureHungerLogic {
    /// CreatureController.isHungry (lines 3081-3082).
    public static func missedMeals(now: Double, lastEatTime: Double, hungerRate: Double) -> Int {
        guard hungerRate > 0 else { return 0 }
        return Int((now - lastEatTime) / hungerRate)
    }
}
