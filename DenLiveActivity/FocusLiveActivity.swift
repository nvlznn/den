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
                    PetIcon(characterID: context.attributes.characterID, color: LCDPalette.background)
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
                    Text(context.attributes.tagName ?? (context.attributes.endsAt == nil ? "Stopwatch" : "Countdown"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                PetIcon(characterID: context.attributes.characterID, color: LCDPalette.background)
                    .frame(width: 20, height: 20)
            } compactTrailing: {
                TimerText(attributes: context.attributes, isStale: context.isStale)
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
    let isStale: Bool

    var body: some View {
        HStack(spacing: 14) {
            PetIcon(characterID: attributes.characterID, color: LCDPalette.pixelOn)
                .padding(8)
                .frame(width: 52, height: 52)
                .background(LCDPalette.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text([attributes.endsAt == nil ? "Focusing" : "Countdown", attributes.tagName].compactMap { $0 }.joined(separator: " · "))
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
                    // 時間到之後計時不會停：從 0 開始往上數超時的部分。
                    HStack(spacing: 2) {
                        Text("+")
                        Text(timerInterval: endsAt...endsAt.addingTimeInterval(Self.stopwatchSpan), countsDown: false)
                    }
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

#Preview("Countdown", as: .content, using: FocusActivityAttributes(startedAt: .now, endsAt: .now.addingTimeInterval(25 * 60), tagName: "Study", characterID: "fangfang")) {
    FocusLiveActivity()
} contentStates: {
    FocusActivityAttributes.ContentState()
}
