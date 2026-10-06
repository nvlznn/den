import SwiftData
import SwiftUI

/// 最外層：兩個分頁，加上不管在哪個分頁都要處理的計時事件。
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(FocusController.self) private var controller

    @AppStorage("selectedTagID") private var selectedTagID = ""
    @AppStorage("didSeedTags") private var didSeedTags = false

    var body: some View {
        @Bindable var controller = controller

        TabView {
            HomeView()
                .tabItem { Label("專注", systemImage: "hourglass") }
            RecordsView()
                .tabItem { Label("紀錄", systemImage: "book.closed") }
        }
        .sheet(item: $controller.sessionToConfirm) { session in
            EndSessionSheet(
                session: session,
                onSave: { controller.saveConfirmed($0, context: modelContext) },
                onDiscard: controller.discardStopwatch
            )
        }
        .task(id: controller.timer.active) {
            await controller.waitForCountdownEnd(context: modelContext)
        }
        .task {
            seedTagsIfNeeded()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                controller.sceneBecameActive(context: modelContext)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: controller.petTaps)
        .sensoryFeedback(.success, trigger: controller.celebrations)
        .sensoryFeedback(.start, trigger: controller.starts)
        .sensoryFeedback(.stop, trigger: controller.stops)
    }

    /// 第一次打開時放幾個預設標籤，之後使用者怎麼改都不再動。
    private func seedTagsIfNeeded() {
        guard !didSeedTags else { return }
        didSeedTags = true
        let existing = (try? modelContext.fetchCount(FetchDescriptor<FocusTag>())) ?? 0
        guard existing == 0 else { return }

        let tags = FocusTag.defaultNames.enumerated().map { FocusTag(name: $1, order: $0) }
        tags.forEach(modelContext.insert)
        try? modelContext.save()
        selectedTagID = tags.first?.id.uuidString ?? ""
    }
}

extension FinishedSession: Identifiable {
    var id: Date { startedAt }
}
