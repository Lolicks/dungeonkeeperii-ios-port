/// Ported from OpenKeeper's pure navigation/room data model.
/// Sources: game/navigation/pathfinding/INavigable.java,
/// game/component/MapTile.java, tools/convert/map/Room.java.
///
/// No UIKit, Metal, jMonkeyEngine, AWT or libGDX dependencies.

public struct Tile: Hashable, Sendable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

public enum Terrain: UInt8, Sendable {
    case solid
    case ground
    case water
    case lava
    case door
}

/// Mirrors the traverse costs from INavigable.java:
/// WATER_COST = 1.4, DEFAULT_COST = 1.0, DOOR_COST = 8.0.
public enum NavigationCost {
    public static let water: Double = 1.4
    public static let `default`: Double = 1.0
    public static let door: Double = 8.0
}

public protocol NavigationMap: AnyObject {
    var width: Int { get }
    var height: Int { get }
    var allowsDiagonal: Bool { get }
    var canWalkOnWater: Bool { get }
    var canWalkOnLava: Bool { get }
    var canBreakDoors: Bool { get }
    func terrain(at tile: Tile) -> Terrain
}

public extension NavigationMap {
    var allowsDiagonal: Bool { false }
    var canWalkOnWater: Bool { false }
    var canWalkOnLava: Bool { false }
    var canBreakDoors: Bool { false }

    func contains(_ tile: Tile) -> Bool {
        tile.x >= 0 && tile.y >= 0 && tile.x < width && tile.y < height
    }

    /// nil means impassable (MapIndexedGraph.getCost returns null for SOLID).
    func cost(at tile: Tile) -> Double? {
        guard contains(tile) else { return nil }
        switch terrain(at: tile) {
        case .solid:
            return nil
        case .ground:
            return NavigationCost.default
        case .water:
            return canWalkOnWater ? NavigationCost.water : nil
        case .lava:
            return canWalkOnLava ? NavigationCost.default : nil
        case .door:
            return canBreakDoors ? NavigationCost.door : nil
        }
    }
}

/// Bit flags from tools/convert/map/Room.java:40-66.
public struct RoomFlag: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let placeableOnWater = RoomFlag(rawValue: 0x0001)
    public static let placeableOnLava = RoomFlag(rawValue: 0x0002)
    public static let placeableOnLand = RoomFlag(rawValue: 0x0004)
    public static let hasWalls = RoomFlag(rawValue: 0x0008)
    public static let centre = RoomFlag(rawValue: 0x0010)
    public static let specialTiles = RoomFlag(rawValue: 0x0020)
    public static let normalTiles = RoomFlag(rawValue: 0x0040)
    public static let buildable = RoomFlag(rawValue: 0x0080)
    public static let specialWalls = RoomFlag(rawValue: 0x0100)
    public static let hasFlame = RoomFlag(rawValue: 0x1000)
    public static let isGood = RoomFlag(rawValue: 0x2000)
}

/// Thing.Room.RoomType from tools/convert/map/Thing.java:366-386.
public enum SpecialRoomType: Int, Sendable {
    case portal = 12
    case dungeonHeart = 14
    case heroGate2x2 = 33
    case heroGateFrontEnd = 34
    case heroGate3x1 = 37
    case heroPortal = 40
}

/// TileConstruction from tools/convert/map/Room.java:68-93.
public enum TileConstruction: Int, Sendable {
    case complete = 0
    case quad = 1
    case threeByThree = 2
    case threeByThreeRotated = 3
    case normal = 4
    case centerPool = 5
    case doubleQuad = 6
    case fiveByFiveRotated = 7
    case heroGate = 8
}
