import Foundation
import Testing
@testable import Den

struct PetStateTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return calendar
    }()

    private func date(hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: hour, minute: minute))!
    }

    @Test func idleDuringTheDay() {
        let pet = PetState(isTiming: false)
        #expect(pet.activity(at: date(hour: 7), calendar: calendar) == .idle)
        #expect(pet.activity(at: date(hour: 14), calendar: calendar) == .idle)
        #expect(pet.activity(at: date(hour: 22, minute: 59), calendar: calendar) == .idle)
    }

    @Test func sleepsAtNight() {
        let pet = PetState(isTiming: false)
        #expect(pet.activity(at: date(hour: 23), calendar: calendar) == .sleeping)
        #expect(pet.activity(at: date(hour: 3), calendar: calendar) == .sleeping)
        #expect(pet.activity(at: date(hour: 6, minute: 59), calendar: calendar) == .sleeping)
    }

    @Test func studiesWhileTimingDayOrNight() {
        let pet = PetState(isTiming: true)
        #expect(pet.activity(at: date(hour: 14), calendar: calendar) == .studying)
        #expect(pet.activity(at: date(hour: 2), calendar: calendar) == .studying)
    }

    @Test func happyForAboutOneAndAHalfSeconds() {
        let now = date(hour: 2)
        let pet = PetState(isTiming: false, happySince: now)
        #expect(pet.activity(at: now, calendar: calendar) == .happy)
        #expect(pet.activity(at: now.addingTimeInterval(1.4), calendar: calendar) == .happy)
        #expect(pet.activity(at: now.addingTimeInterval(1.5), calendar: calendar) == .sleeping)
    }

    @Test(arguments: PetSprites.characters)
    func spritesAreSixteenSquare(character: PetCharacter) {
        for sprite in [character.idle, character.blink, character.sleep, character.happy] {
            #expect(sprite.count == PetSprites.size)
            #expect(sprite.allSatisfy { $0.count == PetSprites.size })
            #expect(sprite.joined().allSatisfy { $0 == "#" || $0 == "." })
        }
        // 看書時書蓋在角色下方，所以比 16 列高；寬度一樣是 16。
        for sprite in [character.study1, character.study2] {
            #expect(sprite.count >= PetSprites.size)
            #expect(sprite.allSatisfy { $0.count == PetSprites.size })
            #expect(sprite.joined().allSatisfy { $0 == "#" || $0 == "." })
        }
        // 每個表情都要看得出差別。
        #expect(Set([character.idle, character.blink, character.study1, character.study2, character.happy]).count == 5)
    }

    @Test(arguments: PetSprites.characters)
    func everyActivityHasTwoFrames(character: PetCharacter) {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        for activity in [PetActivity.idle, .sleeping, .studying, .happy, .dancing] {
            let first = character.frame(for: activity, at: start, happySince: start)
            let second = character.frame(for: activity, at: start.addingTimeInterval(0.6), happySince: start)
            #expect(first != second, "\(character.name) \(activity)")
        }
    }

    @Test func charactersHaveUniqueIDsAndFangFangIsDefault() {
        let ids = PetSprites.characters.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(PetSprites.characters.first?.id == PetSprites.defaultCharacterID)
        #expect(PetSprites.character(id: nil).name == "Boxy")
        #expect(PetSprites.character(id: "no-such-character").name == "Boxy")
        #expect(PetSprites.character(id: "mochi").name == "Mochi")
    }
}
