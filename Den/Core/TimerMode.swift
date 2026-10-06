import Foundation

/// 計時的兩種模式。
///
/// 兩者的差別只有「什麼時候結束」和「畫面顯示哪個數字」，
/// 累積時數的算法完全一樣。
enum TimerMode: Codable, Hashable, Sendable {
    /// 正計時，沒有目標。
    case stopwatch
    /// 倒數，`planned` 是預定時長（秒）。
    case countdown(planned: TimeInterval)

    /// 「專注時長」設定裡的分鐘數；`unlimitedMinutes`（Stopwatch）代表正計時。
    init(focusMinutes: Int) {
        if focusMinutes == Self.unlimitedMinutes {
            self = .stopwatch
        } else {
            self = .countdown(planned: TimeInterval(focusMinutes * 60))
        }
    }

    /// 專注時長設定中代表 Stopwatch（正計時）的值。
    static let unlimitedMinutes = 0

    /// 時長滾輪的選項：Stopwatch，然後 5 分鐘到 3 小時，每 5 分鐘一格。
    static let focusMinuteChoices = [unlimitedMinutes] + Array(stride(from: 5, through: 180, by: 5))
}
