import SwiftData
import SwiftUI

struct FirstEggView: View {
    let library: CharacterLibrary
    @Binding var selectedCharacterID: String
    @Environment(\.modelContext) private var modelContext
    @State private var color: EggColor = .white
    @State private var saveError = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Text("Choose Your Egg")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                EggColorPicker(collection: library.collection, selection: $color)
                Text("Hatches at Lv 1 · 10 hr")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Start") { choose() }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.extraLarge)
                    .disabled(library.collection.remainingCount(of: color) == 0)
                Text("2 free eggs")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
            .padding(.top, 48)
        }
        .onAppear {
            if library.collection.remainingCount(of: color) == 0 {
                color = EggColor.allCases.first { library.collection.remainingCount(of: $0) > 0 } ?? .white
            }
        }
        .alert("Unable to Save", isPresented: $saveError) {
            Button("OK", role: .cancel) {}
        } message: { Text("Please try again.") }
    }

    private func choose() {
        let previous = library.collection
        var collection = previous
        guard let id = collection.claimFreeEgg(color: color) else { return }
        library.collection = collection
        do {
            try modelContext.save()
            selectedCharacterID = id
        } catch {
            library.collection = previous
            saveError = true
        }
    }
}
