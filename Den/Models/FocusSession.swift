import Foundation
import SwiftData

/// 一段已完成的專注紀錄。總專注時間是所有紀錄的 `duration` 加總。
@Model
final class FocusSession {
    var startedAt: Date
    var endedAt: Date
    /// 標籤被刪掉時變成 nil，紀錄本身保留。
    var tag: FocusTag?

    var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }

    init(startedAt: Date, endedAt: Date, tag: FocusTag? = nil) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.tag = tag
    }

    /// 沒有標籤時顯示的名稱。
    static let untaggedName = "專注"
}
