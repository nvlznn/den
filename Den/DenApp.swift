import SwiftData
import SwiftUI

@main
struct DenApp: App {
    /// 跟之後的 iPad、Mac、Apple Watch 版共用同一個容器，紀錄才會跨裝置。
    static let cloudContainerID = "iCloud.dev.noky.den"

    @State private var controller = FocusController(timer: FocusTimer())
    @State private var cloudSync: CloudSyncMonitor

    private let modelContainer: ModelContainer

    init() {
        CountdownNotifier.shared.becomeDelegate()
        let (container, usesCloud) = Self.makeModelContainer()
        modelContainer = container
        _cloudSync = State(initialValue: CloudSyncMonitor(usesCloud: usesCloud, containerID: Self.cloudContainerID))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(controller)
                .environment(cloudSync)
        }
        .modelContainer(modelContainer)
    }

    /// 紀錄存在 iCloud 的私人資料庫：刪掉 app 再裝回來、換一台裝置，紀錄都還在。
    /// 沒登入 iCloud 時照樣存在本機，登入後自動上傳。
    /// 回傳的 `usesCloud` 表示這次是不是真的接上了 iCloud。
    private static func makeModelContainer() -> (ModelContainer, usesCloud: Bool) {
        let schema = Schema([FocusSession.self, FocusTag.self])
        let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .private(cloudContainerID))
        if let container = try? ModelContainer(for: schema, configurations: cloud) {
            return (container, true)
        }
        // iCloud 設定有問題時（例如簽署沒有 iCloud 權限），至少讓 app 能用本機資料打開。
        let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return (try ModelContainer(for: schema, configurations: local), false)
        } catch {
            fatalError("無法建立資料庫：\(error)")
        }
    }
}
