import Foundation
import WidgetKit

/// 跨裝置（iPhone、iPad、Mac）共用的設定：角色、標籤、時長、換日時間。
///
/// 放在 iCloud 的 key-value 存放區，本機的值照舊在 UserDefaults，`@AppStorage` 讀那裡。
/// 只有使用者自己選的時候才 `push`；app 自動修正的值（例如角色還沒同步過來先暫時用第一隻）
/// 不上傳，才不會蓋掉另一台的選擇。所以雲端的值永遠是「最後一次真的選的」。
@MainActor
enum SettingsSync {
    enum Key: String, CaseIterable {
        case characterID
        case selectedTagID
        case focusMinutes
        case dayStartHour

        /// 換日時間放 App Group，Widget 才讀得到。
        var store: UserDefaults {
            self == .dayStartHour ? DayBoundary.store : .standard
        }
    }

    private static var cloud: NSUbiquitousKeyValueStore { .default }
    private static var observer: NSObjectProtocol?

    /// 啟動時呼叫一次：先拉雲端的值，之後雲端有變就跟著變。
    static func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { pull() }
        }
        cloud.synchronize()
        pull()
    }

    /// 使用者在這台選了新的值。直接傳值進來，不從 UserDefaults 讀：
    /// 透過 `@Binding` 改 `@AppStorage` 時，當下讀 UserDefaults 可能還是舊值。
    static func push(_ key: Key, _ value: Any) {
        guard !(cloud.object(forKey: key.rawValue) as AnyObject).isEqual(value) else { return }
        cloud.set(value, forKey: key.rawValue)
        cloud.synchronize()
    }

    /// 雲端上最後一次選的值。
    static func cloudString(_ key: Key) -> String? {
        cloud.string(forKey: key.rawValue)
    }

    private static func pull() {
        var dayChanged = false
        for key in Key.allCases {
            guard let value = cloud.object(forKey: key.rawValue) else { continue }
            let local = key.store.object(forKey: key.rawValue)
            guard !(local as AnyObject).isEqual(value) else { continue }
            if key == .dayStartHour {
                guard let hour = value as? Int else { continue }
                key.store.set(DayBoundary(hour: hour).hour, forKey: key.rawValue)
                dayChanged = true
            } else {
                key.store.set(value, forKey: key.rawValue)
            }
        }
        if dayChanged { WidgetCenter.shared.reloadAllTimelines() }
    }
}
