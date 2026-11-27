"""Executable specification of the OpenKeeper logic ported to Swift.

Mirrors these real sources:
  OpenKeeper/src/main/java/toniarts/openkeeper/game/navigation/pathfinding/
      MapIndexedGraph.java, MapDistance.java, INavigable.java
  OpenKeeper/src/main/java/toniarts/openkeeper/utils/WorldUtils.java:180
  OpenKeeper/src/main/java/toniarts/openkeeper/game/logic/CreatureSleepSystem.java:117
  OpenKeeper/src/main/java/toniarts/openkeeper/game/controller/creature/CreatureController.java:3074
  OpenKeeper/src/main/java/toniarts/openkeeper/game/component/CreatureMood.java
  OpenKeeper/src/main/java/toniarts/openkeeper/game/controller/GameWorldController.java:292

Run: python tools/logic_oracle.py
"""
from __future__ import annotations

import heapq
import math
from dataclasses import dataclass

WATER_COST = 1.4
DEFAULT_COST = 1.0
DOOR_COST = 8.0
MAX_ANGER = 65533


@dataclass(frozen=True)
class Tile:
    x: int
    y: int

    def __hash__(self):
        return self.x * 1000 + self.y


def manhattan(a: Tile, b: Tile) -> int:
    """WorldUtils.calculateDistance: |dx| + |dy|."""
    return abs(a.x - b.x) + abs(a.y - b.y)


class Grid:
    """Minimal IMapController + INavigable stand-in."""

    def __init__(self, width: int, height: int, solid: set[Tile] | None = None,
                 water: set[Tile] | None = None, doors: set[Tile] | None = None,
                 diagonal: bool = False):
        self.width, self.height = width, height
        self.solid = solid or set()
        self.water = water or set()
        self.doors = doors or set()
        self.diagonal = diagonal

    def inside(self, t: Tile) -> bool:
        return 0 <= t.x < self.width and 0 <= t.y < self.height

    def cost(self, t: Tile) -> float | None:
        """MapIndexedGraph.getCost / INavigable defaults."""
        if t in self.solid or not self.inside(t):
            return None
        if t in self.doors:
            return DOOR_COST
        if t in self.water:
            return WATER_COST
        return DEFAULT_COST


def find_path(grid: Grid, start: Tile, goal: Tile) -> tuple[list[Tile], float] | None:
    """A* with Manhattan heuristic, matching MapPathFinder + IndexedAStarPathFinder."""
    frontier: list[tuple[float, int, Tile]] = []
    heapq.heappush(frontier, (manhattan(start, goal), 0, start))
    came_from: dict[Tile, Tile] = {}
    g: dict[Tile, float] = {start: 0.0}
    counter = 0
    dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    if grid.diagonal:
        dirs += [(1, 1), (1, -1), (-1, 1), (-1, -1)]
    while frontier:
        _, _, current = heapq.heappop(frontier)
        if current == goal:
            path = [current]
            while path[-1] != start:
                path.append(came_from[path[-1]])
            path.reverse()
            return path, g[current]
        for dx, dy in dirs:
            neighbour = Tile(current.x + dx, current.y + dy)
            step_cost = grid.cost(neighbour)
            if step_cost is None:
                continue
            if dx != 0 and dy != 0:
                # MapIndexedGraph: both orthogonal neighbours must be passable.
                if grid.cost(Tile(current.x + dx, current.y)) is None:
                    continue
                if grid.cost(Tile(current.x, current.y + dy)) is None:
                    continue
            tentative = g[current] + step_cost
            if tentative < g.get(neighbour, math.inf):
                g[neighbour] = tentative
                came_from[neighbour] = current
                counter += 1
                heapq.heappush(frontier, (tentative + manhattan(neighbour, goal), counter, neighbour))
    return None


def update_sleep(sleep_need: int, last_sleep_time: float, game_time: float,
                 time_awake: float, time_sleep: float, tps: int,
                 sleeping: bool) -> tuple[int, float]:
    """CreatureSleepSystem.updateSleep (lines 117-142)."""
    if sleeping:
        return max(0, sleep_need - 1), game_time
    if game_time - last_sleep_time >= time_awake:
        return time_sleep * tps, game_time
    return sleep_need, last_sleep_time


def missed_meals(now: float, last_eat_time: float, hunger_rate: float) -> int:
    """CreatureController.isHungry (lines 3081-3082)."""
    if hunger_rate <= 0:
        return 0
    return int((now - last_eat_time) / hunger_rate)


def add_anger(value: int, reason: int, moods: list[int]) -> None:
    """CreatureMood.add: clamp [0, MAX_ANGER]."""
    moods[reason] = max(0, min(MAX_ANGER, moods[reason] + value))


