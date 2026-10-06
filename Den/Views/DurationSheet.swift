import SwiftUI

/// 選擇專注時長。最上面的 No limit 是正計時，其他是倒數。
struct DurationSheet: View {
    @Binding var minutes: Int

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Int

    init(minutes: Binding<Int>) {
        _minutes = minutes
        let choices = TimerMode.focusMinuteChoices
        let current = minutes.wrappedValue
        // 不在選項裡的舊值，靠到最接近的一格。
        let nearest = choices.min { abs($0 - current) < abs($1 - current) } ?? 25
        _draft = State(initialValue: choices.contains(current) ? current : nearest)
    }

    var body: some View {
        NavigationStack {
            Picker("Focus Duration", selection: $draft) {
                ForEach(TimerMode.focusMinuteChoices, id: \.self) { choice in
                    Text(Self.wheelLabel(choice))
                        .tag(choice)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .padding(.horizontal)
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle("Select Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCloseButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    SheetConfirmButton {
                        minutes = draft
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    static func wheelLabel(_ minutes: Int) -> String {
        minutes == TimerMode.unlimitedMinutes ? "No limit" : "\(minutes) minutes"
    }

    /// 設定列上顯示的文字。
    static func rowLabel(_ minutes: Int) -> String {
        wheelLabel(minutes)
    }
}
