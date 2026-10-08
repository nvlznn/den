import SwiftData
import SwiftUI

struct CharacterSheet: View {
    @Binding var characterID: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [FocusSession]
    @Query(sort: [SortDescriptor(\CharacterLibrary.createdAt), SortDescriptor(\CharacterLibrary.id)]) private var libraries: [CharacterLibrary]
    @State private var isAddingEgg = false
    @State private var renamingID: String?
    @State private var newName = ""

    private var library: CharacterLibrary? { libraries.first }

    private var totals: [String: TimeInterval] {
        CharacterRanking.totals(in: sessions, characterOf: \.characterID,
                                isManual: \.isManual, duration: \.duration)
    }

    var body: some View {
        NavigationStack {
            List {
                if let library {
                    let collection = library.collection
                    let totals = totals
                    Section {
                        ForEach(CharacterRanking.sorted(collection.ownedIDs, totals: totals), id: \.self) { id in
                            row(id: id, collection: collection, seconds: totals[id, default: 0])
                        }
                    }
                    if !collection.isFull {
                        Section {
                            Button { isAddingEgg = true } label: {
                                Label("Add New Egg", systemImage: "plus.circle.fill")
                            }
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Characters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCloseButton { dismiss() } }
            }
            .alert("Rename", isPresented: Binding(get: { renamingID != nil }, set: { if !$0 { renamingID = nil } })) {
                TextField(PetSprites.character(id: renamingID).name, text: $newName)
                    .onChange(of: newName) { _, value in
                        if value.count > CharacterCollection.maxNameLength {
                            newName = String(value.prefix(CharacterCollection.maxNameLength))
                        }
                    }
                Button("Cancel", role: .cancel) {}
                Button("Save") { saveName() }
            }
            .sheet(isPresented: $isAddingEgg) {
                if let library {
                    AddEggSheet(library: library, selectedCharacterID: $characterID)
                }
            }
        }
    }

    private func row(id: String, collection: CharacterCollection, seconds: TimeInterval) -> some View {
        let character = PetSprites.character(id: collection.displayID(for: id))
        let level = Level(totalSeconds: seconds)
        let isSelected = id == characterID
        return Button {
            characterID = id
            dismiss()
        } label: {
            HStack(spacing: 14) {
                CharacterThumbnail(character: character).frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.name(for: id)).foregroundStyle(Color.primary)
                    Text("Lv \(level.number) · \(DurationText.hoursAndMinutes(level.totalSeconds))")
                        .font(.subheadline).foregroundStyle(Color.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(.tint)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        // 還是蛋的時候不能取名字，孵化後才知道是誰。
        .swipeActions(edge: .trailing) {
            if collection.revealed.contains(id) {
                Button {
                    newName = collection.name(for: id)
                    renamingID = id
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .tint(.orange)
            }
        }
    }

    private func saveName() {
        guard let renamingID, let library else { return }
        var collection = library.collection
        collection.rename(renamingID, to: newName)
        library.collection = collection
        try? modelContext.save()
    }
}

struct CharacterThumbnail: View {
    let character: PetCharacter
    var body: some View {
        PixelSprite(pixels: character.idle)
            .fill(LCDPalette.pixelOn)
            .padding(8)
            .background(LCDPalette.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }
}
