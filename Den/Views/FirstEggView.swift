import SwiftData
import SwiftUI

/// 第一次選蛋時白蛋的位置（全螢幕座標），等待畫面的蛋要飛到這裡。
struct FirstEggFrameKey: PreferenceKey {
    static let defaultValue: CGRect? = nil
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) { value = value ?? nextValue() }
}

struct FirstEggView: View {
    let library: CharacterLibrary
    @Binding var selectedCharacterID: String
    /// 預覽用的假資料不能同步到其他裝置。
    var syncsChoice = true
    /// 從等待畫面過來：白蛋等飛過來的蛋落地才出現，其他東西落地後再淡入。
    var introducesEgg = false
    var eggLanded = false
    @Environment(\.modelContext) private var modelContext
    @AppStorage("onboardingGuidePending") private var guidePending = false
    @State private var color: EggColor = .white
    @State private var saveError = false
    @State private var showsRest = false

    private var restOpacity: Double { !introducesEgg || showsRest ? 1 : 0 }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    Text("Choose your egg to begin your journey")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .padding(.top, 24)
                        .opacity(restOpacity)

                    Spacer(minLength: 32)

                    VStack(spacing: 24) {
                        EggColorPicker(collection: library.collection, selection: $color, thumbnailSize: 116,
                                       reportsWhiteEggFrame: introducesEgg,
                                       whiteEggOpacity: !introducesEgg || eggLanded ? 1 : 0,
                                       restOpacity: restOpacity)
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
                        .opacity(restOpacity)
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
        .onChange(of: eggLanded) { _, landed in
            if landed { withAnimation(.easeOut(duration: 0.35)) { showsRest = true } }
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
            if syncsChoice { SettingsSync.push(.characterID, id) }
            guidePending = true
        } catch {
            library.collection = previous
            saveError = true
        }
    }
}
