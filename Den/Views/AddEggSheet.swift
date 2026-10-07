import SwiftData
import SwiftUI

struct AddEggSheet: View {
    let library: CharacterLibrary
    @Binding var selectedCharacterID: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(EggStore.self) private var store
    @Query private var purchases: [EggPurchase]
    @State private var color: EggColor = .white
    @State private var saveError = false

    private var collection: CharacterCollection { library.collection }
    private var reservedIDs: Set<String> { EggPurchase.reservedIDs(in: purchases) }
    private func hasRoom(for color: EggColor) -> Bool {
        collection.order.contains { color.characterIDs.contains($0) && !collection.ownedIDs.contains($0) && !reservedIDs.contains($0) }
    }
    private var canAdd: Bool {
        !store.isBusy && hasRoom(for: color) &&
        (collection.canClaimFreeEgg || store.product != nil)
    }
    private var buttonTitle: String {
        if collection.canClaimFreeEgg { return "Add · Free" }
        if let product = store.product { return "Buy · \(product.displayPrice)" }
        return store.isLoading ? "Loading…" : "Unavailable"
    }

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    EggColorPicker(collection: collection, selection: $color, reservedIDs: reservedIDs)
                        .disabled(store.isBusy)
                    Text("Hatch a new friend!")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button { Task { await add() } } label: {
                        HStack {
                            if store.isBusy { ProgressView() }
                            Text(buttonTitle).fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .disabled(!canAdd)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }

            .navigationTitle("New Egg")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCloseButton { dismiss() }.disabled(store.isBusy) }
            }
            .task { await store.load(context: modelContext) }
            .onChange(of: collection.ownedIDs + reservedIDs.sorted(), initial: true) { _, _ in
                if collection.isFull { dismiss() }
                if !hasRoom(for: color) {
                    color = EggColor.allCases.first { hasRoom(for: $0) } ?? color
                }
            }
            .alert("Store", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
                Button("OK") { store.message = nil }
            } message: { Text(store.message ?? "") }
            .alert("Couldn’t Save", isPresented: $saveError) {
                Button("OK", role: .cancel) {}
            } message: { Text("Please try again.") }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(store.isBusy)
    }

    private func add() async {
        if collection.canClaimFreeEgg {
            let previous = collection
            var updated = previous
            guard let id = updated.claimFreeEgg(color: color) else { return }
            library.collection = updated
            do {
                try modelContext.save()
                selectedCharacterID = id
                dismiss()
            } catch {
                library.collection = previous
                saveError = true
            }
        } else {
            if let id = await store.purchase(color: color, library: library, context: modelContext) {
                selectedCharacterID = id
                dismiss()
            }
        }
    }
}
