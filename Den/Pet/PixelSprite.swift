import SwiftUI

/// 把像素圖畫成一個形狀，給縮圖和動態島用。LCD 螢幕本身用 Canvas 畫。
struct PixelSprite: Shape {
    let pixels: [String]

    func path(in rect: CGRect) -> Path {
        let rows = pixels.count
        let columns = pixels.map(\.count).max() ?? 0
        guard rows > 0, columns > 0 else { return Path() }

        let cell = min(rect.width / CGFloat(columns), rect.height / CGFloat(rows))
        let origin = CGPoint(
            x: rect.midX - cell * CGFloat(columns) / 2,
            y: rect.midY - cell * CGFloat(rows) / 2
        )

        var path = Path()
        for (row, line) in pixels.enumerated() {
            for (column, character) in line.enumerated() where character == "#" {
                path.addRect(CGRect(
                    x: origin.x + CGFloat(column) * cell,
                    y: origin.y + CGFloat(row) * cell,
                    width: cell,
                    height: cell
                ))
            }
        }
        return path
    }
}
