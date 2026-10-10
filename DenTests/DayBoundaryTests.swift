import Foundation
import Testing
@testable import Den

struct DayBoundaryTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    @Test func lateNightStaysOnThePreviousDay() {
        let boundary = DayBoundary(hour: 4)
        #expect(boundary.isSameDay(date(9, 23), date(10, 3, 59), calendar: calendar))
        #expect(!boundary.isSameDay(date(10, 3, 59), date(10, 4), calendar: calendar))
    }

    @Test func zeroHourIsPlainMidnight() {
        let boundary = DayBoundary(hour: 0)
        #expect(!boundary.isSameDay(date(9, 23, 59), date(10, 0), calendar: calendar))
        #expect(boundary.startOfDay(date(10, 12), calendar: calendar) == date(10, 0))
    }

    @Test func shiftRoundTripsAndNextStartIsTheBoundary() {
        let boundary = DayBoundary(hour: 4)
        #expect(boundary.unshift(boundary.shift(date(10, 9))) == date(10, 9))
        #expect(boundary.nextStart(after: date(10, 3), calendar: calendar) == date(10, 4, 0).addingTimeInterval(5))
        #expect(boundary.nextStart(after: date(10, 5), calendar: calendar) == date(11, 4, 0).addingTimeInterval(5))
    }

    @Test func hourIsClamped() {
        #expect(DayBoundary(hour: -3).hour == 0)
        #expect(DayBoundary(hour: 30).hour == 5)
    }

    @Test func staleWidgetSnapshotResetsOnlyAfterTheBoundary() {
        let boundary = DayBoundary(hour: 4)
        var snapshot = WidgetSnapshot.empty(on: date(10, 10), boundary: boundary)
        snapshot.todaySeconds = 600
        #expect(snapshot.asOf(date(11, 3), boundary: boundary).todaySeconds == 600)
        #expect(snapshot.asOf(date(11, 5), boundary: boundary).todaySeconds == 0)
    }
}
