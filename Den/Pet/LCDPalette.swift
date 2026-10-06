import SwiftUI

/// LCD 螢幕的固定配色。不跟著 Dark Mode 反轉，因為真的 LCD 也不會。
enum LCDPalette {
    /// 偏灰綠的底色。
    static let background = Color(red: 0.616, green: 0.678, blue: 0.525)
    /// 亮的像素：深灰綠。
    static let pixelOn = Color(red: 0.165, green: 0.196, blue: 0.145)
    /// 沒亮的像素：比底色稍深一點點，畫出殘影格線。
    static let pixelOff = Color(red: 0.580, green: 0.643, blue: 0.494)
}
