import Foundation

/// 時長的文字格式。
enum DurationText {
    /// 介面只支援英文，日期也固定用英文排，避免和裝置語系混雜。
    static let locale = Locale(identifier: "en_US")

    /// 「2 hr 15 min」、「40 min」。秒數無條件捨去。
    static func hoursAndMinutes(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(max(0, interval)) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        switch (hours, minutes) {
        case (0, _): return "\(minutes) min"
        case (_, 0): return "\(hours) hr"
        default: return "\(hours) hr \(minutes) min"
        }
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