def mood_state(moods: list[int], threshold: int) -> int:
    """CreatureMood.getState: 0 normal, 1 unhappy, 2 angry."""
    m = max(moods)
    if threshold <= m <= 32767:
        return 1
    if m > 32767:
        return 2
    return 0


def to_runtime_value(authored: int) -> int:
    """CreatureMood.toRuntimeValue: authored / 4."""
    return authored // 4


def to_runtime_threshold(percent: int) -> int:
    """CreatureMood.toRuntimeThreshold."""
    return percent * 32767 // 100


def add_gold_treasuries(treasuries: list[tuple[int, int]], amount: int) -> list[tuple[int, int]]:
    """GameWorldController.addGold: distribute then credit, respecting caps."""
    result = [list(t) for t in treasuries]
    left = amount
    for row in result:
        room = min(left, row[1] - row[0])
        row[0] += room
        left -= room
    return [tuple(r) for r in result]


def sub_gold_treasuries(treasuries: list[tuple[int, int]], amount: int) -> list[tuple[int, int]]:
    """GameWorldController.substractGold: ceil(amount / n) per treasury."""
    result = [list(t) for t in treasuries]
    if not result:
        return []
    per = math.ceil(amount / len(result))
    left = amount
    for row in result:
        take = min(per, row[0], left)
        row[0] -= take
        left -= take
    return [tuple(r) for r in result]


def map_index(x: int, y: int, width: int) -> int:
    """MapData.java:49-62."""
    return y * width + x


def stored_gold_visual(gold: int, max_gold: int) -> int:
    """StoredGoldVisuals.java:39-51."""
    if max_gold <= 0:
        return 3
    if gold < max_gold // 3:
        return 1
    if gold < 2 * max_gold // 3:
        return 2
    return 3


@dataclass
class PlayerGold:
    gold: int = 0
    gold_max: int = 100
    gold_mined: int = 0

    def add_gold(self, value: int) -> None:
        """PlayerGoldControl.addGold: gold=min(gold+value,max), goldMined+=value."""
        if value <= 0:
            return
        self.gold = min(self.gold + value, self.gold_max)
        self.gold_mined += value

    def sub_gold(self, value: int) -> None:
        if value <= 0:
            return
        self.gold = max(0, self.gold - value)


