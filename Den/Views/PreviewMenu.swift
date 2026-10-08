#if DEBUG
import SwiftData
import SwiftUI

/// 只在 Debug build 出現：直接播各種畫面，資料都是記憶體裡的假資料，關掉就消失，不動到真的進度。
/// 只給開發看，所以文字都不翻譯。
struct PreviewMenu: View {
    private enum Scenario: String, Identifiable, CaseIterable {
        case firstLaunch = "First Launch"
        case hatch = "Hatch"
        case levelUp = "Level Up"
        case sessionDone = "Session Done"
        case focusLevelUp = "Level Up While Focusing"

        var id: Self { self }
    }

    @State private var scenario: Scenario?

    var body: some View {
        List(Scenario.allCases) { scenario in
            Button(scenario.rawValue) { self.scenario = scenario }
        }
        .navigationTitle(Text(verbatim: "Preview"))
        .fullScreenCover(item: $scenario) { scenario in
            content(scenario)
        }
    }

    @ViewBuilder
    private func content(_ scenario: Scenario) -> some View {
        let close = { self.scenario = nil }
        switch scenario {
        case .firstLaunch:
            FirstLaunchPreview(onClose: close)
        case .hatch:
            CelebrationView(celebration: Celebration(characterID: "mochi", duration: 1800, levelBefore: 0, levelAfter: 1, characterName: "Mochi", didHatch: true)) { _ in close() }
        case .levelUp:
            CelebrationView(celebration: Celebration(characterID: "fangfang", duration: 2700, levelBefore: 2, levelAfter: 3, characterName: "Boxy")) { _ in close() }
        case .sessionDone:
            CelebrationView(celebration: Celebration(characterID: "fangfang", duration: 1500, levelBefore: 3, levelAfter: 3, characterName: "Boxy")) { _ in close() }
        case .focusLevelUp:
            FocusLevelUpPreview(onClose: close)
        }
    }
}

/// 一個全新使用者：空的角色庫、空的 UserDefaults。
@MainActor
private final class Sandbox {
    private static let suiteName = "dev.noky.den.preview"

    let container: ModelContainer
    let defaults: UserDefaults
    let library: CharacterLibrary

    init() {
        let schema = Schema([FocusSession.self, FocusTag.self, CharacterLibrary.self, FocusContribution.self, EggPurchase.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("無法建立預覽用的資料庫：\(error)")
        }
        library = CharacterLibrary(collection: CharacterCollection(shuffledIDs: PetSprites.characters.map(\.id).shuffled()))
        container.mainContext.insert(library)
        defaults = UserDefaults(suiteName: Self.suiteName) ?? .standard
        defaults.removePersistentDomain(forName: Self.suiteName)
    }
}

/// 選第一顆蛋 → 新手導覽，跟真的第一次打開一樣。
private struct FirstLaunchPreview: View {
    let onClose: () -> Void
    /// 畫面出現時才建一次；放在 `@State` 的預設值會在每次重畫時重建、把進度清掉。
    @State private var sandbox: Sandbox?

    var body: some View {
        if let sandbox {
            FirstLaunchFlow(library: sandbox.library, onClose: onClose)
                .modelContainer(sandbox.container)
                .defaultAppStorage(sandbox.defaults)
        } else {
            Color(.systemBackground)
                .onAppear { sandbox = Sandbox() }
        }
    }
}

private struct FirstLaunchFlow: View {
    let library: CharacterLibrary
    let onClose: () -> Void
    @AppStorage("onboardingGuidePending") private var guidePending = false
    @AppStorage("characterID") private var characterID = PetSprites.defaultCharacterID

    var body: some View {
        FirstEggView(library: library, selectedCharacterID: $characterID)
            .overlay(alignment: .topTrailing) { CloseButton(action: onClose) }
            .sheet(isPresented: $guidePending) {
                OnboardingGuideView(eggColor: EggColor.of(characterID: characterID) ?? .white) {
                    guidePending = false
                    onClose()
                }
            }
    }
}

/// 專注中跨過一級時 LCD 的煙火。點 LCD 重播。
private struct FocusLevelUpPreview: View {
    let onClose: () -> Void
    @State private var since = Date.now

    var body: some View {
        VStack {
            LCDScreenView(
                character: PetSprites.character(id: "fangfang"),
                level: 3,
                pet: PetState(isTiming: true),
                levelUpSince: since,
                onPetTap: { since = .now }
            )
            .aspectRatio(1, contentMode: .fit)
            Spacer()
        }
        .padding()
        .overlay(alignment: .bottom) { CloseButton(action: onClose) }
    }
}

private struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.headline)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .padding()
        .accessibilityLabel(Text(verbatim: "Close"))
    }
}
#endif
