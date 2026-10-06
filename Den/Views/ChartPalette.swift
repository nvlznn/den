import SwiftUI
import UIKit

/// 圖表的分類色。順序固定、不循環；淺色與深色各自調過，並通過色盲辨識檢查。
/// 超過 8 類時不產生新顏色，而是併成「Other」並用 `other` 的灰色。
enum ChartPalette {
    private static let pairs: [(light: UInt32, dark: UInt32)] = [
        (0x2A78D6, 0x3987E5), // blue
        (0xEB6834, 0xD95926), // orange
        (0x1BAF7A, 0x199E70), // aqua
        (0xEDA100, 0xC98500), // yellow
        (0xE87BA4, 0xD55181), // magenta
        (0x008300, 0x008300), // green
        (0x4A3AA7, 0x9085E9), // violet
        (0xE34948, 0xE66767), // red
    ]

    /// 第 `index` 個分類的顏色（依時長排序後的名次決定，同一個畫面裡固定）。
    static func color(at index: Int) -> Color {
        let pair = pairs[min(index, pairs.count - 1)]
        return dynamic(light: pair.light, dark: pair.dark)
    }

    /// 「Other」用中性灰，不佔分類色。
    static let other = Color(.systemGray)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
