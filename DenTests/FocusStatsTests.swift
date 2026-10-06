import Foundation
import Testing
@testable import Den

struct FocusStatsTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        calendar.firstWeekday = 1 // 週日開始
        return calendar
    }()

    private func date(_ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func item(_ start: Date, minutes: Double, tag: String) -> FocusStats.Item {
        FocusStats.Item(startedAt: start, duration: minutes * 60, tagName: tag)
    }

    /// 參考截圖的那一週：週日 5:25、週二 1:06，今天是週二。
    private var weekItems: [FocusStats.Item] {
        [
            item(date(10, 4, 13, 0), minutes: 200, tag: "Kill Debts"),
            item(date(10, 4, 13, 30), minutes: 125, tag: "Kill Debts"),
            item(date(10, 6, 10, 31), minutes: 28, tag: "Kill Debts"),
            item(date(10, 6, 11, 33), minutes: 38, tag: "Tech"),
            item(date(10, 12, 9), minutes: 600, tag: "Tech"), // 下一週，不算
        ]
    }

    @Test func weekOverviewAndFocusDays() {
        let range = StatsRange(period: .week, containing: date(10, 6, 12), calendar: calendar)
        let stats = FocusStats(items: weekItems, range: range, now: date(10, 6, 20), calendar: calendar)

        #expect(stats.totalSessions == 4)
        #expect(stats.totalDuration == (200 + 125 + 28 + 38) * 60)
        #expect(stats.days.count == 7)
        #expect(stats.days.map { $0.duration / 60 } == [325, 0, 66, 0, 0, 0, 0])
        #expect(stats.focusDays == 2)
        #expect(stats.elapsedDays == 3) // 週日、週一、週二
        #expect(stats.dailyAverage == stats.totalDuration / 3)
        #expect(stats.perActiveDay == stats.totalDuration / 2)
        #expect(stats.bestDay == date(10, 4))
        #expect(stats.bestHour == 13)
        #expect(stats.buckets.count == 7)
    }

    @Test func tagBreakdownSortedByDuration() {
        let range = StatsRange(period: .week, containing: date(10, 6, 12), calendar: calendar)
        let stats = FocusStats(items: weekItems, range: range, now: date(10, 6, 20), calendar: calendar)

        #expect(stats.tags.map(\.name) == ["Kill Debts", "Tech"])
        #expect(stats.tags[0].count == 3)
        #expect(stats.tags[0].duration == 353 * 60)
        #expect(abs(stats.tags.map(\.fraction).reduce(0, +) - 1) < 0.000_001)
    }

    @Test func foldsSmallTagsIntoOther() throws {
        let items = (0..<10).map { item(date(10, 6, 9), minutes: Double(10 - $0), tag: "T\($0)") }
        let range = StatsRange(period: .day, containing: date(10, 6, 12), calendar: calendar)
        let folded = FocusStats(items: items, range: range, now: date(10, 6, 20), calendar: calendar).foldedTags(limit: 7)

        #expect(folded.count == 8)
        let other = try #require(folded.last)
        let expected: TimeInterval = (3 + 2 + 1) * 60
        #expect(other.name == "Other")
        #expect(other.count == 3)
        #expect(other.duration == expected)
    }

    @Test func dayHasHourlyBuckets() {
        let range = StatsRange(period: .day, containing: date(10, 6, 12), calendar: calendar)
        let stats = FocusStats(items: weekItems, range: range, now: date(10, 6, 20), calendar: calendar)
        #expect(stats.buckets.count == 24)
        #expect(stats.buckets[10].duration == 28 * 60)
        #expect(stats.buckets[11].duration == 38 * 60)
    }

    @Test func monthAndYearBuckets() {
        let month = StatsRange(period: .month, containing: date(10, 6), calendar: calendar)
        let monthStats = FocusStats(items: weekItems, range: month, now: date(10, 6, 20), calendar: calendar)
        #expect(monthStats.buckets.count == 31)
        #expect(monthStats.elapsedDays == 6)
        #expect(monthStats.totalSessions == 5)

        let year = StatsRange(period: .year, containing: date(10, 6), calendar: calendar)
        let yearStats = FocusStats(items: weekItems, range: year, now: date(10, 6, 20), calendar: calendar)
        #expect(yearStats.buckets.count == 12)
        #expect(yearStats.buckets[9].duration == yearStats.totalDuration)
        #expect(yearStats.bestBucket == date(10, 1))
        #expect(yearStats.days.count == 365)
    }

    @Test func pastPeriodCountsEveryDay() {
        let lastWeek = StatsRange(period: .week, containing: date(10, 6), calendar: calendar).shifted(by: -1, calendar: calendar)
        let stats = FocusStats(items: weekItems, range: lastWeek, now: date(10, 6, 20), calendar: calendar)
        #expect(lastWeek.interval.start == date(9, 27))
        #expect(stats.elapsedDays == 7)
        #expect(stats.totalSessions == 0)
        #expect(stats.dailyAverage == 0)
        #expect(stats.bestDay == nil)
        #expect(stats.bestHour == nil)
    }
}
