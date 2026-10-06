import Foundation

/// 總專注時間換算成等級。每累積 1 小時升 1 級，從 Lv 0 開始，只會上升。
struct Level: Equatable, Sendable {
    static let secondsPerLevel: TimeInterval = 3600

    let totalSeconds: TimeInterval

    init(totalSeconds: TimeInterval) {
        self.totalSeconds = max(0, totalSeconds)
    }

    /// 等級 = 總專注秒數 / 3600，無條件捨去。
    var number: Int {
        Int(totalSeconds / Self.secondsPerLevel)
    }

    /// 距離下一級的進度，0–1。
    var progressToNext: Double {
        totalSeconds.truncatingRemainder(dividingBy: Self.secondsPerLevel) / Self.secondsPerLevel
    }
}
