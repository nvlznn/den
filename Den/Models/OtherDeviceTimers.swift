import Foundation
import Observation
import UIKit

/// 其他裝置上正在進行的計時，給首頁顯示一行小字。
///
/// 每台裝置只寫自己那一個 key（`activeTimer.<裝置 ID>`），iCloud key-value 存放區是
/// 「每個 key 最後寫的贏」，各寫各的就不會互相蓋掉。同步可能慢幾秒到幾分鐘，所以只是提示。
@MainActor
@Observable
final class OtherDeviceTimers {
    struct Entry: Codable, Equatable, Sendable {
        /// 「iPhone」、「iPad」。iOS 不給 app 讀使用者取的裝置名稱。
        var model: String
        var startedAt: Date
    }

    static let keyPrefix = "activeTimer."
    /// 超過這麼久的就當作是殘留（例如計時中把 app 刪掉），不顯示。
    static let maxAge: TimeInterval = 24 * 3600
    private static let deviceIDKey = "deviceID"

    private(set) var entries: [String: Entry] = [:]

    @ObservationIgnored private let cloud: NSUbiquitousKeyValueStore
    @ObservationIgnored let deviceID: String
    @ObservationIgnored let model: String

    init(cloud: NSUbiquitousKeyValueStore = .default, defaults: UserDefaults = .standard) {
        self.cloud = cloud
        if let saved = defaults.string(forKey: Self.deviceIDKey) {
            deviceID = saved
        } else {
            deviceID = UUID().uuidString
            defaults.set(deviceID, forKey: Self.deviceIDKey)
        }
        model = UIDevice.current.model
        _ = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        cloud.synchronize()
        reload()
    }

    /// 把這台的計時狀態寫上去；結束了就刪掉。
    func publish(_ session: ActiveSession?) {
        let key = Self.keyPrefix + deviceID
        if let session {
            let entry = Entry(model: model, startedAt: session.startedAt)
            guard let data = try? JSONEncoder().encode(entry) else { return }
            cloud.set(data, forKey: key)
        } else {
            cloud.removeObject(forKey: key)
        }
        cloud.synchronize()
    }

    func reload() {
        var found: [String: Entry] = [:]
        for (key, value) in cloud.dictionaryRepresentation where key.hasPrefix(Self.keyPrefix) {
            guard let data = value as? Data, let entry = try? JSONDecoder().decode(Entry.self, from: data) else { continue }
            found[String(key.dropFirst(Self.keyPrefix.count))] = entry
        }
        if found != entries { entries = found }
    }

    /// 首頁要顯示的那一筆：別台、不是殘留的，最晚開始的優先。
    func latestOther(at now: Date = .now) -> Entry? {
        Self.latestOther(in: entries, excluding: deviceID, at: now)
    }

    static func latestOther(in entries: [String: Entry], excluding deviceID: String, at now: Date) -> Entry? {
        entries
            .filter { $0.key != deviceID && now.timeIntervalSince($0.value.startedAt) < maxAge }
            .map(\.value)
            .max { $0.startedAt < $1.startedAt }
    }

    /// 「Running on iPad」；同一種裝置時說「another iPhone」。
    func notice(at now: Date = .now) -> String? {
        guard let other = latestOther(at: now) else { return nil }
        return other.model == model
            ? String(localized: "Running on another \(other.model)")
            : String(localized: "Running on \(other.model)")
    }
}
