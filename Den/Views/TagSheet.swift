import SwiftData
import SwiftUI

/// 選擇專注標籤。點一下選取並關閉；可以新增、重新命名、刪除。
///
/// 至少要留一個標籤：只剩一個時不能刪。刪掉標籤時，它的紀錄保留原本的標籤名稱。
struct TagSheet: View {
    /// 目前選的標籤 `FocusTag.id`；空字串或找不到時，視為選第一個標籤。
    @Binding var selectedTagID: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FocusTag.order) private var tags: [FocusTag]

    @State private var isAdding = false
    @State private var renaming: FocusTag?
    @State private var nameDraft = ""

    /// 實際生效的選擇。
    private var effectiveSelectedID: UUID? {
        tags.first { $0.id.uuidString == selectedTagID }?.id ?? tags.first?.id
    }

    var body: some View {
        NavigationStack {
            List {
                if !tags.isEmpty {
                    Section {
                        ForEach(tags) { tag in
                            row(for: tag)
                        }
                    }
                }

                Section {
                    Button {
                        nameDraft = ""
                        isAdding = true
                    } label: {
                        Label("Add Tag", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Select Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCloseButton { dismiss() }
                }
            }
            .alert("Add Tag", isPresented: $isAdding) {
                TextField("Name", text: $nameDraft)
                Button("Cancel", role: .cancel) {}
                Button("Add", action: add)
            }
            .alert("Rename", isPresented: isRenaming, presenting: renaming) { tag in
                TextField("Name", text: $nameDraft)
                Button("Cancel", role: .cancel) {}
                Button("Save") { rename(tag) }
            }

        }
    }

    private func row(for tag: FocusTag) -> some View {
        Button {
            selectedTagID = tag.id.uuidString
            dismiss()
        } label: {
            HStack {
                Label {
                    // 用具體的 Color；`.primary` 在 List 的按鈕裡會被換成 tint 色。
                    Text(tag.name)
                        .foregroundStyle(Color.primary)
                } icon: {
                    Image(systemName: "tag.fill")
                        .foregroundStyle(.tint)
                }
                Spacer()
                if tag.id == effectiveSelectedID {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                }
            }
        }
        .accessibilityAddTraits(tag.id == effectiveSelectedID ? .isSelected : [])
        .swipeActions {
            // 至少要留一個標籤，只剩一個時不出現刪除。
            if tags.count > 1 {
                Button(role: .destructive) {
                    delete(tag)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            Button {
                nameDraft = tag.name
                renaming = tag
            } label: {
                Label("Rename", systemImage: "pencil")
            }
        }
    }

    private var isRenaming: Binding<Bool> {
        Binding {
            renaming != nil
        } set: { isPresented in
            if !isPresented { renaming = nil }
        }
    }

    private var trimmedDraft: String {
        nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func add() {
        guard !trimmedDraft.isEmpty else { return }
        let order = (tags.map(\.order).max() ?? -1) + 1
        modelContext.insert(FocusTag(name: trimmedDraft, order: order))
        try? modelContext.save()
        // 如果有標籤被刪掉的紀錄原本就叫這個名字，它們歸到新標籤底下。
        TagMaintenance.adoptOrphans(context: modelContext)
    }

    private func rename(_ tag: FocusTag) {
        guard !trimmedDraft.isEmpty else { return }
        tag.name = trimmedDraft
        for session in tag.sessions ?? [] {
            session.tagName = trimmedDraft
        }
        try? modelContext.save()
        TagMaintenance.adoptOrphans(context: modelContext)
    }

    private func delete(_ tag: FocusTag) {
        let wasSelected = effectiveSelectedID == tag.id
        guard let target = TagMaintenance.delete(tag, context: modelContext) else { return }
        if wasSelected || selectedTagID == tag.id.uuidString {
            selectedTagID = target.id.uuidString
        }
    }
}
