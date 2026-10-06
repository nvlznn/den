import ActivityKit
import SwiftUI
import WidgetKit

/// 鎖定畫面與動態島上的計時。時間用 `Text(timerInterval:countsDown:)` 由系統自己更新。
struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state, isStale: context.isStale)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PetIcon(characterID: context.attributes.characterID, color: LCDPalette.background)
                        .frame(width: 36, height: 36)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimerText(state: context.state, isStale: context.isStale)
                        .font(.title2.weight(.medium))
                        .frame(maxWidth: 140, alignment: .trailing)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.pausedAt != nil ? "Paused" : (context.attributes.tagName ?? (context.state.endsAt == nil ? "Stopwatch" : "Countdown")))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                PetIcon(characterID: context.attributes.characterID, color: LCDPalette.background)
                    .frame(width: 20, height: 20)
            } compactTrailing: {
                TimerText(state: context.state, isStale: context.isStale)
                    .frame(maxWidth: 64, alignment: .trailing)
            } minimal: {
                PetIcon(characterID: context.attributes.characterID, color: LCDPalette.background)
                    .frame(width: 20, height: 20)
            }
        }
    }
}

private struct LockScreenView: View {
    let attributes: FocusActivityAttributes
    let state: FocusActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        HStack(spacing: 14) {
            PetIcon(characterID: attributes.characterID, color: LCDPalette.pixelOn)
                .padding(8)
                .frame(width: 52, height: 52)
                .background(LCDPalette.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            // 只留標籤名字，靠左、放大；沒有標籤時寫 Focus；暫停時改寫 Paused。
            Text(state.pausedAt != nil ? "Paused" : (attributes.tagName ?? "Focus"))
                .font(.title2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)

            TimerText(state: state, isStale: isStale)
                .font(.system(size: 44, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: 170, alignment: .trailing)
        }
        .padding()
    }
}

private struct TimerText: View {
    /// 正計時的上限只是給 `Text(timerInterval:)` 一個範圍；Live Activity 本身撐不到這麼久。
    private static let stopwatchSpan: TimeInterval = 24 * 3600

    let state: FocusActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        Group {
            if let pausedText = state.pausedText {
                // 暫停中：直接顯示 app 算好的固定文字，數字一定不動。
                Text(pausedText)
            } else if let endsAt = state.endsAt {
                if isStale || endsAt <= .now {
                    // 時間到之後計時不會停：從 0 開始往上數超時的部分。
                    HStack(spacing: 2) {
                        Text("+")
                        Text(timerInterval: endsAt...endsAt.addingTimeInterval(Self.stopwatchSpan), countsDown: false)
                    }
                } else {
                    Text(timerInterval: state.startedAt...endsAt, countsDown: true)
                }
            } else {
                Text(
                    timerInterval: state.startedAt...state.startedAt.addingTimeInterval(Self.stopwatchSpan),
                    countsDown: false
                )
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
    }
}

/// 陪讀中的角色像素圖。
private struct PetIcon: View {
    let characterID: String?
    let color: Color

    var body: some View {
        PixelSprite(pixels: PetSprites.character(id: characterID).study1)
            .fill(color)
            .aspectRatio(1, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

#Preview("Countdown", as: .content, using: FocusActivityAttributes(tagName: "Study", characterID: "fangfang")) {
    FocusLiveActivity()
} contentStates: {
    FocusActivityAttributes.ContentState(startedAt: .now, endsAt: .now.addingTimeInterval(25 * 60), pausedAt: nil, pausedText: nil)
    FocusActivityAttributes.ContentState(startedAt: .now, endsAt: .now.addingTimeInterval(25 * 60), pausedAt: .now, pausedText: "20:00")
}
