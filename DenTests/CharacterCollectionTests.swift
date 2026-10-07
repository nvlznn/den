import Foundation
import SwiftData
import Testing
@testable import Den

struct CharacterCollectionTests {
    let ids = ["fangfang", "doudou", "mochi", "drop", "cloud", "orb"]

    @Test func firstLaunchWaitsForAnExplicitColorChoice() {
        var collection = CharacterCollection(shuffledIDs: ids)
        #expect(collection.needsFirstEgg)
        #expect(collection.ownedIDs.isEmpty)
        let chosen = collection.claimFreeEgg(color: .white)
        #expect(chosen == "mochi")
        #expect(collection.ownedIDs == ["mochi"])
        #expect(collection.displayID(for: "mochi") == "egg.white")
        #expect(!collection.needsFirstEgg)
    }

    @Test func eitherColorCanBeChosenForBothFreeEggs() {
        for first in EggColor.allCases {
            for second in EggColor.allCases {
                var collection = CharacterCollection(shuffledIDs: ids)
                let one = collection.claimFreeEgg(color: first)
                let two = collection.claimFreeEgg(color: second)
                #expect(one != two)
                #expect(one.map { first.characterIDs.contains($0) } == true)
                #expect(two.map { second.characterIDs.contains($0) } == true)
                let extra = collection.claimFreeEgg(color: .white)
                #expect(extra == nil)
                #expect(collection.ownedIDs.count == 2)
            }
        }
    }

    @Test func unhatchedEggsReserveColorCapacity() {
        var collection = CharacterCollection(shuffledIDs: ids)
        _ = collection.claimFreeEgg(color: .white)
        _ = collection.claimFreeEgg(color: .white)
        #expect(collection.remainingCount(of: .white) == 1)
        let paid = collection.nextPaidEgg(of: .white)!
        collection.paidEggs.insert(paid)
        #expect(collection.revealed.isEmpty)
        #expect(collection.remainingCount(of: .white) == 0)
        #expect(collection.nextPaidEgg(of: .white) == nil)
        #expect(collection.remainingCount(of: .black) == 3)
        #expect(!collection.isFull)
    }

    @Test func hatchesAtExactlyLevelOneAndNeverRepeats() {
        var collection = CharacterCollection(shuffledIDs: ids)
        _ = collection.claimFreeEgg(color: .black)
        let early = collection.hatch("fangfang", totalSeconds: 35_999)
        let unowned = collection.hatch("mochi", totalSeconds: 36_000)
        let hatched = collection.hatch("fangfang", totalSeconds: 36_000)
        #expect(!early)
        #expect(!unowned)
        #expect(hatched)
        #expect(collection.displayID(for: "fangfang") == "fangfang")
        let repeated = collection.hatch("fangfang", totalSeconds: 36_000)
        let reduced = collection.hatch("fangfang", totalSeconds: 0)
        #expect(!repeated)
        #expect(!reduced)
        #expect(collection.displayID(for: "fangfang") == "fangfang")
    }

    @Test func purchasingEveryRemainingEggProducesSixDistinctCharacters() {
        for _ in 0..<30 {
            var collection = CharacterCollection(shuffledIDs: ids.shuffled())
            _ = collection.claimFreeEgg(color: .black)
            _ = collection.claimFreeEgg(color: .white)
            for color in EggColor.allCases {
                while let slot = collection.nextPaidEgg(of: color) {
                    collection.paidEggs.insert(slot)
                    collection.paidEggs.insert(slot) // duplicate delivery
                }
            }
            #expect(collection.isFull)
            #expect(collection.ownedIDs.count == 6)
            #expect(Set(collection.ownedIDs).count == 6)
            #expect(collection.paidEggs.count == 4)
            #expect(collection.nextPaidEgg(of: .white) == nil)
            #expect(collection.nextPaidEgg(of: .black) == nil)
        }
    }

    @Test func refundAndRestoreKeepTheSameColorAndSpecies() throws {
        var collection = CharacterCollection(shuffledIDs: ids.shuffled())
        _ = collection.claimFreeEgg(color: .black)
        _ = collection.claimFreeEgg(color: .black)
        let slot = collection.nextPaidEgg(of: .white)!
        let species = collection.characterID(for: slot)
        collection.paidEggs.insert(slot)
        let data = try JSONEncoder().encode(collection)
        var restored = try JSONDecoder().decode(CharacterCollection.self, from: data)
        restored.paidEggs.remove(slot)
        #expect(!restored.ownedIDs.contains(species!))
        restored.paidEggs.insert(slot)
        #expect(restored.characterID(for: slot) == species)
        #expect(restored.displayID(for: species!) == "egg.white")
    }

    @Test func legacyCharactersKeepProgressAndMatchTheirEggColor() {
        var collection = CharacterCollection(legacyIDs: ["mochi", "mochi", "orb"], shuffledIDs: ids)
        #expect(Set(collection.ownedIDs) == ["mochi", "orb"])
        #expect(!collection.needsFirstEgg)
        #expect(collection.displayID(for: "mochi") == "egg.white")
        #expect(collection.displayID(for: "orb") == "egg.black")
        let hatched = collection.hatch("orb", totalSeconds: 72_000)
        #expect(hatched)
        #expect(collection.displayID(for: "orb") == "orb")
        #expect(collection.remainingCount(of: .white) == 2)
        #expect(collection.remainingCount(of: .black) == 2)
    }

    @Test func allSixLegacyCharactersStayUnlockedWithoutPurchases() {
        let collection = CharacterCollection(legacyIDs: ids, shuffledIDs: ids.shuffled())
        #expect(collection.isFull)
        #expect(collection.paidEggs.isEmpty)
        #expect(!collection.canClaimFreeEgg)
    }

