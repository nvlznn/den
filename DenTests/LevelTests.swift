import Foundation
import Testing
@testable import Den

struct LevelTests {
    @Test func startsAtZero() {
        let level = Level(totalSeconds: 0)
        #expect(level.number == 0)
        #expect(level.progressToNext == 0)
    }

    @Test func roundsDown() {
        #expect(Level(totalSeconds: 3599).number == 0)
        #expect(Level(totalSeconds: 3600).number == 1)
        #expect(Level(totalSeconds: 7199).number == 1)
    }

    @Test func oneLevelPerHour() {
        #expect(Level(totalSeconds: 37 * 3600).number == 37)
        #expect(Level(totalSeconds: 37 * 3600 + 59 * 60).number == 37)
    }

    @Test func progressToNextLevel() {
        #expect(Level(totalSeconds: 12 * 3600 + 1800).progressToNext == 0.5)
        #expect(Level(totalSeconds: 900).progressToNext == 0.25)
        #expect(Level(totalSeconds: 3600).progressToNext == 0)
    }

    @Test func neverNegative() {
        let level = Level(totalSeconds: -100)
        #expect(level.number == 0)
        #expect(level.progressToNext == 0)
    }
}

struct DurationTextTests {
    @Test func hoursAndMinutes() {
        #expect(DurationText.hoursAndMinutes(0) == "0 分鐘")
        #expect(DurationText.hoursAndMinutes(25 * 60) == "25 分鐘")
        #expect(DurationText.hoursAndMinutes(25 * 60 + 59) == "25 分鐘")
        #expect(DurationText.hoursAndMinutes(3600) == "1 小時")
        #expect(DurationText.hoursAndMinutes(2 * 3600 + 15 * 60) == "2 小時 15 分鐘")
    }

    @Test func clock() {
        #expect(DurationText.clock(0) == "0:00")
        #expect(DurationText.clock(25 * 60) == "25:00")
        #expect(DurationText.clock(59) == "0:59")
        #expect(DurationText.clock(3600 + 23 * 60 + 45) == "1:23:45")
    }
}
