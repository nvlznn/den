import Foundation

/// 總專注時間換算成等級。每累積 10 小時升 1 級，從 Lv 0 開始。
struct Level: Equatable, Sendable {
    static let secondsPerLevel: TimeInterval = 10 * 3600

    let totalSeconds: TimeInterval

    init(totalSeconds: TimeInterval) {
        self.totalSeconds = max(0, totalSeconds)
    }

    /// 等級 = 總專注秒數 / 36000，無條件捨去。
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
    /// 某個角色的累積秒數。每個角色的等級各自計算；沒有記角色的舊紀錄算給 `defaultID`。
    /// 手動補的紀錄不算進等級。
    static func totalSeconds<Item>(
        of characterID: String,
        defaultID: String,
        in items: [Item],
        characterOf: (Item) -> String?,
        isManual: (Item) -> Bool,
        duration: (Item) -> TimeInterval
    ) -> TimeInterval {
        items
            .filter { !isManual($0) && (characterOf($0) ?? defaultID) == characterID }
            .reduce(0) { $0 + duration($1) }
    }
}
