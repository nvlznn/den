import Foundation
import SwiftData

/// 一段已完成的專注紀錄。總專注時間是所有紀錄的 `duration` 加總。
///
/// 會透過 iCloud 同步，所以每個欄位都要有預設值（CloudKit 的限制）。
@Model
final class FocusSession {
    var startedAt: Date = Date.distantPast
    var endedAt: Date = Date.distantPast
    /// 標籤被刪掉時變成 nil，紀錄本身保留。
    var tag: FocusTag?
    /// 標籤名稱的備份。標籤被刪掉之後，紀錄仍然以原本的名稱顯示在紀錄和統計裡。
    var tagName: String?
    /// 當時陪著專注的角色。舊紀錄沒有，算給預設角色。
    var characterID: String?
    /// 在紀錄頁手動補的。會顯示在紀錄裡，但不算進等級。
    var isManual: Bool = false

    var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }

    init(startedAt: Date, endedAt: Date, tag: FocusTag? = nil, characterID: String? = nil, isManual: Bool = false) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.tag = tag
        self.tagName = tag?.name
        self.characterID = characterID
        self.isManual = isManual
    }

    /// 紀錄和統計上顯示的標籤名稱：標籤還在就用它現在的名字，被刪掉了就用備份的原名。
    var displayTagName: String {
        tag?.name ?? tagName ?? Self.untaggedName
    }

    /// 沒有標籤、也沒有備份名稱時顯示的名稱。
    static let untaggedName = "Focus"
}
