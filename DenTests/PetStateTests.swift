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

    @Test func spritesAreSixteenSquare() {
        let sprites = [
            PetSprites.idle, PetSprites.idleBlink, PetSprites.sleep,
            PetSprites.study1, PetSprites.study2, PetSprites.happy,
        ]
        for sprite in sprites {
            #expect(sprite.count == PetSprites.size)
            #expect(sprite.allSatisfy { $0.count == PetSprites.size })
            #expect(sprite.joined().allSatisfy { $0 == "#" || $0 == "." })
        }
    }

    @Test func everyActivityHasTwoFrames() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        for activity in [PetActivity.idle, .sleeping, .studying, .happy] {
            let first = PetSprites.frame(for: activity, at: start, happySince: start)
            let second = PetSprites.frame(for: activity, at: start.addingTimeInterval(0.6), happySince: start)
            #expect(first != second, "\(activity)")
        }
    }
}
