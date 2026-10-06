import SwiftData
import SwiftUI

/// 新增或編輯一筆紀錄。
///
/// - 新增（`editing == nil`）：手動補的，例如忘了開計時。會出現在紀錄裡，但不算進任何角色的等級。
/// - 編輯：改標籤、開始時間、時長。時長沒動就保留原本精確到秒的長度。
struct RecordSheet: View {
    let editing: FocusSession?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FocusTag.order) private var tags: [FocusTag]

    @AppStorage("selectedTagID") private var selectedTagID = ""

    @State private var tagID: UUID?
    @State private var startedAt: Date
    @State private var minutes: Int

    private static let minuteRange = 1...720

    init(editing: FocusSession? = nil) {
        self.editing = editing
        if let editing {
            _tagID = State(initialValue: editing.tag?.id)
            _startedAt = State(initialValue: editing.startedAt)
            let rounded = Int((editing.duration / 60).rounded())
            _minutes = State(initialValue: min(max(rounded, Self.minuteRange.lowerBound), Self.minuteRange.upperBound))
        } else {
            _startedAt = State(initialValue: Self.defaultStart)
            _minutes = State(initialValue: 25)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Tag", selection: $tagID) {
                    Text("None").tag(UUID?.none)
                    ForEach(tags) { tag in
                        Text(tag.name).tag(Optional(tag.id))
                    }
                }

                DatePicker("Start", selection: $startedAt, in: ...Date.now)

                Section("Duration") {
                    HourMinuteWheel(totalMinutes: $minutes, range: Self.minuteRange)
                }

                if editing != nil {
                    Section {
                        Button("Delete Record", role: .destructive, action: delete)
                    }
                }
            }
            .navigationTitle(editing == nil ? "Add Record" : "Edit Record")
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
                if editing == nil {
                    tagID = UUID(uuidString: selectedTagID)
                }
            }
        }
    }

    private func save() {
        let tag = tags.first { $0.id == tagID }

        if let editing {
            let originalMinutes = Int((editing.duration / 60).rounded())
            let duration = minutes == min(max(originalMinutes, Self.minuteRange.lowerBound), Self.minuteRange.upperBound)
                ? editing.duration
                : TimeInterval(minutes * 60)
            editing.tag = tag
            editing.startedAt = startedAt
            editing.endedAt = startedAt.addingTimeInterval(duration)
        } else {
            modelContext.insert(FocusSession(
                startedAt: startedAt,
                endedAt: startedAt.addingTimeInterval(TimeInterval(minutes * 60)),
                tag: tag,
                isManual: true
            ))
        }
        try? modelContext.save()
        dismiss()
    }

    private func delete() {
        if let editing {
            modelContext.delete(editing)
            try? modelContext.save()
        }
        dismiss()
    }

    /// 預設是 25 分鐘前、對齊到整分。
    private static var defaultStart: Date {
        let date = Date.now.addingTimeInterval(-25 * 60)
        return Calendar.current.dateInterval(of: .minute, for: date)?.start ?? date
    }
}
