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
        #expect(Level(totalSeconds: 5 * 3600 - 1).number == 0)
        #expect(Level(totalSeconds: 5 * 3600).number == 1)
        #expect(Level(totalSeconds: 10 * 3600 - 1).number == 1)
    }

    @Test func oneLevelPerFiveHours() {
        #expect(Level(totalSeconds: 17 * 3600).number == 3)
        #expect(Level(totalSeconds: 185 * 3600).number == 37)
    }

    @Test func progressToNextLevel() {
        #expect(Level(totalSeconds: 62 * 3600 + 1800).progressToNext == 0.5)
        #expect(Level(totalSeconds: 4500).progressToNext == 0.25)
        #expect(Level(totalSeconds: 5 * 3600).progressToNext == 0)
    }

    @Test func timeLeftToEvolve() {
        #expect(Level(totalSeconds: 0).secondsToNext == 5 * 3600)
        #expect(Level(totalSeconds: 6 * 3600 + 40 * 60).secondsToNext == 3 * 3600 + 20 * 60)
        #expect(Level(totalSeconds: 5 * 3600).secondsToNext == 5 * 3600)
    }

    /// 等級是玩家的：所有角色的時間加起來；手動補的紀錄不算。
    @Test func levelIsSharedByAllCharacters() {
        let items: [(characterID: String?, isManual: Bool, duration: TimeInterval)] = [
            (nil, false, 1800),           // 舊紀錄也算
            ("fangfang", false, 3600),
            ("mochi", false, 7200),
            ("mochi", false, 600),
            ("mochi", true, 99_999),      // 手動補的不算
            (nil, true, 99_999),          // 手動補的不算
        ]
        let total = Level.totalSeconds(in: items, isManual: \.isManual, duration: \.duration)
        #expect(total == 13_200)
        #expect(Level(totalSeconds: total * 10).number == 7)
        #expect(Level.totalSeconds(in: [(isManual: false, duration: -60.0)], isManual: \.isManual, duration: \.duration) == 0)
    }

    @Test func neverNegative() {
        let level = Level(totalSeconds: -100)
        #expect(level.number == 0)
        #expect(level.progressToNext == 0)
    }
}

struct DurationTextTests {
    @Test func hoursAndMinutes() {
        #expect(DurationText.hoursAndMinutes(0) == "0 min")
        #expect(DurationText.hoursAndMinutes(25 * 60) == "25 min")
        #expect(DurationText.hoursAndMinutes(25 * 60 + 59) == "25 min")
        #expect(DurationText.hoursAndMinutes(3600) == "1 hr")
        #expect(DurationText.hoursAndMinutes(2 * 3600 + 15 * 60) == "2 hr 15 min")
    }

    @Test func spokenShowsSecondsUnderAMinute() {
        #expect(DurationText.spoken(15) == "15 sec")
        #expect(DurationText.spoken(59.9) == "59 sec")
        #expect(DurationText.spoken(60) == "1 min")
        #expect(DurationText.spoken(2 * 3600 + 15 * 60) == "2 hr 15 min")
    }

    @Test func clock() {
        #expect(DurationText.clock(0) == "0:00")
        #expect(DurationText.clock(25 * 60) == "25:00")
        #expect(DurationText.clock(59) == "0:59")
        #expect(DurationText.clock(3600 + 23 * 60 + 45) == "1:23:45")
    }
}
