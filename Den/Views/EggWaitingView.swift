import SwiftUI

/// 第一次打開、等 iCloud 第一次下載的時候：LCD 色的方塊裡一顆白蛋一格一格地跳。
/// 等完之後蛋停下來，方塊縮小、飛進選蛋頁白蛋的位置（`FirstEggFrameKey`），落地時和那裡的縮圖一模一樣；
/// 不用選蛋（老使用者重新安裝）就整個淡出。
struct EggWaitingView: View {
    enum Phase { case waiting, settled, flying }

    let phase: Phase
    /// 選蛋頁白蛋的位置，全螢幕座標。
    let target: CGRect?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let hopInterval: TimeInterval = 0.375
    private let egg = PetSprites.character(id: EggColor.white.spriteID)

    var body: some View {
        GeometryReader { proxy in
            let size = min(240, proxy.size.width - 48)
            let resting = CGRect(x: (proxy.size.width - size) / 2, y: proxy.size.height * 0.42 - size / 2,
                                 width: size, height: size)
            let isFlying = phase == .flying
            let rect = isFlying ? (target ?? resting) : resting

            ZStack {
                Color(.systemBackground)
                    .opacity(isFlying ? 0 : 1)

                TimelineView(.periodic(from: .now, by: Self.hopInterval)) { context in
                    let tick = Int(context.date.timeIntervalSinceReferenceDate / Self.hopInterval)
                    let inAir = phase == .waiting && !reduceMotion && tick % 2 == 0
                    EggTile(sprite: inAir ? egg.happy : egg.idle, hop: inAir ? 3 : 0, isWaiting: !isFlying)
                }
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .opacity(isFlying && target == nil ? 0 : 1)

                Text("Warming up your egg…")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .position(x: proxy.size.width / 2, y: resting.maxY + 40)
                    .opacity(phase == .waiting ? 1 : 0)
            }
        }
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.25), value: phase == .settled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Warming up your egg…"))
    }
}

/// 等待時蛋小一點、上面留空間跳；不等了就變成和 `CharacterThumbnail` 一樣的比例，落地時才接得上。
private struct EggTile: View {
    let sprite: [String]
    /// 往上跳幾格像素。
    let hop: Int
    let isWaiting: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size.width
            let padding = isWaiting ? size * 0.24 : 8
            let pixel = (size - padding * 2) / CGFloat(PetSprites.size)
            ZStack {
                RoundedRectangle(cornerRadius: isWaiting ? 22 : 10, style: .continuous)
                    .fill(LCDPalette.background)
                PixelSprite(pixels: sprite)
                    .fill(LCDPalette.pixelOn)
                    .padding(padding)
                    .offset(y: -CGFloat(hop) * pixel)
            }
        }
    }
}
