import Foundation

/// 時長的文字格式。
enum DurationText {
    /// 「2 hr 15 min」、「40 min」。秒數無條件捨去。
    static func hoursAndMinutes(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(max(0, interval)) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        switch (hours, minutes) {
        case (0, _): return String(localized: "\(minutes) min")
        case (_, 0): return String(localized: "\(hours) hr")
        default: return String(localized: "\(hours) hr \(minutes) min")
        }
    }

    /// 慶祝畫面用：不到 1 分鐘顯示秒數（「45 sec」），其他同 `hoursAndMinutes`。
    static func spoken(_ interval: TimeInterval) -> String {
        interval < 60 ? String(localized: "\(Int(max(0, interval))) sec") : hoursAndMinutes(interval)
    }

    /// 「1:23:45」；不到 1 小時是「24:59」。
    static func clock(_ seconds: Int) -> String {
        let seconds = max(0, seconds)
        let h = seconds / 3600
        let m = seconds / 60 % 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
