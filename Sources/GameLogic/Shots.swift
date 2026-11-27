/// Ported from OpenKeeper:
/// game/controller/ShotsController.java:174, 305-389 (damage types),
/// game/controller/shot/LightningShotProcessor.java:81-85 (water double damage).

import Foundation

public enum ShotDamageType: Int, Sendable {
    case hitThing = 0
    case constant = 1
    case rangeFromOrigin = 2
    case modifyHealth = 3
    case drain = 4
}

public struct ShotHit: Sendable {
    public let tile: Tile
    public let damage: Int

    public init(tile: Tile, damage: Int) {
        self.tile = tile
        self.damage = damage
    }
}

public enum ShotRules {
    /// ShotsController.damage: RANGE_FROM_ORIGIN uses
    /// damage = (int)(damage * (radius - distance) / radius).
    public static func rangeDamage(damage: Int, radius: Int, distance: Int) -> Int {
        guard radius > 0, distance < radius else { return 0 }
        return damage * (radius - distance) / radius
    }

    /// CONSTANT hits every non-owner creature in the square radius.
    public static func constantHits(origin: Tile, radius: Int, damage: Int) -> [ShotHit] {
        var hits: [ShotHit] = []
        for x in (origin.x - radius)..<(origin.x + radius) {
            for y in (origin.y - radius)..<(origin.y + radius) {
                hits.append(ShotHit(tile: Tile(x: x, y: y), damage: damage))
            }
        }
        return hits
    }

    /// MODIFY_HEALTH heals by -shotData1; DRAIN transfers at most a percentage
    /// of the shooter's maximum health, capped by the target's current health.
    public static func drain(targetHealth: Int, shooterMaxHealth: Int,
                             percent: Int) -> Int {
        min(targetHealth, shooterMaxHealth * percent / 100)
    }

    /// LightningShotProcessor: double damage on water.
    public static func lightningDamage(base: Int, onWater: Bool) -> Int {
        onWater ? base * 2 : base
    }
}