    @Test func oldSingleColorDevelopmentSaveMigratesWithoutLosingSpecies() throws {
        let json = #"{"order":["fangfang","mochi","orb","drop","cloud","doudou"],"freeCount":2,"legacyCount":0,"paidSlots":[2],"revealed":["fangfang"]}"#
        let collection = try JSONDecoder().decode(CharacterCollection.self, from: Data(json.utf8))
        #expect(Set(collection.ownedIDs) == ["fangfang", "mochi", "orb"])
        #expect(collection.displayID(for: "fangfang") == "fangfang")
        #expect(collection.displayID(for: "mochi") == "egg.white")
        #expect(collection.displayID(for: "orb") == "egg.black")
    }

    @Test @MainActor func migrationPreservesRecordsAndHatchesOnlyEligibleCharacters() throws {
        let schema = Schema([FocusSession.self, FocusTag.self, CharacterLibrary.self, FocusContribution.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        context.insert(FocusSession(startedAt: .distantPast, endedAt: Date.distantPast.addingTimeInterval(1800), characterID: "mochi"))
        context.insert(FocusSession(startedAt: .distantPast, endedAt: Date.distantPast.addingTimeInterval(36_000), characterID: "orb"))
        context.insert(FocusSession(startedAt: .distantPast, endedAt: Date.distantPast.addingTimeInterval(99_999), characterID: "mochi", isManual: true))
        let library = try CharacterLibrary.prepare(in: context)
        #expect(Set(library.collection.ownedIDs) == ["mochi", "orb"])
        #expect(library.collection.displayID(for: "mochi") == "egg.white")
        #expect(library.collection.displayID(for: "orb") == "orb")
        #expect(try context.fetchCount(FetchDescriptor<FocusSession>()) == 3)
        #expect(try CharacterLibrary.prepare(in: context).id == library.id)
    }

    @Test func previousColoredEggSaveKeepsItsPurchases() throws {
        var previous = CharacterCollection(shuffledIDs: ids)
        _ = previous.claimFreeEgg(color: .white)
        _ = previous.claimFreeEgg(color: .black)
        let slot = previous.nextPaidEgg(of: .white)!
        previous.paidEggs.insert(slot)
        let encoded = try JSONEncoder().encode(previous)
        var json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json.removeValue(forKey: "purchasedIDs")
        let oldData = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(CharacterCollection.self, from: oldData)
        #expect(restored.ownedIDs == previous.ownedIDs)
        #expect(restored.paidEggs == [slot])
        #expect(restored.purchasedIDs.isEmpty)
    }

    @Test @MainActor func partialCloudDownloadDoesNotEraseSavedPurchases() throws {
        let container = try ModelContainer(for: CharacterLibrary.self, EggPurchase.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        var collection = CharacterCollection(shuffledIDs: ids)
        _ = collection.claimFreeEgg(color: .white)
        _ = collection.claimFreeEgg(color: .black)
        collection.purchasedIDs.insert("drop")
        let library = CharacterLibrary(collection: collection)
        context.insert(library)
        try context.save()
        try library.reconcile(purchases: [], context: context)
        #expect(library.collection.purchasedIDs == ["drop"])
        let receipt = EggPurchase(color: .white, characterID: "drop")
        receipt.transactionID = "100"
        receipt.state = "delivered"
        context.insert(receipt)
        try library.reconcile(purchases: [receipt, receipt], context: context)
        #expect(library.collection.purchasedIDs == ["drop"])
        receipt.revoked = true
        try library.reconcile(purchases: [receipt], context: context)
        #expect(library.collection.purchasedIDs.isEmpty)
        #expect(library.collection.ownedIDs.count == 2)
    }

    @Test func exactlyThreeCharactersPerColorAndValidEggPixels() {
        #expect(EggColor.white.characterIDs.count == 3)
        #expect(EggColor.black.characterIDs.count == 3)
        #expect(Set(EggColor.allCases.flatMap(\.characterIDs)) == Set(PetSprites.characters.map(\.id)))
        for egg in [PetSprites.whiteEgg, PetSprites.blackEgg] {
            for frame in [egg.idle, egg.blink, egg.study1, egg.study2, egg.sleep, egg.happy] {
                #expect(frame.count == 16)
                #expect(frame.allSatisfy { $0.count == 16 && $0.allSatisfy { $0 == "." || $0 == "#" } })
            }
            #expect(egg.isEgg)
        }
        #expect(EggSlot.all.count == 6)
        #expect(EggSlot(productID: "dev.noky.den.egg.white.2")?.color == .white)
        #expect(EggSlot(productID: "unknown") == nil)
    }
}

struct FocusContributionTests {
    @Test @MainActor func originalDurationIsCapturedOnceAndManualEntriesAreExcluded() throws {
        let schema = Schema([FocusSession.self, FocusTag.self, FocusContribution.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        let session = FocusSession(startedAt: .distantPast, endedAt: Date.distantPast.addingTimeInterval(1800))
        let manual = FocusSession(startedAt: .distantPast, endedAt: Date.distantPast.addingTimeInterval(99_999), isManual: true)
        context.insert(session)
        context.insert(manual)
        FocusContribution.capture(session, context: context)
        FocusContribution.capture(manual, context: context)
        session.endedAt = session.startedAt.addingTimeInterval(9999)
        FocusContribution.capture(session, context: context)
        try context.save()
        let contributions = try context.fetch(FetchDescriptor<FocusContribution>())
        #expect(contributions.count == 1)
        #expect(contributions.first?.seconds == 1800)
        context.delete(session)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<FocusContribution>()) == 1)
    }
}
