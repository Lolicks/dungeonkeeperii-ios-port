/// Ported from GameWorldController.addGold / substractGold (lines 252-338)
/// and PlayerGoldControl.addGold (lines 40-48).

public struct Treasury: Sendable {
    public var gold: Int
    public let capacity: Int

    public init(gold: Int, capacity: Int) {
        self.gold = gold
        self.capacity = capacity
    }
}

public enum EconomyLogic {
    /// Deposits as much as possible; returns the amount that did not fit.
    public static func addGold(_ amount: Int, to treasuries: inout [Treasury]) -> Int {
        var left = amount
        for index in treasuries.indices {
            let space = max(0, treasuries[index].capacity - treasuries[index].gold)
            let deposit = min(left, space)
            treasuries[index].gold += deposit
            left -= deposit
        }
        return left
    }

    /// Removes ceil(amount / n) from each treasury, capped by its gold.
    /// Returns the unpaid remainder.
    public static func subGold(_ amount: Int, from treasuries: inout [Treasury]) -> Int {
        guard !treasuries.isEmpty else { return amount }
        let perTreasury = (amount + treasuries.count - 1) / treasuries.count
        var left = amount
        for index in treasuries.indices {
            let take = min(perTreasury, treasuries[index].gold, left)
            treasuries[index].gold -= take
            left -= take
        }
        return left
    }
}
