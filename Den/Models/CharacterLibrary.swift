import Foundation
import SwiftData

/// Private iCloud data, including the shuffle and the once-only free egg claim.
@Model
final class CharacterLibrary {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var payload: Data = Data()

    init(collection: CharacterCollection) {
        payload = (try? JSONEncoder().encode(collection)) ?? Data()
    }

    var collection: CharacterCollection {
        get {
            (try? JSONDecoder().decode(CharacterCollection.self, from: payload))
                ?? CharacterCollection(shuffledIDs: PetSprites.characters.map(\.id))
        }
        set {
            guard newValue != collection else { return }
            payload = (try? JSONEncoder().encode(newValue)) ?? payload
        }
    }

    @MainActor
    static func current(in context: ModelContext) -> CharacterLibrary? {
        let descriptor = FetchDescriptor<CharacterLibrary>(sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.id)])
        return try? context.fetch(descriptor).first
    }

    @MainActor
    static func prepare(in context: ModelContext) throws -> CharacterLibrary {
        if let current = current(in: context) {
            var collection = current.collection
            let additions = PetSprites.characters.map(\.id).filter { !collection.order.contains($0) }
            if !additions.isEmpty {
                collection.order += additions.shuffled()
                current.collection = collection
                try context.save()
            }
            return current
        }
        let sessions = try context.fetch(FetchDescriptor<FocusSession>(sortBy: [SortDescriptor(\.startedAt)]))
        let legacy = sessions.filter { !$0.isManual }.map { $0.characterID ?? PetSprites.defaultCharacterID }
        let library = CharacterLibrary(collection: CharacterCollection(
            legacyIDs: legacy,
            shuffledIDs: PetSprites.characters.map(\.id).shuffled()
        ))
        context.insert(library)
        try library.reconcile(sessions: sessions, context: context)
        try context.save()
        return library
    }

    @MainActor
    func reconcile(purchases: [EggPurchase], context: ModelContext) throws {
        var updated = collection
        let delivered = Set(purchases.filter(\.isDelivered).map(\.characterID))
        updated.purchasedIDs.formUnion(delivered)
        // Keep previously synced grants while their receipts download. Remove only
        // explicit revocations, and keep grants backed by another valid receipt.
        for purchase in purchases where purchase.revoked && !delivered.contains(purchase.characterID) {
            updated.purchasedIDs.remove(purchase.characterID)
        }
        if updated != collection {
            collection = updated
            try context.save()
        }
    }

    @MainActor
    func reconcile(sessions: [FocusSession], context: ModelContext) throws {
        var updated = collection
        for id in updated.ownedIDs {
            let seconds = Level.totalSeconds(of: id, defaultID: PetSprites.defaultCharacterID,
                in: sessions, characterOf: \.characterID, isManual: \.isManual, duration: \.duration)
            _ = updated.hatch(id, totalSeconds: seconds)
        }
        if updated != collection {
            collection = updated
            try context.save()
        }
    }
}
