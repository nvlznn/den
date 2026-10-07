import Foundation

/// Internal positions in a color's shuffled deck; old product IDs remain for migration.
/// Both free and purchased eggs consume the same three positions per color.
struct EggSlot: Hashable, Codable, Sendable, Identifiable {
    let color: EggColor
    let number: Int
    var id: String { "\(color.rawValue).\(number)" }
    var productID: String { "dev.noky.den.egg.\(id)" }

    static let all: [EggSlot] = EggColor.allCases.flatMap { color in
        (1...color.characterIDs.count).map { EggSlot(color: color, number: $0) }
    }

    init(color: EggColor, number: Int) {
        self.color = color
        self.number = number
    }

    init?(productID: String) {
        guard let slot = Self.all.first(where: { $0.productID == productID }) else { return nil }
        self = slot
    }
}

/// The random order is saved once. An egg's species stays hidden until Lv 1;
/// reserving it at acquisition prevents two unhatched eggs drawing duplicates.
struct CharacterCollection: Codable, Equatable, Sendable {
    var order: [String]
    private(set) var freeIDs: [String]
    private(set) var legacyIDs: Set<String>
    var paidEggs: Set<EggSlot> = [] // Previous non-consumable development purchases.
    var purchasedIDs: Set<String> = []
    var revealed: Set<String>

    init(legacyIDs: [String] = [], shuffledIDs: [String]) {
        var seen = Set<String>()
        let deck = shuffledIDs.filter { EggColor.of(characterID: $0) != nil && seen.insert($0).inserted }
        order = deck
        let legacy = legacyIDs.filter { deck.contains($0) }
        self.legacyIDs = Set(legacy)
        var free = [String]()
        for id in legacy where !free.contains(id) && free.count < 2 { free.append(id) }
        freeIDs = free
        revealed = []
    }

    var ownedIDs: [String] {
        let owned = Set(freeIDs).union(legacyIDs).union(purchasedIDs).union(paidEggs.compactMap(characterID(for:)))
        return order.filter { owned.contains($0) }
    }
    var needsFirstEgg: Bool { freeIDs.isEmpty && legacyIDs.isEmpty && !isFull }
    var isFull: Bool { ownedIDs.count == order.count }
    var canClaimFreeEgg: Bool { freeIDs.count < 2 && !isFull }

    func characterID(for slot: EggSlot) -> String? {
        let pool = order.filter { slot.color.characterIDs.contains($0) }
        guard (1...pool.count).contains(slot.number) else { return nil }
        return pool[slot.number - 1]
    }

    func remainingCount(of color: EggColor) -> Int {
        order.filter { color.characterIDs.contains($0) && !ownedIDs.contains($0) }.count
    }

    func nextSlot(of color: EggColor) -> EggSlot? {
        EggSlot.all.first { slot in
            slot.color == color && characterID(for: slot).map { !ownedIDs.contains($0) } == true
        }
    }

    func nextPaidEgg(of color: EggColor) -> EggSlot? {
        guard !canClaimFreeEgg else { return nil }
        return nextSlot(of: color)
    }

    mutating func claimFreeEgg(color: EggColor) -> String? {
        guard canClaimFreeEgg, let slot = nextSlot(of: color), let id = characterID(for: slot) else { return nil }
        freeIDs.append(id)
        return id
    }

    mutating func hatch(_ characterID: String, totalSeconds: TimeInterval) -> Bool {
        guard ownedIDs.contains(characterID), totalSeconds >= Level.secondsPerLevel else { return false }
        return revealed.insert(characterID).inserted
    }

    func displayID(for characterID: String) -> String {
        if revealed.contains(characterID) { return characterID }
        return (EggColor.of(characterID: characterID) ?? .white).spriteID
    }

    // Preserve data from the earlier single-color development build as well.
    private enum CodingKeys: String, CodingKey {
        case order, freeIDs, legacyIDs, paidEggs, purchasedIDs, revealed, freeCount, legacyCount, paidSlots
    }

    init(from decoder: Decoder) throws {
        let data = try decoder.container(keyedBy: CodingKeys.self)
        order = try data.decode([String].self, forKey: .order)
        revealed = try data.decode(Set<String>.self, forKey: .revealed)
        purchasedIDs = try data.decodeIfPresent(Set<String>.self, forKey: .purchasedIDs) ?? []
        if let free = try data.decodeIfPresent([String].self, forKey: .freeIDs) {
            freeIDs = free
            legacyIDs = try data.decode(Set<String>.self, forKey: .legacyIDs)
            paidEggs = try data.decode(Set<EggSlot>.self, forKey: .paidEggs)
        } else {
            freeIDs = Array(order.prefix(try data.decode(Int.self, forKey: .freeCount)))
            legacyIDs = Set(order.prefix(try data.decode(Int.self, forKey: .legacyCount)))
            let indices = try data.decode(Set<Int>.self, forKey: .paidSlots)
            paidEggs = Set(EggSlot.all.filter { slot in
                guard let id = characterID(for: slot), let index = order.firstIndex(of: id) else { return false }
                return indices.contains(index)
            })
        }
    }

    func encode(to encoder: Encoder) throws {
        var data = encoder.container(keyedBy: CodingKeys.self)
        try data.encode(order, forKey: .order)
        try data.encode(freeIDs, forKey: .freeIDs)
        try data.encode(legacyIDs, forKey: .legacyIDs)
        try data.encode(paidEggs, forKey: .paidEggs)
        try data.encode(purchasedIDs, forKey: .purchasedIDs)
        try data.encode(revealed, forKey: .revealed)
    }
}
