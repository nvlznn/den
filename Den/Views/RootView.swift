import CoreData
import SwiftData
import SwiftUI

/// 最外層：兩個分頁，加上不管在哪個分頁都要處理的計時事件。
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(FocusController.self) private var controller

    @AppStorage("selectedTagID") private var selectedTagID = ""

    var body: some View {
        @Bindable var controller = controller

        Group {
            if controller.timer.isRunning {
                // 專注中只留 LCD、進度條、數字、標籤和 End，不顯示 tab bar。
                HomeView()
            } else {
                TabView {
                    HomeView()
                        .tabItem { Label("Focus", systemImage: "hourglass") }
                    RecordsView()
                        .tabItem { Label("Records", systemImage: "book.closed") }
                    StatisticsView()
                        .tabItem { Label("Statistics", systemImage: "chart.pie") }
                }
            }
        }
        .animation(.default, value: controller.timer.isRunning)
        .fullScreenCover(item: $controller.celebration) { celebration in
            CelebrationView(celebration: celebration) {
                controller.celebration = nil
            }
        }
        .task {
            if let first = TagMaintenance.seedIfNeeded(context: modelContext) {
                selectedTagID = first.id.uuidString
            }
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
