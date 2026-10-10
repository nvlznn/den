import Foundation
import WidgetKit

/// 把「換日時間」放在 iCloud 的 key-value 存放區，每台裝置才會用同一個時間分天。
/// 本機的值放在 App Group（`DayBoundary.store`），Widget 和 `@AppStorage` 都讀那裡。
@MainActor
enum DayBoundarySync {
    private static var cloud: NSUbiquitousKeyValueStore { .default }
    private static var observer: NSObjectProtocol?

    /// 啟動時呼叫一次：先拉雲端的值，之後雲端有變就跟著變。
    static func start() {
        guard observer == nil else { return }
        pull()
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { pull() }
        }
        cloud.synchronize()
    }

    /// 使用者在這台改了時間。
    static func push(_ hour: Int) {
        cloud.set(Int64(hour), forKey: DayBoundary.key)
        cloud.synchronize()
    }

    private static func pull() {
        guard let value = cloud.object(forKey: DayBoundary.key) as? Int64 else { return }
        let hour = DayBoundary(hour: Int(value)).hour
        guard DayBoundary.store.object(forKey: DayBoundary.key) as? Int != hour else { return }
        DayBoundary.store.set(hour, forKey: DayBoundary.key)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
