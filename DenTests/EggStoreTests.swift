import Foundation
import StoreKit
import StoreKitTest
import SwiftData
import Testing
@testable import Den

@Suite(.serialized)
@MainActor
struct EggStoreTests {
    private class BundleMarker {}

    private func session() throws -> SKTestSession {
        let url = try #require(Bundle(for: BundleMarker.self).url(forResource: "Den", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    private func fixture() throws -> (ModelContainer, CharacterLibrary) {
        let schema = Schema([CharacterLibrary.self, EggPurchase.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        var collection = CharacterCollection(shuffledIDs: PetSprites.characters.map(\.id))
        _ = collection.claimFreeEgg(color: .white)
        _ = collection.claimFreeEgg(color: .black)
        let library = CharacterLibrary(collection: collection)
        container.mainContext.insert(library)
        try container.mainContext.save()
        return (container, library)
    }

    @Test func oneConsumableCanBeBoughtFourTimesAndStopsAtCapacity() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        let (container, library) = try fixture()
        let context = container.mainContext
        let store = EggStore()
        await store.load(context: context)
        #expect(store.products.count == 1)
        #expect(store.product?.id == "dev.noky.den.egg")
        #expect(store.product?.type == .consumable)
        for color in [EggColor.white, .black, .white, .black] {
            let id = try #require(await store.purchase(color: color, library: library, context: context))
            #expect(color.characterIDs.contains(id))
        }
        #expect(library.collection.isFull)
        #expect(library.collection.ownedIDs.count == 6)
        #expect(library.collection.purchasedIDs.count == 4)
        let fifth = await store.purchase(color: .white, library: library, context: context)
        #expect(fifth == nil)
        #expect(session.allTransactions().count == 4)
        let receipts = try context.fetch(FetchDescriptor<EggPurchase>())
        #expect(receipts.count == 4)
        #expect(Set(receipts.map(\.transactionID)).count == 4)
        #expect(receipts.allSatisfy { $0.isDelivered })
    }

    @Test func cancellationDoesNotGrantOrReserveAnEgg() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        let (container, library) = try fixture()
        let context = container.mainContext
        let store = EggStore()
        await store.load(context: context)
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        let result = await store.purchase(color: .white, library: library, context: context)
        #expect(result == nil)
        #expect(library.collection.ownedIDs.count == 2)
        let receipts = try context.fetch(FetchDescriptor<EggPurchase>())
        #expect(EggPurchase.reservedIDs(in: receipts).isEmpty)
        #expect(receipts.allSatisfy { !$0.isDelivered })
    }

    @Test func unfinishedPaymentRecoversAndDuplicateDeliveryGrantsOnce() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        let (container, library) = try fixture()
        let context = container.mainContext
        let id = try #require(library.collection.characterID(for: library.collection.nextPaidEgg(of: .black)!))
        let intent = EggPurchase(color: .black, characterID: id)
        context.insert(intent)
        try context.save()
        let transaction = try await session.buyProduct(identifier: EggStore.productID, options: [.appAccountToken(intent.id)])
        let store = EggStore()
        await store.load(context: context)
        #expect(intent.isDelivered)
        #expect(library.collection.purchasedIDs == [id])
        #expect(store.deliver(transaction, context: context))
        #expect(store.deliver(transaction, context: context))
        #expect(library.collection.ownedIDs.count == 3)
        #expect(try context.fetchCount(FetchDescriptor<EggPurchase>()) == 1)
        // A fresh context reads the same saved receipt and character grant.
        let reopened = ModelContext(container)
        let restored = try #require(CharacterLibrary.current(in: reopened))
        #expect(restored.collection.purchasedIDs == [id])
        #expect(try reopened.fetch(FetchDescriptor<EggPurchase>()).first?.transactionID == String(transaction.id))
        await transaction.finish()
    }

    @Test func approvedPendingPurchaseRetainsTheChosenColor() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        let (container, library) = try fixture()
        let context = container.mainContext
        let store = EggStore()
        await store.load(context: context)
        session.askToBuyEnabled = true
        let result = await store.purchase(color: .black, library: library, context: context)
        #expect(result == nil)
        #expect(library.collection.ownedIDs.count == 2)
        let intent = try #require(context.fetch(FetchDescriptor<EggPurchase>()).first)
        #expect(intent.state == "pending")
        #expect(intent.reservesCharacter)
        let pending = try #require(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        for _ in 0..<40 where !intent.isDelivered {
            await store.retryUnfinished(context: context)
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(intent.isDelivered)
        #expect(EggColor.black.characterIDs.contains(intent.characterID))
        #expect(library.collection.purchasedIDs == [intent.characterID])
    }

    @Test func missingCloudIntentWaitsAndRetriesWithoutLosingPayment() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        let (container, library) = try fixture()
        let context = container.mainContext
        let token = UUID()
        let transaction = try await session.buyProduct(identifier: EggStore.productID, options: [.appAccountToken(token)])
        let store = EggStore()
        await store.load(context: context)
        #expect(!store.deliver(transaction, context: context))
        #expect(library.collection.purchasedIDs.isEmpty)
        let id = try #require(library.collection.characterID(for: library.collection.nextPaidEgg(of: .white)!))
        let intent = EggPurchase(color: .white, characterID: id)
        intent.id = token
        context.insert(intent)
        try context.save()
        await store.retryUnfinished(context: context)
        #expect(intent.isDelivered)
        #expect(library.collection.purchasedIDs == [id])
    }

    @Test func refundRemovesOnlyThatGrantAndKeepsExistingProgress() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        let (container, library) = try fixture()
        let context = container.mainContext
        let store = EggStore()
        await store.load(context: context)
        let id = try #require(await store.purchase(color: .white, library: library, context: context))
        var collection = library.collection
        _ = collection.hatch(id, totalSeconds: 36_000)
        library.collection = collection
        try context.save()
        let receipt = try #require(context.fetch(FetchDescriptor<EggPurchase>()).first)
        let purchase = try #require(session.allTransactions().first)
        try session.refundTransaction(identifier: purchase.identifier)
        for _ in 0..<40 where !receipt.revoked {
            await store.retryUnfinished(context: context)
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(receipt.revoked)
        #expect(library.collection.purchasedIDs.isEmpty)
        #expect(library.collection.ownedIDs.count == 2)
        #expect(library.collection.revealed.contains(id))
    }

}
