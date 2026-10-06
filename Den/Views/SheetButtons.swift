import SwiftUI

/// Sheet 左上角的 ✕。iOS 26 起用系統的關閉按鈕。
struct SheetCloseButton: View {
    let action: () -> Void

    var body: some View {
        if #available(iOS 26, *) {
            Button(role: .close, action: action)
        } else {
            Button(action: action) {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Close")
        }
    }
}

/// Sheet 右上角的 ✓。iOS 26 起用系統的確認按鈕。
struct SheetConfirmButton: View {
    let action: () -> Void

    var body: some View {
        if #available(iOS 26, *) {
            Button(role: .confirm, action: action)
        } else {
            Button(action: action) {
                Image(systemName: "checkmark")
            }
            .accessibilityLabel("Done")
        }
    }
}
