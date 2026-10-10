import Foundation

/// 「一天」從幾點開始。半夜 4 點前的專注算前一天。
///
/// 做法是把時間往前挪 `hour` 小時，再照一般日曆分天，所以紀錄、統計、今天都用同一套。
/// 挪過的時間只拿來分組；顯示幾點幾分時要用 `unshift` 還原。
struct DayBoundary: Equatable, Sendable {
    static let key = "dayStartHour"
    static let defaultHour = 4
    static let hours = 0...5

    /// 存在 App Group，Widget 讀得到。跨裝置的同步見 `DayBoundarySync`。
    static var store: UserDefaults { UserDefaults(suiteName: WidgetSnapshot.appGroup) ?? .standard }

    static var current: DayBoundary {
        DayBoundary(hour: store.object(forKey: key) as? Int ?? defaultHour)
    }

    let hour: Int

    init(hour: Int) {
        self.hour = min(max(hour, Self.hours.lowerBound), Self.hours.upperBound)
    }

    private var offset: TimeInterval { TimeInterval(hour) * 3600 }

    func shift(_ date: Date) -> Date { date.addingTimeInterval(-offset) }
    func unshift(_ date: Date) -> Date { date.addingTimeInterval(offset) }

    /// `date` 所屬那天的 00:00（已挪過的時間）。
    func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: shift(date))
    }

    func isSameDay(_ a: Date, _ b: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(shift(a), inSameDayAs: shift(b))
    }

    /// 下一次換日的真實時間。
    func nextStart(after date: Date, calendar: Calendar = .current) -> Date {
        calendar.nextDate(
            after: date,
            matching: DateComponents(hour: hour, minute: 0, second: 5),
            matchingPolicy: .nextTime
        ) ?? date.addingTimeInterval(24 * 3600)
    }
}
