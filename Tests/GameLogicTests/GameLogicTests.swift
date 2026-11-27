import XCTest
@testable import GameLogic

final class GameLogicTests: XCTestCase {
    private final class Grid: NavigationMap {
        let width: Int
        let height: Int
        var allowsDiagonal: Bool
        var canWalkOnWater = false
        var canWalkOnLava = false
        var canBreakDoors = false
        private let solid: Set<Tile>
        private let water: Set<Tile>
        private let doors: Set<Tile>

        init(width: Int, height: Int, solid: Set<Tile> = [], water: Set<Tile> = [],
             doors: Set<Tile> = [], diagonal: Bool = false) {
            self.width = width
            self.height = height
            self.solid = solid
            self.water = water
            self.doors = doors
            self.allowsDiagonal = diagonal
        }

        func terrain(at tile: Tile) -> Terrain {
            if solid.contains(tile) { return .solid }
            if water.contains(tile) { return .water }
            if doors.contains(tile) { return .door }
            return .ground
        }
    }

    func testPlainAStar() throws {
        let result = try MapPathFinder(map: Grid(width: 5, height: 5))
            .findPath(from: Tile(x: 0, y: 0), to: Tile(x: 4, y: 4))
        XCTAssertEqual(result.tiles.count, 9)
        XCTAssertEqual(result.cost, 8.0, accuracy: 1e-9)
        XCTAssertEqual(MapPathFinder.heuristic(from: result.tiles[0], to: result.tiles[1]), 1)
    }

    func testDoorIsAvoidedWhenDetourIsCheaper() throws {
        let grid = Grid(width: 3, height: 3, doors: [Tile(x: 1, y: 1)])
        let result = try MapPathFinder(map: grid)
            .findPath(from: Tile(x: 0, y: 1), to: Tile(x: 2, y: 1))
        XCTAssertFalse(result.tiles.contains(Tile(x: 1, y: 1)))
        XCTAssertEqual(result.cost, 4.0, accuracy: 1e-9)
    }

    func testWaterCost() throws {
        let grid = Grid(width: 3, height: 1, water: [Tile(x: 1, y: 0)])
        let result = try MapPathFinder(map: grid)
            .findPath(from: Tile(x: 0, y: 0), to: Tile(x: 2, y: 0))
        XCTAssertEqual(result.cost, 2.4, accuracy: 1e-9)
    }

    func testNoSqueezingThroughCorners() {
        let grid = Grid(width: 2, height: 2,
                        solid: [Tile(x: 1, y: 0), Tile(x: 0, y: 1)], diagonal: true)
        XCTAssertThrowsError(try MapPathFinder(map: grid)
            .findPath(from: Tile(x: 0, y: 0), to: Tile(x: 1, y: 1)))
    }

    func testSleepNeedConsumedPerTick() {
        let result = CreatureSleepLogic.update(
            sleepNeed: 20, lastSleepTime: 0, gameTime: 10,
            timeAwake: 5, timeSleep: 3, ticksPerSecond: 20, isSleeping: true)
        XCTAssertEqual(result.sleepNeed, 19)
        XCTAssertEqual(result.lastSleepTime, 10)
    }

    func testSleepDebtRelatch() {
        let result = CreatureSleepLogic.update(
            sleepNeed: 0, lastSleepTime: 0, gameTime: 6,
            timeAwake: 5, timeSleep: 3, ticksPerSecond: 20, isSleeping: false)
        XCTAssertEqual(result.sleepNeed, 60)
        XCTAssertEqual(result.lastSleepTime, 6)
    }

    func testHungerMissedMeals() {
        XCTAssertEqual(CreatureHungerLogic.missedMeals(now: 13, lastEatTime: 1, hungerRate: 4), 3)
        XCTAssertEqual(CreatureHungerLogic.missedMeals(now: 3, lastEatTime: 1, hungerRate: 4), 0)
    }

    func testMoodClampAndThresholds() {
        var mood = CreatureMood()
        mood.add(CreatureMood.maxAnger + 100, .general)
        XCTAssertEqual(mood.values[MoodReason.general.rawValue], CreatureMood.maxAnger)
        XCTAssertEqual(mood.state(unhappyThreshold: CreatureMood.toRuntimeThreshold(50)), 2)
        XCTAssertEqual(CreatureMood.toRuntimeValue(100), 25)
        XCTAssertEqual(CreatureMood.toRuntimeThreshold(50), 16383)
    }

    func testEconomyCapacityAndEvenSubtraction() {
        var treasuries = [Treasury(gold: 5, capacity: 10), Treasury(gold: 0, capacity: 10)]
        XCTAssertEqual(EconomyLogic.addGold(10, to: &treasuries), 5)
        XCTAssertEqual(treasuries.map(\.gold), [10, 5])
        XCTAssertEqual(EconomyLogic.subGold(5, from: &treasuries), 0)
        XCTAssertEqual(treasuries.map(\.gold), [7, 3])
    }
}
