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

    func testMapIndexAndStoredGoldTiers() {
        var map = MapData<Int>(width: 8, height: 4, initial: 0)
        map.set(7, x: 3, y: 2)
        XCTAssertEqual(map.at(x: 3, y: 2), 7)
        XCTAssertEqual(map.index(x: 3, y: 2), 19)
        XCTAssertEqual(StoredGoldVisual(gold: 5, maxGold: 30).rawValue, 1)
        XCTAssertEqual(StoredGoldVisual(gold: 15, maxGold: 30).rawValue, 2)
        XCTAssertEqual(StoredGoldVisual(gold: 29, maxGold: 30).rawValue, 3)
    }

    func testPlayerGoldCapAndMinedCounter() {
        var wallet = PlayerGold(goldMax: 50)
        wallet.addGold(80)
        XCTAssertEqual(wallet.gold, 50)
        XCTAssertEqual(wallet.goldMined, 80)
        wallet.subGold(20)
        XCTAssertEqual(wallet.gold, 30)
        XCTAssertTrue(RoomObjectType.trainee.occupiedByCreatures)
        XCTAssertFalse(RoomObjectType.gold.occupiedByCreatures)
    }

    func testFixedStepClock() {
        var clock = FixedStepClock()
        XCTAssertNil(clock.tick(now: 10_000_000))
        if let tick = clock.tick(now: 20_000_000) {
            XCTAssertEqual(tick, 0.02, accuracy: 1e-9)
        } else {
            XCTFail("Expected a tick at the 60 FPS interval")
        }
        XCTAssertNotNil(clock.tick(now: 40_000_000))
        clock.pause()
        XCTAssertNil(clock.tick(now: 50_000_000))
        clock.resume(now: 50_000_000)
        XCTAssertNotNil(clock.tick(now: 61_000_000))
    }

    func testDamageScalingAndRearBonus() {
        XCTAssertEqual(DamageRules.scale(100, config: DamageConfig()), 100)
        var armour = DamageConfig(); armour.hasArmour = true
        XCTAssertEqual(DamageRules.scale(100, config: armour), 50)
        var frozen = DamageConfig(); frozen.frozen = true
        XCTAssertEqual(DamageRules.scale(100, config: frozen), 125)
        XCTAssertEqual(DamageRules.scale(-30, config: armour), -30)
        XCTAssertEqual(CombatRules.rearAttackBonus(damage: 100, dot: 1,
                                                   facingLength: 1, directionLength: 1), 100)
        XCTAssertGreaterThan(CombatRules.rearAttackBonus(damage: 100, dot: 0,
                                                        facingLength: 1, directionLength: 1), 116)
    }

    func testHealthAndExperienceRules() {
        let result = HealthRules.apply(health: 10, maxHealth: 100, damage: 20)
        XCTAssertEqual(result.health, 0)
        XCTAssertTrue(result.dead)
        XCTAssertTrue(HealthRules.attacksDelayed(health: 10, maxHealth: 100, isWorker: false))
        XCTAssertEqual(ExperienceRules.fightingGain(experiencePerSecond: 20, ticksPerSecond: 4), 5)
        let levelled = ExperienceRules.addExperience(100, level: 1, experienceToNextLevel: 100)
        XCTAssertEqual(levelled.level, 2)
        XCTAssertEqual(levelled.experience, 0)
        XCTAssertEqual(ExperienceRules.scaledByLevel(200, levelPercent: 150), 300)
    }

    func testPaydayAndMoodRules() {
        let rules = PayDayRules()
        let clock = rules.startClock(gameTime: 100)
        XCTAssertEqual(clock.nextPayDay, 700)
        XCTAssertEqual(rules.angerPerTick(angerNoPay: 100, unpaid: 5, held: false), 25)
        XCTAssertEqual(rules.angerPerTick(angerNoPay: 100, unpaid: 0, held: false), 0)
        var cfg = MoodTickConfig()
        cfg.lairRoomAvailable = true
        cfg.hungerAmountNeeded = 3
        cfg.hungerFill = 2
        cfg.hatcheryAvailable = true
        XCTAssertEqual(MoodSystemRules.noLairAnger(angerNoLair: 100, config: cfg), 25)
        XCTAssertEqual(MoodSystemRules.noFoodAnger(angerNoFood: 80, config: cfg), 20)
    }

    func testCreatureStateMachineAndHatchery() {
        var machine = CreatureStateMachine()
        let next = machine.chooseIdleAction(now: 10, needs: [.hunger, .sleep, .findWork])
        XCTAssertEqual(next, .goToSleep)
        XCTAssertEqual(machine.stateStartTime, 10)

        var work = CreatureStateMachine(state: .work, job: .train)
        XCTAssertTrue(work.job.interruptible)
        _ = work.updateWork(now: 20, hasVitalNeed: true,
                            taskStillValid: true, arrivedAtWorkSpot: false)
        XCTAssertEqual(work.state, .idle)

        XCTAssertTrue(CreatureStateMachine.eatAttemptDue(now: 0.3, last: 0, ticksPerSecond: 20))
        XCTAssertFalse(CreatureStateMachine.eatAttemptDue(now: 0.1, last: 0, ticksPerSecond: 20))
        XCTAssertTrue(HatcherySystem.shouldReEvaluate(motionless: 5))
        XCTAssertTrue(HatcherySystem.stateTimeExceeded(elapsed: 4, animationSeconds: 2, pecking: true))

        var hatchery = HatcheryState(timeElapsed: 12)
        XCTAssertTrue(HatcherySystem.evaluate(config: HatcheryConfig(),
                                              state: &hatchery, tiles: 5))
        XCTAssertEqual(hatchery.chickens, 1)
    }

    func testShotsAndSocialRules() {
        XCTAssertEqual(ShotRules.rangeDamage(damage: 100, radius: 10, distance: 3), 70)
        XCTAssertEqual(ShotRules.rangeDamage(damage: 100, radius: 10, distance: 10), 0)
        XCTAssertEqual(ShotRules.lightningDamage(base: 20, onWater: true), 40)
        XCTAssertEqual(ShotRules.drain(targetHealth: 50, shooterMaxHealth: 200, percent: 10), 20)
        XCTAssertEqual(ShotRules.constantHits(origin: Tile(x: 0, y: 0), radius: 1,
                                              damage: 5).count, 4)
        XCTAssertEqual(CollectPayRules.keptByCreature(collected: 100, maxGold: 30,
                                                     currentGold: 10), 20)
        XCTAssertFalse(BattleRules.canLeaveBattle(gameTime: 103.9, joinedAt: 100))
        XCTAssertTrue(BattleRules.canLeaveBattle(gameTime: 104, joinedAt: 100))
        let slap = SlapRules.apply(health: 50, maxHealth: 100, slapDamage: 5,
                                   otherAnger: 10, slapAnger: 7, sleepNeed: 20)
        XCTAssertEqual(slap.health, 45)
        XCTAssertEqual(slap.anger, 17)
        XCTAssertEqual(slap.sleepNeed, 15)
    }

    func testTaskSelectionAndTileWork() {
        let start = Tile(x: 0, y: 0)
        XCTAssertEqual(TaskSelectionRules.points(from: start, to: Tile(x: 3, y: 4), priority: 100), 107)
        let tasks = [
            TaskDescriptor(id: 1, type: .claimWall, location: start, points: 1, created: 1),
            TaskDescriptor(id: 2, type: .digTile, location: start, points: 5, created: 2),
            TaskDescriptor(id: 3, type: .fetchTrapCrate, location: start, points: 9, created: 3),
        ]
        let sorted = TaskSelectionRules.sortedForWorker(tasks)
        XCTAssertEqual(sorted.map(\.id), [3, 2, 1])
        XCTAssertEqual(TileWorkRules.perSwing(rate: 10), 10)
        XCTAssertEqual(TileWorkRules.perTick(rate: 10), 10)
        XCTAssertEqual(TileWorkRules.goldReleased(totalGold: 100, maxHealth: 200, health: 50), 75)
        XCTAssertEqual(ChickenSpawnRules.cooldown(tiles: 10, firstDelay: 0), 11)
        XCTAssertEqual(TileWorkRules.digAssignees(openSides: 3), 9)
    }
}
