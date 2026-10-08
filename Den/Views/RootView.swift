import CoreData
import SwiftData
import SwiftUI

/// 最外層：兩個分頁，加上不管在哪個分頁都要處理的計時事件。
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(FocusController.self) private var controller
    @Environment(CloudSyncMonitor.self) private var cloudSync

    @Environment(EggStore.self) private var store
    @Environment(CommunityFocusStore.self) private var community
    @Query private var sessions: [FocusSession]
    @Query private var purchases: [EggPurchase]
    @Query(sort: [SortDescriptor(\CharacterLibrary.createdAt), SortDescriptor(\CharacterLibrary.id)]) private var libraries: [CharacterLibrary]
    @AppStorage("characterID") private var characterID = PetSprites.defaultCharacterID
    @State private var libraryError: String?
    @State private var selectedTab = 0
    @AppStorage("onboardingGuidePending") private var guidePending = false

    @AppStorage("selectedTagID") private var selectedTagID = ""

    var body: some View {
        @Bindable var controller = controller

        Group {
            if let library = libraries.first, library.collection.needsFirstEgg {
                FirstEggView(library: library, selectedCharacterID: $characterID)
            } else if controller.timer.isRunning {
                // 專注中只留 LCD、進度條、數字、標籤和 End，不顯示 tab bar。
                HomeView()
            } else {
                TabView(selection: $selectedTab) {
                    HomeView()
                        .tabItem { Label("Focus", systemImage: "hourglass") }.tag(0)
                    RecordsView()
                        .tabItem { Label("Records", systemImage: "book.closed") }.tag(1)
                    StatisticsView()
                        .tabItem { Label("Statistics", systemImage: "chart.pie") }.tag(2)
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape") }.tag(3)
                }
            }
        }
        .animation(.default, value: controller.timer.isRunning)
        .sheet(isPresented: $guidePending) {
            OnboardingGuideView(eggColor: EggColor.of(characterID: characterID) ?? .white) {
                guidePending = false
            }
        }
        .syncsWidgets()
        .task { await store.load(context: modelContext) }
        .task(id: libraryInput) {
            guard cloudSync.isReady || !libraries.isEmpty else { return }
            do {
                let library = try CharacterLibrary.prepare(in: modelContext)
                var collection = library.collection
                collection.paidEggs.formUnion(store.legacyEggs)
                library.collection = collection
                try library.reconcile(purchases: purchases, context: modelContext)
                try library.reconcile(sessions: sessions, context: modelContext)
                if !collection.ownedIDs.contains(characterID), let first = collection.ownedIDs.first {
                    characterID = first
                }
                for session in sessions { FocusContribution.capture(session, context: modelContext) }
                try modelContext.save()
            } catch { libraryError = String(localized: "Your progress could not be saved. Please reopen Den and try again.") }
        }
        .task(id: purchaseInput) {
            guard cloudSync.isReady || !libraries.isEmpty else { return }
            await store.retryUnfinished(context: modelContext)
        }
        .task(id: contributionInput) {
            guard cloudSync.isReady, scenePhase == .active, selectedTab != 3 || controller.timer.isRunning else { return }
            // Debounce edits/sync bursts; no request every timer tick.
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            await community.refresh(context: modelContext)
        }
        .alert("Unable to Save", isPresented: Binding(get: { libraryError != nil }, set: { if !$0 { libraryError = nil } })) {
            Button("OK") { libraryError = nil }
        } message: { Text(libraryError ?? "") }
        .fullScreenCover(item: $controller.celebration) { celebration in
            CelebrationView(celebration: celebration) { name in
                controller.finishCelebration(naming: name, context: modelContext)
            }
        }
        #if DEBUG
        // 模擬器看慶祝畫面用：啟動參數 `-demoCelebration hatch` 或 `-demoCelebration levelUp`。
        .task {
            switch UserDefaults.standard.string(forKey: "demoCelebration") {
            case "hatch":
                controller.celebration = Celebration(characterID: "mochi", duration: 1800, levelBefore: 0, levelAfter: 1, characterName: "Mochi", didHatch: true)
            case "levelUp":
                controller.celebration = Celebration(characterID: "fangfang", duration: 2700, levelBefore: 2, levelAfter: 3, characterName: "Boxy")
            default:
                break
            }
        }
        #endif
        // 等 iCloud 第一次下載完（或沒有 iCloud）才判斷要不要建預設標籤，重新安裝時才不會多一組。
        .onChange(of: cloudSync.isReady, initial: true) { _, isReady in
            guard isReady else { return }
            if let first = TagMaintenance.seedIfEmpty(context: modelContext) {
                selectedTagID = first.id.uuidString
            }
            mergeDuplicateTags()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                controller.sceneBecameActive()
                mergeDuplicateTags()
            }
        }
        // iCloud 同步進來新資料時
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: RunLoop.main)) { _ in
            mergeDuplicateTags()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: controller.petTaps)
        .sensoryFeedback(.success, trigger: controller.celebrations)
        .sensoryFeedback(.start, trigger: controller.starts)
        .sensoryFeedback(.stop, trigger: controller.stops)
        .sensoryFeedback(.impact(weight: .medium), trigger: controller.pauseToggles)
    }

    private var libraryInput: [String] {
        [String(cloudSync.isReady), store.legacyEggs.map(\.id).sorted().description] + purchaseInput
            + libraries.map { $0.payload.base64EncodedString() }
            + sessions.map { "\($0.characterID ?? ""):\($0.duration):\($0.isManual)" }
    }

    private var purchaseInput: [String] {
        [String(cloudSync.isReady), String(describing: scenePhase)] + libraries.map { $0.id.uuidString }
            + purchases.map { "\($0.id):\($0.transactionID):\($0.state):\($0.revoked)" }.sorted()
    }

    private var contributionInput: [String] {
        [String(cloudSync.isReady), String(describing: scenePhase), String(selectedTab), String(controller.timer.isRunning)] + sessions.compactMap(\.contributionKey).sorted()
    }

    /// 同名標籤合併後，如果目前選的是被合併掉的那個，改選留下來的。
    private func mergeDuplicateTags() {
        let replaced = TagMaintenance.mergeDuplicates(context: modelContext)
        TagMaintenance.adoptOrphans(context: modelContext)
        if let current = UUID(uuidString: selectedTagID), let keeper = replaced[current] {
            selectedTagID = keeper.uuidString
        }
    }
}
