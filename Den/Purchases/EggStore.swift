import Foundation
import Observation
import StoreKit
import SwiftData

@MainActor
@Observable
final class EggStore {
    static let productID = "dev.noky.den.egg"
    static let productIDs = [productID]
    private(set) var products: [Product] = []
    private(set) var legacyEggs = Set<EggSlot>()
    private(set) var isBusy = false
    private(set) var isLoading = false
    var message: String?
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var listener: Task<Void, Never>?
    @ObservationIgnored private var isRetrying = false

    var product: Product? { products.first { $0.id == Self.productID } }

    init() {
        listener = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self, let context = self.context,
                      case .verified(let transaction) = result else { continue }
                if self.deliver(transaction, context: context) { await transaction.finish() }
            }
        }
    }

    deinit { listener?.cancel() }

    func load(context: ModelContext) async {
        self.context = context
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        await retryUnfinished(context: context)
        // Compatibility only: new purchases always use the single consumable.
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.revocationDate == nil, let slot = EggSlot(productID: transaction.productID) {
                legacyEggs.insert(slot)
            }
        }
        do { products = try await Product.products(for: Self.productIDs) }
        catch { message = String(localized: "Store unavailable.") }
    }

    func retryUnfinished(context: ModelContext) async {
        self.context = context
        guard !isRetrying else { return }
        isRetrying = true
        defer { isRetrying = false }
        // Finished consumable history is enabled in Info.plist. Refresh saved
        // receipts as well, so refunds received while Den was closed are applied.
        for await result in Transaction.all {
            guard case .verified(let transaction) = result else { continue }
            _ = deliver(transaction, context: context)
        }
        for await result in Transaction.unfinished {
            guard case .verified(let transaction) = result else { continue }
            if deliver(transaction, context: context) { await transaction.finish() }
        }
    }

    func purchase(color: EggColor, library: CharacterLibrary, context: ModelContext) async -> String? {
        self.context = context
        guard !isBusy, let product, !library.collection.canClaimFreeEgg else { return nil }
        isBusy = true
        defer { isBusy = false }
        let intent: EggPurchase
        do {
            let purchases = try context.fetch(FetchDescriptor<EggPurchase>())
            let reserved = EggPurchase.reservedIDs(in: purchases)
            let collection = library.collection
            guard let id = collection.order.first(where: {
                color.characterIDs.contains($0) && !collection.ownedIDs.contains($0) && !reserved.contains($0)
            }) else { return nil }
            intent = EggPurchase(color: color, characterID: id)
            context.insert(intent)
            try context.save()
        } catch {
            message = String(localized: "Couldn’t save. No purchase started.")
            return nil
        }
        do {
            switch try await product.purchase(options: [.appAccountToken(intent.id)]) {
            case .success(let result):
                guard case .verified(let transaction) = result else {
                    message = String(localized: "Purchase verification failed.")
                    return nil
                }
                guard deliver(transaction, context: context) else { return nil }
                await transaction.finish()
                return intent.isDelivered ? intent.characterID : nil
            case .pending:
                if intent.isDelivered { return intent.characterID }
                intent.state = "pending"
                try context.save()
                message = String(localized: "Awaiting approval.")
            case .userCancelled:
                if intent.isDelivered { return intent.characterID }
                intent.state = "cancelled"
                try context.save()
            @unknown default: break
            }
        } catch {
            if intent.isDelivered { return intent.characterID }
            // A thrown purchase did not deliver a verified transaction. Any later
            // unfinished transaction still has its intent for recovery.
            intent.state = "cancelled"
            try? context.save()
            message = String(localized: "Purchase failed.")
        }
        return nil
    }

    /// Called by success, updates and recovery. The transaction ID is the delivery
    /// key; the persisted token fixes its character before Apple charges.
    @discardableResult
    func deliver(_ transaction: Transaction, context: ModelContext) -> Bool {
        if let slot = EggSlot(productID: transaction.productID) {
            if transaction.revocationDate == nil { legacyEggs.insert(slot) }
            return true
        }
        guard transaction.productID == Self.productID else { return false }
        do {
            let purchases = try context.fetch(FetchDescriptor<EggPurchase>())
            let transactionID = String(transaction.id)
            guard let intent = purchases.first(where: { $0.transactionID == transactionID })
                    ?? purchases.first(where: { $0.id == transaction.appAccountToken }),
                  intent.transactionID.isEmpty || intent.transactionID == transactionID,
                  let library = CharacterLibrary.current(in: context) else {
                // Its private iCloud intent may not have downloaded yet.
                return false
            }
            intent.transactionID = transactionID
            intent.state = "delivered"
            intent.revoked = transaction.revocationDate != nil
            try library.reconcile(purchases: purchases, context: context)
            try context.save()
            return true
        } catch {
            message = String(localized: "Purchase saved by Apple. Reopen Den to finish.")
            return false
        }
    }
}
