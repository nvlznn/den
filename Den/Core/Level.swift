import Foundation

/// 玩家的總專注時間換算成等級，所有角色共用。每累積 5 小時升 1 級，從 Lv 0 開始。
struct Level: Equatable, Sendable {
    static let secondsPerLevel: TimeInterval = 5 * 3600

    let totalSeconds: TimeInterval

    init(totalSeconds: TimeInterval) {
        self.totalSeconds = max(0, totalSeconds)
    }

    /// 等級 = 總專注秒數 / 18000，無條件捨去。
    var number: Int {
        Int(totalSeconds / Self.secondsPerLevel)
    }

    /// 距離下一級的進度，0–1。
    var progressToNext: Double {
        totalSeconds.truncatingRemainder(dividingBy: Self.secondsPerLevel) / Self.secondsPerLevel
    }

    /// 距離下一級還要多少秒。
    var secondsToNext: TimeInterval {
        Self.secondsPerLevel - totalSeconds.truncatingRemainder(dividingBy: Self.secondsPerLevel)
    }
}

extension Level {
    /// 玩家的累積秒數：所有角色加起來。手動補的紀錄不算進等級。
    static func totalSeconds<Item>(
        in items: [Item],
        isManual: (Item) -> Bool,
        duration: (Item) -> TimeInterval
    ) -> TimeInterval {
        items
            .filter { !isManual($0) }
            .reduce(0) { $0 + max(0, duration($1)) }
    }
}
