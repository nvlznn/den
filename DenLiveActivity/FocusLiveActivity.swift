import ActivityKit
import SwiftUI
import WidgetKit

/// 鎖定畫面與動態島上的計時。時間用 `Text(timerInterval:countsDown:)` 由系統自己更新。
struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, isStale: context.isStale)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PetIcon(color: LCDPalette.background)
                        .frame(width: 36, height: 36)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimerText(attributes: context.attributes, isStale: context.isStale)
                        .font(.title2.weight(.medium))
                        .frame(maxWidth: 140, alignment: .trailing)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.endsAt == nil ? "正計時" : "倒數")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                PetIcon(color: LCDPalette.background)
                    .frame(width: 20, height: 20)
            } compactTrailing: {
                TimerText(attributes: context.attributes, isStale: context.isStale)
                    .frame(maxWidth: 64, alignment: .trailing)
            } minimal: {
                PetIcon(color: LCDPalette.background)
                    .frame(width: 20, height: 20)
            }
        }
    }
}

private struct LockScreenView: View {
    let attributes: FocusActivityAttributes
    let isStale: Bool

    var body: some View {
        HStack(spacing: 14) {
            PetIcon(color: LCDPalette.pixelOn)
                .padding(8)
                .frame(width: 52, height: 52)
                .background(LCDPalette.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(attributes.endsAt == nil ? "專注中" : "倒數中")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TimerText(attributes: attributes, isStale: isStale)
                    .font(.title.weight(.medium))
            }
            Spacer(minLength: 0)
        }
        .padding()
    }
}

private struct TimerText: View {
    /// 正計時的上限只是給 `Text(timerInterval:)` 一個範圍；Live Activity 本身撐不到這麼久。
    private static let stopwatchSpan: TimeInterval = 24 * 3600

    let attributes: FocusActivityAttributes
    let isStale: Bool

    var body: some View {
        Group {
            if let endsAt = attributes.endsAt {
                if isStale || endsAt <= .now {
                    Text("時間到了")
                } else {
                    Text(timerInterval: attributes.startedAt...endsAt, countsDown: true)
                }
            } else {
                Text(
                    timerInterval: attributes.startedAt...attributes.startedAt.addingTimeInterval(Self.stopwatchSpan),
                    countsDown: false
                )
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
    }
}

/// 陪讀中的寵物像素圖。
private struct PetIcon: View {
    let color: Color

    var body: some View {
        PixelSprite(pixels: PetSprites.study1)
            .fill(color)
            .aspectRatio(1, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

private struct PixelSprite: Shape {
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

#Preview("倒數", as: .content, using: FocusActivityAttributes(startedAt: .now, endsAt: .now.addingTimeInterval(25 * 60))) {
    FocusLiveActivity()
} contentStates: {
    FocusActivityAttributes.ContentState()
}
