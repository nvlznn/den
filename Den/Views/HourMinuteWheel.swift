import SwiftUI

/// 小時與分鐘兩個滾輪，樣子比照時鐘 app 的計時器。總分鐘數一律收在 `range` 裡。
struct HourMinuteWheel: View {
    @Binding var totalMinutes: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 0) {
            Picker("Hours", selection: hours) {
                ForEach(range.lowerBound / 60...range.upperBound / 60, id: \.self) { hour in
                    Text("\(hour) hr").tag(hour)
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()

            Picker("Minutes", selection: minutes) {
                ForEach(minuteOptions, id: \.self) { minute in
                    Text("\(minute) min").tag(minute)
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .pickerStyle(.wheel)
        .labelsHidden()
    }

    /// 只列出在範圍內的分鐘，例如上限 3 小時時，3 hr 那一格只有 0 min。
    private var minuteOptions: ClosedRange<Int> {
        let hour = totalMinutes / 60
        let lower = hour == range.lowerBound / 60 ? range.lowerBound % 60 : 0
        let upper = hour == range.upperBound / 60 ? range.upperBound % 60 : 59
        return lower...upper
    }

    private var hours: Binding<Int> {
        Binding {
            totalMinutes / 60
        } set: { hour in
            totalMinutes = clamped(hour * 60 + totalMinutes % 60)
        }
    }

    private var minutes: Binding<Int> {
        Binding {
            totalMinutes % 60
        } set: { minute in
            totalMinutes = clamped(totalMinutes / 60 * 60 + minute)
        }
    }

    private func clamped(_ value: Int) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
