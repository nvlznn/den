import SwiftData
import SwiftUI

struct FirstEggView: View {
    let library: CharacterLibrary
    @Binding var selectedCharacterID: String
    @Environment(\.modelContext) private var modelContext
    @AppStorage("onboardingGuidePending") private var guidePending = false
    @State private var color: EggColor = .white
    @State private var saveError = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    Text("Choose your egg to begin your journey")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .padding(.top, 24)

                    Spacer(minLength: 32)

                    VStack(spacing: 24) {
                        EggColorPicker(collection: library.collection, selection: $color, thumbnailSize: 116)
                    }

                    Spacer(minLength: 32)

                    Button(action: choose) {
                        Text("Let’s go!")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.extraLarge)
                        .disabled(library.collection.remainingCount(of: color) == 0)
                }
                .padding(24)
                .frame(minHeight: geometry.size.height)
            }
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
            guidePending = true
        } catch {
            library.collection = previous
            saveError = true
        }
    }
}
