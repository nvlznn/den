import CoreData
import StoreKit
import SwiftData
import SwiftUI

/// 最外層：兩個分頁，加上不管在哪個分頁都要處理的計時事件。
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @Environment(FocusController.self) private var controller
    @Environment(CloudSyncMonitor.self) private var cloudSync

    @Environment(EggStore.self) private var store
    @Environment(CommunityFocusStore.self) private var community
    @Query private var sessions: [FocusSession]
    @Query private var purchases: [EggPurchase]
    @Query(sort: [SortDescriptor(\CharacterLibrary.createdAt), SortDescriptor(\CharacterLibrary.id)]) private var libraries: [CharacterLibrary]
    @AppStorage("characterID") private var characterID = PetSprites.defaultCharacterID
    @State private var libraryError: String?
    @State private var showsSharedLevelNotice = false
    // 第一次打開、等 iCloud 的等待畫面（見 `showsEggWaiting`）。
    @State private var eggWaitShown = false
    @State private var eggWaitMinimumPassed = false
    @State private var eggWaitGaveUp = false
    @State private var eggPhase = EggWaitingView.Phase.waiting
    @State private var eggTarget: CGRect?
    @State private var eggWaitEnded = false
    @State private var selectedTab = 0
    @AppStorage("onboardingGuidePending") private var guidePending = false

    @AppStorage("selectedTagID") private var selectedTagID = ""

    var body: some View {
        @Bindable var controller = controller

        // 等待畫面疊在最上面；下面先排好選蛋頁，蛋才知道要飛去哪裡。
        ZStack {
            Group {
                if libraries.isEmpty {
                    Color.clear
                } else if let library = libraries.first, library.collection.needsFirstEgg {
                    FirstEggView(library: library, selectedCharacterID: $characterID,
                                 introducesEgg: eggWaitShown, eggLanded: eggWaitEnded)
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

            if showsEggWaiting {
                EggWaitingView(phase: eggPhase, target: eggTarget)
                    .task {
                        eggWaitShown = true
                        do { try await Task.sleep(for: .seconds(Self.eggWaitMinimum)) } catch { return }
                        eggWaitMinimumPassed = true
                        do { try await Task.sleep(for: .seconds(Self.eggWaitLimit - Self.eggWaitMinimum)) } catch { return }
                        eggWaitGaveUp = true
                    }
            }
        }
        .onPreferenceChange(FirstEggFrameKey.self) { eggTarget = $0 }
        // 等待畫面至少放 1 秒；資料好了之後蛋先停下來，再飛進選蛋頁白蛋的位置（老使用者就淡出到主頁）。
        // 落地的那一刻才換成選蛋頁自己的白蛋，兩個長得一模一樣，看起來是同一顆。
        .task(id: canLeaveEggWaiting) {
            guard canLeaveEggWaiting else { return }
            eggPhase = .settled
            do { try await Task.sleep(for: .seconds(0.3)) } catch { return }
            withAnimation(.spring(duration: 0.6, bounce: 0.15)) { eggPhase = .flying }
            do { try await Task.sleep(for: .seconds(0.45)) } catch { return }
            eggWaitEnded = true
        }
        .fullScreenCover(isPresented: $guidePending) {
            OnboardingGuideView(eggColor: EggColor.of(characterID: characterID) ?? .white) {
                guidePending = false
                controller.askForReview(after: .welcome)
            }
        }
        .syncsWidgets()
        .task { await store.load(context: modelContext) }
        .task(id: libraryInput) {
            // 等 iCloud 第一次下載完，重新安裝時才不會多建一份；等太久（例如沒網路）就當成新使用者。
            guard cloudSync.isReady || !libraries.isEmpty || eggWaitGaveUp else { return }
            do {
                let library = try CharacterLibrary.prepare(in: modelContext)
                var collection = library.collection
                collection.paidEggs.formUnion(store.legacyEggs)
                library.collection = collection
                try library.reconcile(purchases: purchases, context: modelContext)
                // 別台選的角色可能比角色資料先同步過來：資料到了就換成雲端選的那隻；
                // 還沒到就先暫時用第一隻（不上傳，才不會蓋掉別台的選擇）。
                if let synced = SettingsSync.cloudString(.characterID), synced != characterID,
                   collection.ownedIDs.contains(synced) {
                    characterID = synced
                } else if !collection.ownedIDs.contains(characterID), let first = collection.ownedIDs.first {
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
        // 等慶祝畫面收完再問，太早會被正在關的畫面擋掉。
        .task(id: controller.pendingReview) {
            guard let moment = controller.pendingReview else { return }
            do { try await Task.sleep(for: .seconds(0.8)) } catch { return }
            requestReview()
            moment.markAsked()
            controller.pendingReview = nil
        }
        .alert("Unable to Save", isPresented: Binding(get: { libraryError != nil }, set: { if !$0 { libraryError = nil } })) {
            Button("OK") { libraryError = nil }
        } message: { Text(libraryError ?? "") }
        .alert("Levels Are Now Shared", isPresented: $showsSharedLevelNotice) {
            Button("OK") {}
        }
        // 等導覽、慶祝畫面都關掉才判斷，只判斷一次。
        .onChange(of: canCheckSharedLevelNotice, initial: true) { _, canCheck in
            guard canCheck else { return }
            SharedLevelNotice.markDone()
            showsSharedLevelNotice = SharedLevelNotice.levelChanged(totals: CharacterRanking.totals(
                in: sessions, characterOf: \.characterID, isManual: \.isManual, duration: \.duration))
        }
        .fullScreenCover(item: $controller.celebration) { celebration in
            CelebrationView(celebration: celebration) { name in
                controller.finishCelebration(naming: name, context: modelContext)
            }
        }
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

    private static let eggWaitMinimum: TimeInterval = 1
    private static let eggWaitLimit: TimeInterval = 10

    /// 還沒有角色資料（第一次打開，在等 iCloud）；或等待畫面已經出現、還沒播完離開的動畫。
    /// 已經在用的人打開時資料就在了，不會看到。
    private var showsEggWaiting: Bool {
        libraries.isEmpty || (eggWaitShown && !eggWaitEnded)
    }

    private var canLeaveEggWaiting: Bool {
        eggWaitMinimumPassed && !libraries.isEmpty
    }

    private var libraryInput: [String] {
        [String(cloudSync.isReady), String(eggWaitGaveUp), store.legacyEggs.map(\.id).sorted().description] + purchaseInput
            + libraries.map { $0.payload.base64EncodedString() }
            + sessions.map { "\($0.characterID ?? ""):\($0.duration):\($0.isManual)" }
    }

    private var canCheckSharedLevelNotice: Bool {
        SharedLevelNotice.isPending() && !libraries.isEmpty && !guidePending && controller.celebration == nil
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
