/// Port of OpenKeeper's utils/GameLoop.java (Paul Speed's loop fork).
/// Key behaviour: fixed 60 FPS update rate (16,666,667 ns), dropped makeup
/// frames rather than catching up, and lastTime reset on resume.

public struct FixedStepClock: Sendable {
    public static let interval60FPS: UInt64 = 16_666_667

    public let updateRate: UInt64
    public private(set) var frameRate: Int64 = 0
    public private(set) var lastTime: UInt64
    public private(set) var paused: Bool = false

    public init(updateRate: UInt64 = FixedStepClock.interval60FPS, startTime: UInt64 = 0) {
        self.updateRate = updateRate
        self.lastTime = startTime
    }

    /// Returns the delta seconds for exactly one logic tick, or nil when
    /// the accumulated time has not reached one update interval yet.
    public mutating func tick(now: UInt64) -> Double? {
        guard !paused else { return nil }
        let delta = now - lastTime
        if Int64(delta) + frameRate >= Int64(updateRate) {
            lastTime = now
            frameRate += Int64(delta) - Int64(updateRate)
            return Double(delta) / 1_000_000_000.0
        }
        return nil
    }

    /// GameLoop.java:160 — Thread.sleep((updateRate - frameRate) / 1e6).
    public var sleepMilliseconds: Int64 {
        max(0, (Int64(updateRate) - frameRate) / 1_000_000)
    }

    public mutating func pause() { paused = true }

    public mutating func resume(now: UInt64) {
        paused = false
        // GameLoop.java:123 — lastTime = System.nanoTime() on resume.
        lastTime = now
    }
}
