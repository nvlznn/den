import SwiftUI

/// 正計時結束時確認時長。時長只能往下調（忘記按結束、睡著了），不能往上調。
struct EndSessionSheet: View {
    let session: FinishedSession
    let onSave: (FinishedSession) -> Void
    let onDiscard: () -> Void

    @State private var minutes: Int

    init(session: FinishedSession, onSave: @escaping (FinishedSession) -> Void, onDiscard: @escaping () -> Void) {
        self.session = session
        self.onSave = onSave
        self.onDiscard = onDiscard
        _minutes = State(initialValue: Int(session.duration / 60))
    }

    private var maxMinutes: Int { Int(session.duration / 60) }

    /// 沒動過就保留原本精確到秒的結束時間。
    private var adjusted: FinishedSession {
        minutes == maxMinutes ? session : session.shortened(to: TimeInterval(minutes * 60))
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("這次專注了")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.top, 28)

            Text(DurationText.hoursAndMinutes(adjusted.duration))
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("如果忘了按結束，可以把時間調短。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HourMinuteWheel(totalMinutes: $minutes, range: 0...maxMinutes)

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Button {
                    onSave(adjusted)
                } label: {
                    Text("儲存")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    onDiscard()
                } label: {
                    Text("不儲存")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
            }
            .controlSize(.large)
        }
        .padding()
        .presentationDetents([.large])
        .interactiveDismissDisabled()
    }
}
