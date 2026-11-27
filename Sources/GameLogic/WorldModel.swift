/// Platform-independent world data model ported from OpenKeeper:
/// game/map/MapData.java (index = y * width + x),
/// game/component/MapTile.java, RoomComponent.java,
/// game/controller/room/AbstractRoomController.java (ObjectType),
/// game/controller/StoredGoldVisuals.java (gold display tiers),
/// game/controller/player/PlayerGoldControl.java (gold cap + goldMined).

public enum RoomObjectType: Int, Sendable {
    case gold = 0
    case lair = 1
    case spellBook = 2
    case special = 3
    case researcher = 4
    case prisoner = 5
    case torturee = 6
    case food = 7
    case trainee = 8
    case manufacturer = 9
    case crate = 10
    case worshipper = 11
    case guard = 12
    case gambler = 13
    case corpse = 14

    /// AbstractRoomController: occupiedByCreatures is true only for these.
    public var occupiedByCreatures: Bool {
        switch self {
        case .trainee, .worshipper, .guard, .gambler: return true
        default: return false
        }
    }
}

public enum StoredGoldVisual: Int, Sendable {
    case additionalResource1 = 1
    case additionalResource2 = 2
    case base = 3

    /// StoredGoldVisuals.update (lines 39-51): integer-division tiers.
    public init(gold: Int, maxGold: Int) {
        guard maxGold > 0 else {
            self = .base
            return
        }
        if gold < maxGold / 3 {
            self = .additionalResource1
        } else if gold < 2 * maxGold / 3 {
            self = .additionalResource2
        } else {
            self = .base
        }
    }
}

public struct MapTileState: Sendable {
    public var terrainId: Short
    public var ownerId: Short
    public var roomId: Short
    public var gold: Int
    public var health: Int

    public init(terrainId: Short = 0, ownerId: Short = 0, roomId: Short = 0,
                gold: Int = 0, health: Int = 0) {
        self.terrainId = terrainId
        self.ownerId = ownerId
        self.roomId = roomId
        self.gold = gold
        self.health = health
    }
}

public struct RoomState: Sendable {
    public var roomId: Short
    public var ownerId: Short
    public var health: Int
    public let maxHealth: Int
    public var destroyed: Bool

    public init(roomId: Short, ownerId: Short, health: Int,
                maxHealth: Int, destroyed: Bool = false) {
        self.roomId = roomId
        self.ownerId = ownerId
        self.health = health
        self.maxHealth = maxHealth
        self.destroyed = destroyed
    }

    public mutating func applyDamage(_ amount: Int) {
        guard !destroyed else { return }
        health = max(0, health - amount)
        if health == 0 { destroyed = true }
    }
}

/// Flat map storage mirroring MapData's `tiles[y * width + x]`.
public struct MapData<Element>: Sendable {
    public let width: Int
    public let height: Int
    private var elements: [Element]

    public init(width: Int, height: Int, initial: Element) {
        precondition(width > 0 && height > 0)
        self.width = width
        self.height = height
        self.elements = [Element](repeating: initial, count: width * height)
    }

    public func index(x: Int, y: Int) -> Int? {
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        return y * width + x
    }

    public func at(x: Int, y: Int) -> Element? {
        guard let i = index(x: x, y: y) else { return nil }
        return elements[i]
    }

    public mutating func set(_ value: Element, x: Int, y: Int) {
        guard let i = index(x: x, y: y) else { return }
        elements[i] = value
    }
}

/// PlayerGoldControl.addGold / subGold: capped balance + lifetime mined counter.
public struct PlayerGold: Sendable {
    public var gold: Int = 0
    public var goldMined: Int = 0
    public var goldMax: Int

    public init(goldMax: Int) {
        self.goldMax = goldMax
    }

    public mutating func addGold(_ value: Int) {
        guard value > 0 else { return }
        gold = min(gold + value, goldMax)
        goldMined += value
    }

    public mutating func subGold(_ value: Int) {
        guard value > 0 else { return }
        gold = max(0, gold - value)
    }

    public var isFullCapacity: Bool { gold >= goldMax }
}
