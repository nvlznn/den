import Foundation
import SwiftData

/// 一段已完成的專注紀錄。總專注時間是所有紀錄的 `duration` 加總。
@Model
final class FocusSession {
    var startedAt: Date
    var endedAt: Date

    var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }

    init(startedAt: Date, endedAt: Date) {
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}
