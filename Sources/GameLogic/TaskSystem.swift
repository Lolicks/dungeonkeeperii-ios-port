/// Ported from OpenKeeper:
/// game/task/TaskWorkerPriorityComparator.java:27-60,
/// game/task/TaskManager.java:1504-1515 (points = Manhattan + priority),
/// game/task/AbstractTask.java:96-150 (defaults),
/// game/controller/TileWork.java:49-66, 80-85, 115-140, 170-172,
/// game/task/worker/DigTileTask.java:80-89,
/// game/logic/ChickenSpawnSystem.java:60, 188-211.

import Foundation

public enum TaskType: Int, Sendable {
    case digTile = 0
    case claimTile = 1
    case claimWall = 2
    case claimRoom = 3
    case carryGoldToTreasury = 4
    case goToEat = 5
    case goToSleep = 6
    case fetchTrapCrate = 7
    case deliverTrapCrate = 8
    case train = 9
    case research = 10
}

public struct TaskDescriptor: Sendable {
    public let id: Int
    public let type: TaskType
    public let location: Tile
    public var priority: Int
    public let created: Int
    public var maxAssignees: Int
    public var assignees: Int
    public var points: Int

    public init(id: Int, type: TaskType, location: Tile, priority: Int = 100,
                created: Int = 0, maxAssignees: Int = 1,
                assignees: Int = 0, points: Int = 0) {
        self.id = id
        self.type = type
        self.location = location
        self.priority = priority
        self.created = created
        self.maxAssignees = maxAssignees
        self.assignees = assignees
        self.points = points
    }

    public var isFull: Bool { assignees >= maxAssignees }

    /// AbstractTask.isWorkStepDue: a work step happens every 1.0 second.
    public static func isWorkStepDue(now: Double, lastStep: Double) -> Bool {
        now - lastStep >= 1.0
    }
}

public enum TaskSelectionRules {
    /// TaskManager.processUnemployedWorkers (lines 1504-1509):
    /// score = Manhattan distance + task priority.
    public static func points(from: Tile, to: Tile, priority: Int) -> Int {
        MapPathFinder.heuristic(from: from, to: to) + priority
    }

    private static func isArmingTrap(_ task: TaskDescriptor) -> Bool {
        task.type == .fetchTrapCrate || task.type == .deliverTrapCrate
    }

    /// TaskWorkerPriorityComparator (lines 27-60):
    /// arm trap first, claim wall last, then points, then creation time.
    public static func sortedForWorker(_ tasks: [TaskDescriptor]) -> [TaskDescriptor] {
        tasks.sorted { a, b in
            let aArm = isArmingTrap(a)
            let bArm = isArmingTrap(b)
            if aArm != bArm { return aArm && !bArm }
            let aWall = a.type == .claimWall
            let bWall = b.type == .claimWall
            if aWall != bWall { return !aWall && bWall }
            if a.points != b.points { return a.points < b.points }
            return a.created < b.created
        }
    }
}

public enum TileWorkRules {
    /// TileWork.perSwing (lines 64-66): (abs(rate) * efficiency + 99) / 100.
    public static func perSwing(rate: Int, efficiency: Int = 100) -> Int {
        (abs(rate) * efficiency + 99) / 100
    }

    /// TileWork.perTick (lines 170-172): abs(rate) * (efficiency * 4096 / 100) >> 12.
    /// `rate` is already the per-tick rate (MapController divides by ticksPerSecond).
    public static func perTick(rate: Int, efficiency: Int = 100) -> Int {
        (abs(rate) * (efficiency * 4096 / 100)) >> 12
    }

    /// TileWork.perApplication (lines 49-51): round(abs(rate) * efficiency / 100).
    public static func perApplication(rate: Int, efficiency: Int = 100) -> Int {
        Int((Double(abs(rate)) * Double(efficiency) / 100.0).rounded())
    }

    /// TileWork.mine (lines 80-85).
    public static func goldReleased(totalGold: Int, maxHealth: Int, health: Int) -> Int {
        guard maxHealth > 0 else { return 0 }
        return Int(Int64(totalGold) * Int64(maxHealth - health) / Int64(maxHealth))
    }

    /// TileWork.canDamageTile (lines 133-140).
    public static func canDamage(terrain: Terrain, isOwned: Bool,
                                 ownerIsPlayer: Bool) -> Bool {
        if terrain == .solid { return true }
        // OWNABLE tiles can be damaged when the owner is not this player.
        return isOwned && !ownerIsPlayer
    }

    /// DigTileTask.getMaxAllowedNumberOfAsignees (lines 80-89): 3 per open side.
    public static func digAssignees(openSides: Int) -> Int {
        3 * openSides
    }
}

public enum ChickenSpawnRules {
    /// ChickenSpawnSystem.getCooldown (lines 188-211).
    public static func cooldown(tiles: Int, firstDelay: Double) -> Double {
        if tiles < 1 || tiles >= 20 { return 3 }
        if tiles <= 9 {
            let values = [15, 13, 12]
            return Double(values[(tiles - 1) / 3])
        }
        return Double(max(4, 21 - tiles))
    }
}
