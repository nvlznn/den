import Foundation

/// 紀錄頁上顯示的一週。
struct RecordWeek: Hashable, Sendable {
    let interval: DateInterval

    init(containing date: Date, calendar: Calendar = .current) {
        interval = calendar.dateInterval(of: .weekOfYear, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 7 * 24 * 3600)
    }

    /// 往前（負數）或往後移幾週。
    func shifted(by weeks: Int, calendar: Calendar = .current) -> RecordWeek {
        let date = calendar.date(byAdding: .weekOfYear, value: weeks, to: interval.start) ?? interval.start
        return RecordWeek(containing: date, calendar: calendar)
    }

    var firstDay: Date { interval.start }

    /// 這週的最後一天（不是下週的第一天）。
    func lastDay(calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
    }

    func contains(_ date: Date) -> Bool {
        interval.start <= date && date < interval.end
    }
}

/// 同一天的紀錄與加總。
struct DayGroup<Item>: Identifiable {
    /// 那一天的 00:00。
    let day: Date
    /// 新的在前。
    let items: [Item]
    let totalDuration: TimeInterval

    var id: Date { day }
    var count: Int { items.count }
}

enum RecordGrouping {
    /// 把落在 `interval` 裡的紀錄依開始那天分組，新的日子在前。
    static func days<Item>(
        _ items: [Item],
        in interval: DateInterval,
        calendar: Calendar = .current,
        startedAt: (Item) -> Date,
        duration: (Item) -> TimeInterval
    ) -> [DayGroup<Item>] {
        let inRange = items.filter { interval.start <= startedAt($0) && startedAt($0) < interval.end }
        let byDay = Dictionary(grouping: inRange) { calendar.startOfDay(for: startedAt($0)) }
        return byDay
            .map { day, items in
                DayGroup(
                    day: day,
                    items: items.sorted { startedAt($0) > startedAt($1) },
                    totalDuration: items.reduce(0) { $0 + duration($1) }
                )
            }
            .sorted { $0.day > $1.day }
    }
}
