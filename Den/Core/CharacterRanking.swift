import Foundation

enum CharacterRanking {
    static func totals<Item>(in items: [Item], characterOf: (Item) -> String?,
                             isManual: (Item) -> Bool, duration: (Item) -> TimeInterval) -> [String: TimeInterval] {
        var totals: [String: TimeInterval] = [:]
        for item in items where !isManual(item) {
            totals[characterOf(item) ?? PetSprites.defaultCharacterID, default: 0] += max(0, duration(item))
        }
        return totals
    }

    /// Stable ties retain the collection's original order.
    static func sorted(_ ids: [String], totals: [String: TimeInterval]) -> [String] {
        ids.enumerated().sorted {
            let left = totals[$0.element, default: 0]
            let right = totals[$1.element, default: 0]
            return left == right ? $0.offset < $1.offset : left > right
        }.map(\.element)
    }
}
