import SwiftUI

/// 上半部的復古 LCD 螢幕：點陣格、殘影格線、寵物、`Lv` 文字。
struct LCDScreenView: View {
    /// 螢幕寬度固定 48 格，高度依比例。
    static let columns = 48

    let character: PetCharacter
    let level: Int
    let pet: PetState
    /// 升級時 `Lv` 閃兩下。
    let levelFlashSince: Date?
    /// 指定的話就一直做這件事（慶祝畫面用），不看時間與計時狀態。
    var activityOverride: PetActivity?
    let onPetTap: () -> Void

    private static let levelFlashDuration: TimeInterval = 1.2
    private let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { context in
            let activity = activityOverride ?? pet.activity(at: context.date)
            Canvas { graphics, size in
                draw(in: graphics, size: size, date: context.date, activity: activity)
            }
            .padding(14)
            .background(LCDPalette.background, in: shape)
            .contentShape(shape)
            .onTapGesture(perform: onPetTap)
            .accessibilityElement()
            .accessibilityLabel("\(character.name), level \(level), \(activity.spokenDescription)")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onPetTap() }
        }
    }

    private func draw(in graphics: GraphicsContext, size: CGSize, date: Date, activity: PetActivity) {
        let columns = Self.columns
        let cell = size.width / CGFloat(columns)
        guard cell > 0 else { return }
        let rows = max(1, Int(size.height / cell))
        var grid = PixelGrid(columns: columns, rows: rows)

        let levelOrigin = PixelPoint(x: 2, y: 2)
        if showsLevel(at: date) {
            grid.stamp(LCDFont.render("Lv \(level)"), at: levelOrigin)
        }

        // 寵物在中央偏下。
        let frame = character.frame(for: activity, at: date, happySince: pet.happySince)
        let restingY = min(Int(Double(rows) * 0.62) - PetSprites.size / 2, rows - PetSprites.size - 3)
        let petOrigin = PixelPoint(
            x: (columns - PetSprites.size) / 2 + frame.offsetX,
            y: max(levelOrigin.y + LCDFont.height + 4, restingY) + frame.offsetY
        )
        grid.stamp(frame.sprite, at: petOrigin)
        for z in frame.zMarks {
            grid.stamp(PetSprites.z, at: PixelPoint(x: petOrigin.x + z.x, y: petOrigin.y + z.y))
        }

        // 方塊之間留縫，看起來才像點陣；沒亮的格子也畫出來，是 LCD 質感的關鍵。
        let originY = (size.height - CGFloat(rows) * cell) / 2
        let gap = max(0.5, cell * 0.1)
        var lit = Path()
        var unlit = Path()
        for row in 0..<rows {
            for column in 0..<columns {
                let rect = CGRect(
                    x: CGFloat(column) * cell,
                    y: originY + CGFloat(row) * cell,
                    width: cell - gap,
                    height: cell - gap
                )
                if grid[column, row] {
                    lit.addRect(rect)
                } else {
                    unlit.addRect(rect)
                }
            }
        }
        graphics.fill(unlit, with: .color(LCDPalette.pixelOff))
        graphics.fill(lit, with: .color(LCDPalette.pixelOn))
    }

    /// 平常一直顯示；升級後的 1.2 秒內熄、亮、熄、亮。
    private func showsLevel(at date: Date) -> Bool {
        guard let levelFlashSince else { return true }
        let elapsed = date.timeIntervalSince(levelFlashSince)
        guard (0..<Self.levelFlashDuration).contains(elapsed) else { return true }
        return Int(elapsed / (Self.levelFlashDuration / 4)) % 2 == 1
    }
}

private extension PetActivity {
    var spokenDescription: String {
        switch self {
        case .idle: String(localized: "resting")
        case .sleeping: String(localized: "sleeping")
        case .studying: String(localized: "focusing with you")
        case .happy: String(localized: "happy")
        case .dancing: String(localized: "dancing")
        }
    }
}

/// 一張開或關的點陣。
private struct PixelGrid {
    let columns: Int
    let rows: Int
    private var pixels: [Bool]

    init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        pixels = Array(repeating: false, count: columns * rows)
    }

    subscript(column: Int, row: Int) -> Bool {
        pixels[row * columns + column]
    }

    /// 把像素圖蓋上去；超出螢幕的部分直接裁掉。
    mutating func stamp(_ sprite: [String], at origin: PixelPoint) {
        for (dy, line) in sprite.enumerated() {
            let row = origin.y + dy
            guard (0..<rows).contains(row) else { continue }
            for (dx, character) in line.enumerated() where character == "#" {
                let column = origin.x + dx
                guard (0..<columns).contains(column) else { continue }
                pixels[row * columns + column] = true
            }
        }
    }
}

/// 3×5 的像素字，只收 `Lv` 會用到的字元。
private enum LCDFont {
    static let height = 5

    private static let glyphs: [Character: [String]] = [
        "L": ["#..", "#..", "#..", "#..", "###"],
        "v": ["...", "...", "#.#", "#.#", ".#."],
        " ": ["..", "..", "..", "..", ".."],
        "0": ["###", "#.#", "#.#", "#.#", "###"],
        "1": [".#.", "##.", ".#.", ".#.", "###"],
        "2": ["###", "..#", "###", "#..", "###"],
        "3": ["###", "..#", ".##", "..#", "###"],
        "4": ["#.#", "#.#", "###", "..#", "..#"],
        "5": ["###", "#..", "###", "..#", "###"],
        "6": ["###", "#..", "###", "#.#", "###"],
        "7": ["###", "..#", ".#.", ".#.", ".#."],
        "8": ["###", "#.#", "###", "#.#", "###"],
        "9": ["###", "#.#", "###", "..#", "###"],
    ]

    /// 把字串排成一張像素圖，字與字之間空一格。
    static func render(_ text: String) -> [String] {
        let characters = text.compactMap { glyphs[$0] }
        return (0..<height).map { row in
            characters.map { $0[row] }.joined(separator: ".")
        }
    }
}
