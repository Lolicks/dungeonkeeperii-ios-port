/// Ported from OpenKeeper game/controller/creature/CreatureState.java
/// and CreatureController.java (idle priority order and work interruption).
/// libGDX state machine replaced with pure Swift enums; no UIKit/Metal.

import Foundation

public enum CreatureState: String, Sendable {
    case idle
    case wait
    case work
    case sleeping
    case eating
    case goToSleep
    case fight
    case imprisoned
    case tortured
}

public enum JobType: String, Sendable {
    case research
    case manufacture
    case guard
    case pray
    case train
    case gamble
    case dig
    case claim
    case carryGold
    case unknown

    /// CreatureState.WORK: these jobs may be interrupted by eat/sleep/pay.
    public var interruptible: Bool {
        switch self {
        case .research, .manufacture, .guard, .pray, .train, .gamble: return true
        default: return false
        }
    }
}

/// IDLE.findStuffToDo (CreatureState.java:82-167), in exact priority order.
public enum IdlePriority: Sendable {
    case party
    case wait
    case objective
    case lair
    case sleep
    case hunger
    case pay
    case workerGoldDrop
    case winnings
    case disco
    case findWork

    public static let order: [IdlePriority] = [
        .party, .wait, .objective, .lair, .sleep, .hunger,
        .pay, .workerGoldDrop, .winnings, .disco, .findWork,
    ]
}

public struct CreatureStateMachine: Sendable {
    public private(set) var state: CreatureState
    public private(set) var job: JobType
    public private(set) var stateStartTime: Double

    public init(state: CreatureState = .idle, job: JobType = .unknown,
                stateStartTime: Double = 0) {
        self.state = state
        self.job = job
        self.stateStartTime = stateStartTime
    }

    /// First available need wins; maps to WORK or the matching state.
    public mutating func chooseIdleAction(now: Double,
                                          needs: Set<IdlePriority>) -> CreatureState {
        guard let chosen = IdlePriority.order.first(where: { needs.contains($0) }) else {
            transition(to: .idle, now: now)
            return .idle
        }
        switch chosen {
        case .sleep: transition(to: .goToSleep, now: now)
        case .hunger: transition(to: .eating, now: now)
        default: transition(to: .work, now: now)
        }
        return state
    }

    /// CreatureState.WORK.update: interruptible jobs yield to vital needs.
    public mutating func updateWork(now: Double, hasVitalNeed: Bool,
                                    taskStillValid: Bool, arrivedAtWorkSpot: Bool) -> CreatureState {
        guard state == .work else { return state }
        if hasVitalNeed && job.interruptible {
            transition(to: .idle, now: now)
        } else if !taskStillValid {
            transition(to: .idle, now: now)
        } else if arrivedAtWorkSpot {
            // Task execution itself is driven by the task system.
            stateStartTime = stateStartTime
        }
        return state
    }

    /// CreatureController: EAT_ATTEMPT_INTERVAL_TICKS = 4, one attempt per
    /// 4 / ticksPerSecond seconds.
    public static func eatAttemptDue(now: Double, lastAttempt: Double,
                                     ticksPerSecond: Int) -> Bool {
        now - lastAttempt >= 4.0 / Double(ticksPerSecond)
    }

    /// goToSleep throttles autonomous attempts to one per game second.
    public static func sleepAttemptDue(now: Double, lastAttempt: Double) -> Bool {
        now - lastAttempt >= 1.0
    }

    /// CreatureState.EATING ends when the animation time has elapsed.
    public static func eatingFinished(now: Double, stateStart: Double,
                                      animationSeconds: Double) -> Bool {
        now - stateStart > animationSeconds
    }

    public mutating func transition(to newState: CreatureState, now: Double) {
        state = newState
        stateStartTime = now
    }
}
