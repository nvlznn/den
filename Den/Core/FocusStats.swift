import Foundation

/// 統計頁的時間單位。
enum StatsPeriod: String, CaseIterable, Identifiable, Sendable {
    case day, week, month, year

    var id: Self { self }

    /// 整個期間的單位。
    var component: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }

    /// 時間分佈長條圖每一根的單位。
    var bucketComponent: Calendar.Component {
        switch self {
        case .day: .hour
        case .week, .month: .day
        case .year: .month
        }
    }
}

/// 統計頁正在看的一段期間，例如「2026 年 10 月」。
struct StatsRange: Hashable, Sendable {
    let period: StatsPeriod
    let interval: DateInterval

    init(period: StatsPeriod, containing date: Date, calendar: Calendar = .current) {
        self.period = period
        interval = calendar.dateInterval(of: period.component, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 24 * 3600)
    }

    func shifted(by count: Int, calendar: Calendar = .current) -> StatsRange {
        let date = calendar.date(byAdding: period.component, value: count, to: interval.start) ?? interval.start
        return StatsRange(period: period, containing: date, calendar: calendar)
    }

    func contains(_ date: Date) -> Bool {
        interval.start <= date && date < interval.end
    }
}

/// 一段期間的專注統計。紀錄依開始時間歸到期間與分組。
struct FocusStats: Sendable {
    struct Item: Sendable {
        var startedAt: Date
        var duration: TimeInterval
        var tagName: String
    }

    /// 長條圖的一根，或某一天的加總。
    struct Bucket: Identifiable, Hashable, Sendable {
        let start: Date
        let duration: TimeInterval
        var id: Date { start }
    }

    struct TagShare: Identifiable, Hashable, Sendable {
        let name: String
        let count: Int
        let duration: TimeInterval
        /// 0–1，佔這段期間總時長的比例。
        let fraction: Double
        var id: String { name }
    }

    let range: StatsRange
    let totalSessions: Int
    let totalDuration: TimeInterval
    /// 長條圖：期間內每個小時（日）、每天（週、月）、每個月（年），沒專注的也在，值為 0。
    let buckets: [Bucket]
    /// 期間內的每一天。
    let days: [Bucket]
    /// 有專注的天數。
    let focusDays: Int
    /// 期間內已經過的天數（含今天）。看過去的期間時就是整段的天數。
    let elapsedDays: Int
    /// 平均每天（以已經過的天數算）。
    let dailyAverage: TimeInterval
    /// 有專注的那幾天，平均每天。
    let perActiveDay: TimeInterval
    /// 一天中專注最多的小時（0–23）。
    let bestHour: Int?
    let bestDay: Date?
    /// 長條圖裡專注最多的那一根（年檢視就是最好的月份）。
    let bestBucket: Date?
    /// 依時長由多到少。
    let tags: [TagShare]

    init(items: [Item], range: StatsRange, now: Date = .now, calendar: Calendar = .current) {
        self.range = range
        let inRange = items.filter { range.contains($0.startedAt) }

        totalSessions = inRange.count
        totalDuration = inRange.reduce(0) { $0 + $1.duration }

        buckets = Self.buckets(of: range.period.bucketComponent, in: range.interval, items: inRange, calendar: calendar)
        days = Self.buckets(of: .day, in: range.interval, items: inRange, calendar: calendar)

        focusDays = days.filter { $0.duration > 0 }.count
        let today = calendar.startOfDay(for: now)
        elapsedDays = days.filter { $0.start <= today }.count

        dailyAverage = elapsedDays > 0 ? totalDuration / Double(elapsedDays) : 0
        perActiveDay = focusDays > 0 ? totalDuration / Double(focusDays) : 0

        let byHour = Dictionary(grouping: inRange) { calendar.component(.hour, from: $0.startedAt) }
            .mapValues { $0.reduce(0) { $0 + $1.duration } }
        bestHour = byHour.max { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }?.key
        bestDay = days.filter { $0.duration > 0 }.max { $0.duration < $1.duration }?.start
        bestBucket = buckets.filter { $0.duration > 0 }.max { $0.duration < $1.duration }?.start

        let total = totalDuration
        tags = Dictionary(grouping: inRange, by: \.tagName)
            .map { name, items in
                let duration = items.reduce(0) { $0 + $1.duration }
                return TagShare(name: name, count: items.count, duration: duration, fraction: total > 0 ? duration / total : 0)
            }
            .sorted { $0.duration > $1.duration || ($0.duration == $1.duration && $0.name < $1.name) }
    }

    /// 超過 `limit` 個標籤時，其餘的併成一個「Other」。
    func foldedTags(limit: Int, otherName: String = String(localized: "Other")) -> [TagShare] {
        guard tags.count > limit else { return tags }
        let rest = tags.dropFirst(limit)
        let other = TagShare(
            name: otherName,
            count: rest.reduce(0) { $0 + $1.count },
            duration: rest.reduce(0) { $0 + $1.duration },
            fraction: rest.reduce(0) { $0 + $1.fraction }
        )
        return Array(tags.prefix(limit)) + [other]
    }

    private static func buckets(
        of component: Calendar.Component,
        in interval: DateInterval,
        items: [Item],
        calendar: Calendar
    ) -> [Bucket] {
        var starts: [Date] = []
        var cursor = interval.start
        while cursor < interval.end {
            starts.append(cursor)
            guard let next = calendar.date(byAdding: component, value: 1, to: cursor) else { break }
            cursor = next
        }
        var totals = Dictionary(uniqueKeysWithValues: starts.map { ($0, TimeInterval(0)) })
        for item in items {
            guard let start = calendar.dateInterval(of: component, for: item.startedAt)?.start,
                  totals[start] != nil else { continue }
            totals[start, default: 0] += item.duration
        }
        return starts.map { Bucket(start: $0, duration: totals[$0] ?? 0) }
    }
}
