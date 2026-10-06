import ActivityKit
import Foundation

/// 鎖定畫面與動態島上的計時。時間由系統自己更新，app 不推送任何更新，
/// 所以狀態全部放在不會變的 attributes 裡。
struct FocusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {}

    var startedAt: Date
    /// 倒數的預定結束時間；正計時為 nil。
    var endsAt: Date?
}
