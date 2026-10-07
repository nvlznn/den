import Foundation

/// App 寫給 Widget 讀的「今日摘要」。透過 App Group 共用的 UserDefaults 傳遞。
///
/// Widget 不直接讀資料庫（資料庫接著 iCloud），只讀這份小摘要；app 每次紀錄或角色有變就重寫一次。
struct WidgetSnapshot: Codable, Equatable, Sendable {
    static let appGroup = "group.dev.noky.den"
    private static let key = "widgetSnapshot"

    /// 這份摘要是哪一天（那天的 00:00）。過了午夜，今天的數字就要歸零。
    var day: Date
    var todaySeconds: TimeInterval
    var todaySessions: Int
    var characterID: String
    var level: Int
    var progressToNext: Double
    var secondsToNext: TimeInterval

    /// 還沒有任何資料時（例如剛裝好、還沒打開過 app）顯示的內容。
    static func empty(on date: Date = .now, calendar: Calendar = .current) -> WidgetSnapshot {
        WidgetSnapshot(
            day: calendar.startOfDay(for: date),
            todaySeconds: 0,
            todaySessions: 0,
            characterID: "egg",
            level: 0,
            progressToNext: 0,
            secondsToNext: 10 * 3600
        )
    }

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        UserDefaults(suiteName: Self.appGroup)?.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }

    /// 給 `date` 那一刻顯示用：如果摘要是前幾天的，今天的時間和次數歸零，角色和等級不變。
    func asOf(_ date: Date, calendar: Calendar = .current) -> WidgetSnapshot {
        guard !calendar.isDate(day, inSameDayAs: date) else { return self }
        var copy = self
        copy.day = calendar.startOfDay(for: date)
        copy.todaySeconds = 0
        copy.todaySessions = 0
        return copy
    }
}
