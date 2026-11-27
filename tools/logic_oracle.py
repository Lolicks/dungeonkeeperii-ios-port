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
    print("ALL LOGIC ORACLE CHECKS PASSED (9 groups)")


if __name__ == "__main__":
    run_checks()
