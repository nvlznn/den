import ActivityKit
import Foundation

/// 鎖定畫面與動態島上的計時。時間由系統用 `Text(timerInterval:)` 自己更新；
/// 只有暫停、繼續的時候 app 才會更新一次內容。
struct FocusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// 扣掉暫停時間之後的開始時間，計時從這裡算起。
        var startedAt: Date
        /// 倒數的預定結束時間（已把暫停的時間順延）；正計時為 nil。
        var endsAt: Date?
        /// 暫停開始的時間；沒有暫停就是 nil。
        var pausedAt: Date?
        /// 暫停時要顯示的固定文字（例如 `12:34`、`+0:45`）。暫停時不靠任何計時元件，直接顯示它，數字才一定不動。
        var pausedText: String?
    }

    /// 開始時選的標籤。
    var tagName: String?
    /// 陪著專注的角色，動態島上畫的就是牠。
    var characterID: String?
}
