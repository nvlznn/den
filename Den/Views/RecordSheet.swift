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
                // 每筆紀錄一定要有標籤，所以沒有「None」。
                Picker("Tag", selection: $tagID) {
                    // 標籤已經被刪掉的紀錄：保留原本的名稱當作一個選項，沒改的話就維持原樣。
                    if let orphanName {
                        Text(orphanName).tag(UUID?.none)
                    }
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
                // 新增：預設用目前選的標籤。編輯：用紀錄原本的標籤；它的標籤已被刪掉就維持原名，不改成別的。
                guard orphanName == nil else { return }
                let preferred = editing == nil ? UUID(uuidString: selectedTagID) : tagID
                tagID = tags.first { $0.id == preferred }?.id ?? tags.first?.id
            }
        }
    }

    /// 編輯的紀錄如果標籤已被刪掉，它顯示的原本名稱；否則 nil。
    private var orphanName: String? {
        guard let editing, editing.tag == nil else { return nil }
        return editing.displayTagName
    }

    private func save() {
        // 孤兒紀錄且沒換標籤：維持原本的標籤名稱，不指定新的標籤。
        let keepsDeletedTag = orphanName != nil && tagID == nil
        let tag = tags.first { $0.id == tagID } ?? TagMaintenance.fallbackTag(context: modelContext)

        if let editing {
            let originalMinutes = Int((editing.duration / 60).rounded())
            let duration = minutes == min(max(originalMinutes, Self.minuteRange.lowerBound), Self.minuteRange.upperBound)
                ? editing.duration
                : TimeInterval(minutes * 60)
            if !keepsDeletedTag {
                editing.tag = tag
                editing.tagName = tag.name
            }
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
