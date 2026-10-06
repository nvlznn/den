import SwiftUI

/// 倒數時長選擇：15、25、45、60 分鐘，或自訂。
struct DurationPicker: View {
    static let presets = [15, 25, 45, 60]
    static let customRange = 1...180

    @Binding var minutes: Int
    @State private var isCustomizing = false

    var body: some View {
        HStack {
            Text("時長")
                .accessibilityHidden(true)
            Spacer()
            Menu {
                ForEach(Self.presets, id: \.self) { preset in
                    Button {
                        minutes = preset
                    } label: {
                        if preset == minutes {
                            Label("\(preset) 分鐘", systemImage: "checkmark")
                        } else {
                            Text("\(preset) 分鐘")
                        }
                    }
                }
                Divider()
                Button {
                    isCustomizing = true
                } label: {
                    if Self.presets.contains(minutes) {
                        Text("自訂…")
                    } else {
                        Label("自訂…", systemImage: "checkmark")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(DurationText.hoursAndMinutes(TimeInterval(minutes * 60)))
                    Image(systemName: "chevron.up.chevron.down")
                        .imageScale(.small)
                }
            }
            // 讓 VoiceOver 直接落在選單上，啟動就會打開。
            .accessibilityLabel("時長")
            .accessibilityValue(DurationText.hoursAndMinutes(TimeInterval(minutes * 60)))
        }
        .sheet(isPresented: $isCustomizing) {
            CustomDurationSheet(minutes: $minutes, range: Self.customRange)
        }
    }
}

/// 自訂倒數時長，樣子比照時鐘 app 的計時器。
private struct CustomDurationSheet: View {
    @Binding var minutes: Int
    let range: ClosedRange<Int>

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Int

    init(minutes: Binding<Int>, range: ClosedRange<Int>) {
        _minutes = minutes
        self.range = range
        _draft = State(initialValue: min(max(minutes.wrappedValue, range.lowerBound), range.upperBound))
    }

    var body: some View {
        NavigationStack {
            HourMinuteWheel(totalMinutes: $draft, range: range)
                .padding(.horizontal)
                .navigationTitle("自訂時長")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") {
                            minutes = draft
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.medium])
    }
}

/// 小時與分鐘兩個滾輪。總分鐘數一律收在 `range` 裡。
struct HourMinuteWheel: View {
    @Binding var totalMinutes: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 0) {
            Picker("小時", selection: hours) {
                ForEach(range.lowerBound / 60...range.upperBound / 60, id: \.self) { hour in
                    Text("\(hour) 小時").tag(hour)
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()

            Picker("分鐘", selection: minutes) {
                ForEach(minuteOptions, id: \.self) { minute in
                    Text("\(minute) 分鐘").tag(minute)
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .pickerStyle(.wheel)
        .labelsHidden()
    }

    /// 只列出在範圍內的分鐘，例如上限 3 小時時，3 小時那一格只有 0 分鐘。
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
