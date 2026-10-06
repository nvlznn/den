import Foundation
import Testing
@testable import Den

struct RecordGroupingTests {
    struct Item: Equatable {
        let startedAt: Date
        let duration: TimeInterval
    }

    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        calendar.firstWeekday = 1 // 週日開始
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    @Test func weekRunsSundayToSaturday() {
        let week = RecordWeek(containing: date(6, 12), calendar: calendar)
        #expect(week.firstDay == date(4, 0))
        #expect(week.lastDay(calendar: calendar) == date(10, 0))
        #expect(week.contains(date(10, 23, 59)))
        #expect(!week.contains(date(11, 0)))
    }

    @Test func shiftingWeeks() {
        let week = RecordWeek(containing: date(6, 12), calendar: calendar)
        let september27 = calendar.date(from: DateComponents(year: 2026, month: 9, day: 27))!
        #expect(week.shifted(by: -1, calendar: calendar).firstDay == september27)
        #expect(week.shifted(by: 1, calendar: calendar).firstDay == date(11, 0))
        #expect(week.shifted(by: -1, calendar: calendar).shifted(by: 1, calendar: calendar) == week)
    }

    @Test func groupsByDayNewestFirstWithTotals() {
        let items = [
            Item(startedAt: date(4, 17, 35), duration: 1890),
            Item(startedAt: date(6, 10, 31), duration: 1686),
            Item(startedAt: date(6, 11, 33), duration: 1933),
            Item(startedAt: date(4, 17, 45), duration: 76),
            Item(startedAt: date(6, 10, 52), duration: 387),
            Item(startedAt: date(12, 9), duration: 600), // 下一週，不算
        ]
        let week = RecordWeek(containing: date(6, 12), calendar: calendar)
        let days = RecordGrouping.days(
            items, in: week.interval, calendar: calendar,
            startedAt: \.startedAt, duration: \.duration
        )

        #expect(days.map(\.day) == [date(6, 0), date(4, 0)])
        #expect(days[0].count == 3)
        #expect(days[0].totalDuration == 1933 + 387 + 1686)
        #expect(days[0].items.map(\.startedAt) == [date(6, 11, 33), date(6, 10, 52), date(6, 10, 31)])
        #expect(days[1].count == 2)
        #expect(days[1].totalDuration == 1966)
    }

    @Test func emptyWeekHasNoDays() {
        let week = RecordWeek(containing: date(6, 12), calendar: calendar)
        let days = RecordGrouping.days(
            [Item](), in: week.interval, calendar: calendar,
            startedAt: \.startedAt, duration: \.duration
        )
        #expect(days.isEmpty)
    }
}

struct FocusDurationTests {
    @Test func infinityMeansStopwatch() {
        #expect(TimerMode(focusMinutes: TimerMode.unlimitedMinutes) == .stopwatch)
        #expect(TimerMode(focusMinutes: 25) == .countdown(planned: 1500))
    }

    @Test func choicesStartWithInfinityThenFiveMinuteSteps() {
        let choices = TimerMode.focusMinuteChoices
        #expect(choices.first == TimerMode.unlimitedMinutes)
        #expect(Array(choices.dropFirst().prefix(3)) == [5, 10, 15])
        #expect(choices.last == 180)
        #expect(choices.contains(25))
    }
}
