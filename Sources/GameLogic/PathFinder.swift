/// A* renderer independent port of OpenKeeper's MapPathFinder +
/// IndexedAStarPathFinder graph rules.
/// Heuristic: WorldUtils.calculateDistance (Manhattan, utils/WorldUtils.java:180).
/// Diagonal corner rule: MapIndexedGraph.java:80-98, 148-174.

public struct PathResult: Sendable {
    public let tiles: [Tile]
    public let cost: Double

    public init(tiles: [Tile], cost: Double) {
        self.tiles = tiles
        self.cost = cost
    }
}

public enum PathFindingError: Error, Sendable {
    case noPath
}

private struct FrontierNode {
    let priority: Double
    let order: Int
    let tile: Tile
}

private struct MinHeap {
    private var items: [FrontierNode] = []

    var isEmpty: Bool { items.isEmpty }

    mutating func push(_ node: FrontierNode) {
        items.append(node)
        siftUp(from: items.count - 1)
    }

    mutating func pop() -> FrontierNode? {
        guard !items.isEmpty else { return nil }
        items.swapAt(0, items.count - 1)
        let result = items.removeLast()
        if !items.isEmpty { siftDown(from: 0) }
        return result
    }

    private func comesBefore(_ a: FrontierNode, _ b: FrontierNode) -> Bool {
        if a.priority != b.priority { return a.priority < b.priority }
        return a.order < b.order
    }

    private mutating func siftUp(from index: Int) {
        var child = index
        while child > 0 {
            let parent = (child - 1) / 2
            if comesBefore(items[child], items[parent]) {
                items.swapAt(child, parent)
                child = parent
            } else { break }
        }
    }

    private mutating func siftDown(from index: Int) {
        var parent = index
        while true {
            let left = parent * 2 + 1
            let right = left + 1
            var candidate = parent
            if left < items.count && comesBefore(items[left], items[candidate]) { candidate = left }
            if right < items.count && comesBefore(items[right], items[candidate]) { candidate = right }
            if candidate == parent { return }
            items.swapAt(parent, candidate)
            parent = candidate
        }
    }
}

public final class MapPathFinder {
    private let map: NavigationMap

    public init(map: NavigationMap) {
        self.map = map
    }

    public static func heuristic(from: Tile, to: Tile) -> Int {
        abs(from.x - to.x) + abs(from.y - to.y)
    }

    public func findPath(from start: Tile, to goal: Tile) throws -> PathResult {
        var frontier = MinHeap()
        var order = 0
        frontier.push(FrontierNode(
            priority: Double(Self.heuristic(from: start, to: goal)),
            order: order, tile: start))

        var bestCost: [Tile: Double] = [start: 0]
        var cameFrom: [Tile: Tile] = [:]

        var directions = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        if map.allowsDiagonal {
            directions += [(1, 1), (1, -1), (-1, 1), (-1, -1)]
        }

        while let current = frontier.pop() {
            let node = current.tile
            guard let nodeCost = bestCost[node] else { continue }
            if node == goal {
                var path = [node]
                while path[path.count - 1] != start {
                    guard let previous = cameFrom[path[path.count - 1]] else { break }
                    path.append(previous)
                }
                path.reverse()
                return PathResult(tiles: path, cost: nodeCost)
            }

            for (dx, dy) in directions {
                let neighbour = Tile(x: node.x + dx, y: node.y + dy)
                guard let stepCost = map.cost(at: neighbour) else { continue }
                if dx != 0 && dy != 0 {
                    // No squeezing through corners: both orthogonal tiles must
                    // be passable (MapIndexedGraph.java:80-98).
                    if map.cost(at: Tile(x: node.x + dx, y: node.y)) == nil { continue }
                    if map.cost(at: Tile(x: node.x, y: node.y + dy)) == nil { continue }
                }
                let tentative = nodeCost + stepCost
                if tentative < (bestCost[neighbour] ?? Double.infinity) {
                    bestCost[neighbour] = tentative
                    cameFrom[neighbour] = node
                    order += 1
                    frontier.push(FrontierNode(
                        priority: tentative + Double(Self.heuristic(from: neighbour, to: goal)),
                        order: order, tile: neighbour))
                }
            }
        }
        throw PathFindingError.noPath
    }
}