@dataclass
class FixedStepClock:
    """GameLoop.java: fixed update rate, dropped makeup frames, pause resume."""
    update_rate: int = 16_666_667
    frame_rate: int = 0
    last_time: int = 0
    paused: bool = False

    def tick(self, now: int) -> float | None:
        if self.paused:
            return None
        delta = now - self.last_time
        if delta + self.frame_rate >= self.update_rate:
            self.last_time = now
            self.frame_rate += delta - self.update_rate
            return delta / 1_000_000_000
        return None

    @property
    def sleep_ms(self) -> int:
        return max(0, (self.update_rate - self.frame_rate) // 1_000_000)

    def resume(self, now: int) -> None:
        self.paused = False
        self.last_time = now


def scale_damage(amount: int, possessed=False, armour=False, frozen=False,
                 stunned=False) -> int:
    """EntityController.scaleDamage (lines 255-279)."""
    if amount <= 0:
        return amount
    multiplier = 128
    if possessed or armour:
        multiplier -= 64
    if frozen:
        multiplier += 32
    if not frozen and stunned:
        multiplier += 128
    return min(2**31 - 1, amount * multiplier // 128)


def rear_attack_bonus(damage: int, dot: float, facing_len: float,
                      direction_len: float) -> int:
    """CombatRules.addRearAttackBonus (lines 60-79)."""
    denominator = facing_len * direction_len
    if denominator <= 0:
        return damage
    raw = max(-1.0, min(1.0, dot / denominator))
    import math as _m
    steps = min(1023, int(_m.acos(raw) / _m.pi * 1024))
    percent = steps // 20
    if percent < 16:
        return damage
    return damage + damage * percent // 100


def experience_add(experience: int, level: int, to_next: int) -> tuple[int, int]:
    """CreatureExperienceSystem.addExperience (lines 219-228)."""
    if experience >= to_next:
        return min(10, level + 1), 0
    return level, experience


def payday_start(game_time: int, before_first: int = 600) -> tuple[int, int]:
    return game_time + before_first, game_time


def mood_anger(anger_authored: int, held: bool = False) -> int:
    """CreatureMood.toRuntimeValue: authored / 4, applied each tick."""
    return 0 if held else anger_authored // 4


def task_points(start: Tile, goal: Tile, priority: int) -> int:
    """TaskManager: Manhattan distance + task priority."""
    return manhattan(start, goal) + priority


def tile_work_per_swing(rate: int, efficiency: int = 100) -> int:
    return (abs(rate) * efficiency + 99) // 100


def tile_work_per_tick(rate: int, efficiency: int = 100) -> int:
    return (abs(rate) * (efficiency * 4096 // 100)) >> 12


def gold_released(total_gold: int, max_health: int, health: int) -> int:
    if max_health <= 0:
        return 0
    return total_gold * (max_health - health) // max_health


def chicken_cooldown(tiles: int) -> int:
    values = [15, 13, 12]
    if tiles < 1 or tiles >= 20:
        return 3
    if tiles <= 9:
        return values[(tiles - 1) // 3]
    return max(4, 21 - tiles)


def shot_range_damage(damage: int, radius: int, distance: int) -> int:
    """ShotsController: damage * (radius - distance) / radius."""
    if radius <= 0 or distance >= radius:
        return 0
    return damage * (radius - distance) // radius


def lightning_damage(base: int, on_water: bool) -> int:
    """LightningShotProcessor: x2 on water."""
    return base * 2 if on_water else base


def collect_pay(collected: int, max_gold: int, current_gold: int) -> int:
    """CollectPay: creature keeps half, capped by carry capacity."""
    return min(collected // 2, max(0, max_gold - current_gold))


def battle_can_leave(game_time: float, joined_at: float) -> bool:
    return game_time - joined_at >= 4.0


IDLE_PRIORITY = ["party", "wait", "objective", "lair", "sleep", "hunger",
                 "pay", "workerGoldDrop", "winnings", "disco", "findWork"]

INTERRUPTIBLE_JOBS = {"research", "manufacture", "guard", "pray", "train", "gamble"}


def choose_idle(needs: set[str]) -> str | None:
    return next((p for p in IDLE_PRIORITY if p in needs), None)


def eat_attempt_due(now: float, last: float, tps: int) -> bool:
    return now - last >= 4.0 / tps


def hatchery_spawn(time_elapsed: float, last_spawn: float, tiles: int,
                   chickens: int, capacity: int) -> bool:
    cooldown = chicken_cooldown(tiles)
    if time_elapsed - last_spawn >= cooldown and chickens < capacity:
        return True
    return chickens < 4 and time_elapsed >= 10


def run_checks() -> None:
    # 1. Plain 4-neighbour A* on an empty grid: 9 tiles, cost 8.
    result = find_path(Grid(5, 5), Tile(0, 0), Tile(4, 4))
    assert result is not None
    path, cost = result
    assert len(path) == 9 and abs(cost - 8.0) < 1e-9, result
    assert manhattan(path[0], path[1]) == 1

    # 2. Door cost 8 makes a 4-step detour cheaper than the 8-cost door.
    result = find_path(Grid(3, 3, doors={Tile(1, 1)}), Tile(0, 1), Tile(2, 1))
    assert result is not None
    path, cost = result
    assert Tile(1, 1) not in path and abs(cost - 4.0) < 1e-9, result

    # 3. Water cost 1.4 is used when no alternative exists (total 2.4).
    result = find_path(Grid(3, 1, water={Tile(1, 0)}), Tile(0, 0), Tile(2, 0))
    assert result is not None and abs(result[1] - 2.4) < 1e-9, result

    # 4. Diagonal movement cannot squeeze between two blocked orthogonal tiles.
    grid = Grid(2, 2, solid={Tile(1, 0), Tile(0, 1)}, diagonal=True)
    path = find_path(grid, Tile(0, 0), Tile(1, 1))
    assert path is None, path

    # 5. Sleep debt is consumed once per tick while sleeping.
    need, last = update_sleep(20, 0.0, 10.0, 5.0, 3.0, 20, sleeping=True)
    assert need == 19 and last == 10.0

    # 6. Awake long enough re-latches the clock and sets debt = timeSleep * tps.
    need, last = update_sleep(0, 0.0, 6.0, 5.0, 3.0, 20, sleeping=False)
    assert need == 60 and last == 6.0

    # 7. Hunger debt uses integer truncated missed meals.
    assert missed_meals(13.0, 1.0, 4.0) == 3
    assert missed_meals(3.0, 1.0, 4.0) == 0

    # 8. Mood clamps and threshold conversion.
    moods = [0] * 6
    add_anger(MAX_ANGER + 100, 0, moods)
    assert moods[0] == MAX_ANGER
    assert mood_state(moods, to_runtime_threshold(50)) == 2
    assert to_runtime_value(100) == 25
    assert to_runtime_threshold(50) == 16383

    # 9. Gold distribution respects capacity; subtraction uses ceil per treasury.
    assert add_gold_treasuries([(5, 10), (0, 10)], 10) == [(10, 10), (5, 10)]
    assert sub_gold_treasuries([(10, 20), (3, 20)], 5) == [(7, 20), (1, 20)]
    # 10. MapData flat index and StoredGoldVisuals tiers.
    assert map_index(3, 2, 8) == 19
    assert stored_gold_visual(5, 30) == 1
    assert stored_gold_visual(15, 30) == 2
    assert stored_gold_visual(29, 30) == 3

    # 11. PlayerGoldControl cap and lifetime mined counter.
    wallet = PlayerGold(gold_max=50)
    wallet.add_gold(80)
    assert wallet.gold == 50 and wallet.gold_mined == 80
    wallet.sub_gold(20)
    assert wallet.gold == 30
    # 12. FixedStepClock: no tick before one interval, one tick (not catch-up) after,
    # pause suppresses ticks, resume resets lastTime.
    clock = FixedStepClock()
    assert clock.tick(10_000_000) is None
    tick = clock.tick(20_000_000)
    assert tick is not None and abs(tick - 0.02) < 1e-9
    assert clock.tick(40_000_000) is not None
    clock.paused = True
    assert clock.tick(50_000_000) is None
    clock.resume(50_000_000)
    assert clock.tick(61_000_000) is not None
    assert clock.sleep_ms >= 0
    # 13. Damage scaling in 128ths: armour halves, freeze adds 32/128,
    # stun doubles unless frozen, healing is never scaled.
    assert scale_damage(100) == 100
    assert scale_damage(100, armour=True) == 50
    assert scale_damage(100, frozen=True) == 125
    assert scale_damage(100, stunned=True) == 200
    assert scale_damage(-30, armour=True) == -30

    # 14. Rear attack bonus only applies from ~16% upward.
    assert rear_attack_bonus(100, 1.0, 1, 1) == 100
    assert rear_attack_bonus(100, 0.0, 1, 1) > 116

    # 15. Experience level-up resets accumulated experience and caps at 10.
    assert experience_add(100, 1, 100) == (2, 0)
    assert experience_add(99, 1, 100) == (1, 99)
    assert experience_add(500, 10, 100) == (10, 0)

    # 16. Payday clock and anger per tick.
    assert payday_start(100) == (700, 100)
    assert mood_anger(100) == 25
    assert mood_anger(100, held=True) == 0

    # 17. Worker task score = Manhattan distance + priority.
    assert task_points(Tile(0, 0), Tile(3, 4), 100) == 107

    # 18. Tile work formulas and seam gold release.
    assert tile_work_per_swing(10) == 10
    assert tile_work_per_tick(10) == 10
    assert gold_released(100, 200, 50) == 75

    # 19. Chicken hatchery cooldown tiers.
    assert chicken_cooldown(0) == 3
    assert chicken_cooldown(2) == 15
    assert chicken_cooldown(10) == 11
    assert chicken_cooldown(15) == 6
    assert chicken_cooldown(20) == 3
    # 20. Shots: RANGE_FROM_ORIGIN diminishing damage, lightning water x2.
    assert shot_range_damage(100, 10, 3) == 70
    assert shot_range_damage(100, 10, 10) == 0
    assert lightning_damage(20, False) == 20
    assert lightning_damage(20, True) == 40

    # 21. Pay collection keeps half, capped by carry capacity.
    assert collect_pay(100, 30, 10) == 20
    assert collect_pay(10, 30, 28) == 2

    # 22. Battle minimum stay is 4 seconds.
    assert not battle_can_leave(103.9, 100)
    assert battle_can_leave(104.0, 100)
    # 23. Idle need priority: sleep beats hunger, hunger beats findWork.
    assert choose_idle({"hunger", "findWork", "sleep"}) == "sleep"
    assert choose_idle({"findWork", "pay"}) == "pay"

    # 24. Eat attempts are throttled to 4 ticks; sleep to one per second.
    assert eat_attempt_due(0.3, 0, 20)
    assert not eat_attempt_due(0.1, 0, 20)
    assert "train" in INTERRUPTIBLE_JOBS and "dig" not in INTERRUPTIBLE_JOBS

    # 25. Hatchery spawn cooldown and free-range cap.
    assert hatchery_spawn(12, 0, 5, 0, 8)
    assert not hatchery_spawn(4, 0, 5, 0, 8)
    print("ALL LOGIC ORACLE CHECKS PASSED (25 groups)")


if __name__ == "__main__":
    run_checks()
