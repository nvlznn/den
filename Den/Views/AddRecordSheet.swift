import SwiftData
import SwiftUI

/// 手動補一筆紀錄，例如忘了開計時。
struct AddRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FocusTag.order) private var tags: [FocusTag]

    @AppStorage("selectedTagID") private var selectedTagID = ""

    @State private var tagID: UUID?
    @State private var startedAt = Self.defaultStart
    @State private var minutes = 25

    var body: some View {
        NavigationStack {
            Form {
                Picker("標籤", selection: $tagID) {
                    Text("無").tag(UUID?.none)
                    ForEach(tags) { tag in
                        Text(tag.name).tag(Optional(tag.id))
                    }
                }

                DatePicker("開始時間", selection: $startedAt, in: ...Date.now)

                Section("時長") {
                    HourMinuteWheel(totalMinutes: $minutes, range: 1...720)
                }
            }
            .navigationTitle("新增紀錄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCloseButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    SheetConfirmButton(action: save)
                }
            }
            .onAppear {
                tagID = UUID(uuidString: selectedTagID)
            }
        }
    }

    private func save() {
        let tag = tags.first { $0.id == tagID }
        modelContext.insert(FocusSession(
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(TimeInterval(minutes * 60)),
            tag: tag
        ))
        try? modelContext.save()
        dismiss()
    }

    /// 預設是 25 分鐘前、對齊到整分。
    private static var defaultStart: Date {
        let date = Date.now.addingTimeInterval(-25 * 60)
        return Calendar.current.dateInterval(of: .minute, for: date)?.start ?? date
    }
}
