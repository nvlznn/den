import Foundation

/// LCD 上的一個點，以像素格為單位。
struct PixelPoint: Hashable, Sendable {
    var x: Int
    var y: Int
}

/// 某一瞬間要畫的寵物：像素圖、上下位移、旁邊飄的 z。
struct PetFrame: Equatable, Sendable {
    var sprite: [String]
    /// 往下為正。
    var offsetY: Int = 0
    /// 相對於寵物左上角。
    var zMarks: [PixelPoint] = []
}

extension PetSprites {
    /// 開心時一次跳躍（上或下）的時間；1.5 秒剛好跳兩下。
    private static let hopInterval: TimeInterval = PetState.happyDuration / 4

    /// 依狀態與時間挑出這一格。每個狀態 2 格，約每 0.6 秒切換。
    static func frame(for activity: PetActivity, at date: Date, happySince: Date?) -> PetFrame {
        let tick = Int((date.timeIntervalSinceReferenceDate / PetState.frameInterval).rounded(.down))
        let isSecondFrame = tick % 2 != 0

        switch activity {
        case .idle:
            // 輕微上下晃動，大約每 5 秒眨一次眼。
            let blinks = tick % 9 == 4
            return PetFrame(sprite: blinks ? idleBlink : idle, offsetY: isSecondFrame ? 1 : 0)

        case .sleeping:
            let z = isSecondFrame ? PixelPoint(x: 18, y: -2) : PixelPoint(x: 16, y: 1)
            return PetFrame(sprite: sleep, zMarks: [z])

        case .studying:
            return PetFrame(sprite: isSecondFrame ? study2 : study1)

        case .happy:
            let sinceHappy = max(0, date.timeIntervalSince(happySince ?? date))
            let inAir = Int(sinceHappy / hopInterval) % 2 == 0
            return PetFrame(sprite: happy, offsetY: inAir ? -3 : 0)
        }
    }
}
