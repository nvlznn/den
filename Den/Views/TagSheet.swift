import SwiftData
import SwiftUI

/// 選擇專注標籤。點一下選取並關閉；可以新增、重新命名、刪除、排序。
struct TagSheet: View {
    /// 目前選的標籤 `FocusTag.id`，空字串代表沒有。
    @Binding var selectedTagID: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FocusTag.order) private var tags: [FocusTag]

    @State private var isAdding = false
    @State private var renaming: FocusTag?
    @State private var nameDraft = ""

    var body: some View {
        NavigationStack {
            List {
                if !tags.isEmpty {
                    Section {
                        ForEach(tags) { tag in
                            row(for: tag)
                        }
                        .onDelete { offsets in
                            offsets.map { tags[$0] }.forEach(delete)
                        }
                        .onMove(perform: move)
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
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
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
                if tag.id.uuidString == selectedTagID {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                }
            }
        }
        .accessibilityAddTraits(tag.id.uuidString == selectedTagID ? .isSelected : [])
        .swipeActions {
            Button(role: .destructive) {
                delete(tag)
            } label: {
                Label("Delete", systemImage: "trash")
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
    }

    private func rename(_ tag: FocusTag) {
        guard !trimmedDraft.isEmpty else { return }
        tag.name = trimmedDraft
        try? modelContext.save()
    }

    /// 刪掉標籤時，用過它的紀錄保留，只是變成沒有標籤。
    private func delete(_ tag: FocusTag) {
        if tag.id.uuidString == selectedTagID {
            selectedTagID = ""
        }
        modelContext.delete(tag)
        try? modelContext.save()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = tags
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, tag) in reordered.enumerated() {
            tag.order = index
        }
        try? modelContext.save()
    }
}
