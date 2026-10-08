import Foundation
import SwiftData

/// 專注標籤，例如「Study」、「Work」。
///
/// 會透過 iCloud 同步，所以每個欄位都要有預設值、關聯要是 optional（CloudKit 的限制）。
@Model
final class FocusTag {
    /// 穩定的識別碼，用來記住目前選的標籤，以及寫進進行中的計時。
    var id: UUID = UUID()
    var name: String = ""
    /// 在列表裡的順序，越小越前面。
    var order: Int = 0

    @Relationship(deleteRule: .nullify, inverse: \FocusSession.tag)
    var sessions: [FocusSession]? = []

    init(name: String, order: Int) {
        self.id = UUID()
        self.name = name
        self.order = order
    }

    static let defaultNames = [String(localized: "Study"), String(localized: "Work"), String(localized: "Other")]
}
