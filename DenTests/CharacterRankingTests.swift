import Foundation
import Testing
@testable import Den

struct CharacterRankingTests {
    @Test func ranksBySecondsWithStableTies() {
        #expect(CharacterRanking.sorted(["mochi", "drop", "cloud", "orb"],
                                        totals: ["mochi": 100, "drop": 300, "cloud": 300])
                == ["drop", "cloud", "mochi", "orb"])
    }

    @Test func usesActualFocusAndSupportsLegacyRecords() {
        struct Record { let character: String?; let manual: Bool; let seconds: Double }
        let records = [Record(character: "drop", manual: false, seconds: 120),
                       Record(character: "drop", manual: false, seconds: 60),
                       Record(character: "mochi", manual: true, seconds: 10000),
                       Record(character: nil, manual: false, seconds: 90)]
        let totals = CharacterRanking.totals(in: records, characterOf: \.character,
                                             isManual: \.manual, duration: \.seconds)
        #expect(totals["drop"] == 180)
        #expect(totals[PetSprites.defaultCharacterID] == 90)
        #expect(totals.values.reduce(0, +) == 270)
    }

    @Test func eggsHaveUnnumberedNames() {
        #expect(PetSprites.character(id: "egg.white").name == "White Egg")
        #expect(PetSprites.character(id: "egg.black").name == "Black Egg")
    }
}
