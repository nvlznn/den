import Foundation
import SwiftData

/// 專注標籤，例如「讀書」、「工作」。
@Model
final class FocusTag {
    /// 穩定的識別碼，用來記住目前選的標籤，以及寫進進行中的計時。
    var id: UUID
    var name: String
    /// 在列表裡的順序，越小越前面。
    var order: Int

    @Relationship(deleteRule: .nullify, inverse: \FocusSession.tag)
    var sessions: [FocusSession] = []

    init(name: String, order: Int) {
        self.id = UUID()
        self.name = name
        self.order = order
    }

    static let defaultNames = ["讀書", "工作", "其他"]
}
